import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verify_app/models/ai_observation.dart';
import 'package:verify_app/models/customer.dart';
import 'package:verify_app/models/inspection_session.dart';
import 'package:verify_app/screens/ai_review_screen.dart';
import 'package:verify_app/screens/customer_report_screen.dart';
import 'package:verify_app/services/mock_delivery_service.dart';

import 'support.dart';

class ControlledDelivery implements DeliveryService {
  final gate = Completer<void>();
  int calls = 0;
  String? recipient;
  String? inspection;
  int? revision;
  @override
  Future<void> simulate({
    required String inspectionId,
    required int revision,
    required String channel,
    required String recipient,
  }) {
    calls++;
    this.recipient = recipient;
    inspection = inspectionId;
    this.revision = revision;
    return gate.future;
  }
}

InspectionSession approved() {
  final s = readySession();
  completeChecks(s);
  final o = addConcern(s);
  s.decide(
    o,
    AiObservationStatus.dismissed,
    'Not an actual concern',
    notActualConcern: true,
  );
  acknowledge(s);
  expect(s.completeDemo(), isTrue);
  return s;
}

void review(InspectionSession s) {
  expect(s.prepareReport(), isTrue);
  s.setDeliveryConfirmation(0, true);
  s.setDeliveryConfirmation(1, true);
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  test('snapshot allow-list preserves session data and excludes all private metadata', () {
    final s = approved();
    s.setNote('PRIVATE NOTE', customerVisible: false);
    s.setNote('Consider follow-up', customerVisible: true);
    acknowledge(s);
    s.completeDemo();
    review(s);
    final snapshot = s.reportSnapshot!;
    final json = jsonEncode(snapshot.data);
    expect(snapshot.inspectionId, s.id);
    expect(snapshot.revision, s.reportRevision);
    expect(json, contains('Intake Customer'));
    expect(json, contains('Sample Vehicle'));
    expect(json, contains(s.location));
    expect(json, contains(s.technician));
    expect(json, contains('Consider follow-up'));
    for (final excluded in [
      'PRIVATE NOTE',
      'Synthetic possible leak',
      'confidence',
      'audit',
      'attempt',
      s.attempts.first.id,
      'Not an actual concern',
    ]) {
      expect(json, isNot(contains(excluded)));
    }
    expect(snapshot.data['verifiedFacts'], isEmpty);
    expect(snapshot.data['realApproved'], isFalse);
    expect(snapshot.data['playbackAvailable'], isFalse);
    expect((snapshot.data['customer'] as Map)['provenance'], 'sample');
    expect(
      () => (snapshot.data['customer'] as Map)['name'] = 'overwrite',
      throwsUnsupportedError,
    );
  });

  test('pending concerns, missing checks and stale approvals block report and service', () async {
    final s = approved();
    review(s);
    s.decide(
      s.observations.first,
      AiObservationStatus.furtherInspection,
      'Mechanic needed',
    );
    final service = ControlledDelivery();
    expect(s.prepareReport(), isFalse);
    expect(await s.simulateDelivery(service), isFalse);
    expect(service.calls, 0);
    expect(s.reportBlockers.join(), contains('Unresolved concern'));
    s.decide(
      s.observations.first,
      AiObservationStatus.dismissed,
      'Reviewed',
      notActualConcern: true,
    );
    expect(s.prepareReport(), isFalse);
    acknowledge(s);
    s.completeDemo();
    review(s);
    s.failCheck('drain_plug', 'Required evidence needs replacement');
    expect(s.reportCurrent, isFalse);
    expect(await s.simulateDelivery(service), isFalse);
    expect(s.reportBlockers.join(), contains('Drain Plug'));
  });

  test(
    'missing or invalid contacts and unchecked confirmations prevent sends',
    () async {
      final s = approved();
      final service = ControlledDelivery();
      s.prepareReport();
      expect(await s.simulateDelivery(service), isFalse);
      s.setDeliveryConfirmation(0, true);
      expect(await s.simulateDelivery(service), isFalse);
      s.selectDeliveryChannel(DeliveryChannel.email);
      expect(s.recipient, isEmpty);
      expect(s.recipientProblem, contains('No EMAIL contact'));
      s.setDeliveryConfirmation(1, true);
      expect(s.deliveryConfirmations, everyElement(isFalse));
      s.setCustomer(
        const Customer(
          firstName: 'Intake',
          lastName: 'Customer',
          phone: 'bad',
          email: 'bad',
        ),
      );
      acknowledge(s);
      s.completeDemo();
      s.prepareReport();
      expect(s.recipientProblem, contains('Invalid EMAIL'));
      s.selectDeliveryChannel(DeliveryChannel.sms);
      expect(s.recipientProblem, contains('Invalid SMS'));
      expect(await s.simulateDelivery(service), isFalse);
      expect(service.calls, 0);
    },
  );

  test('recommendations, evidence, decisions and contacts invalidate snapshots and confirmations', () {
    final mutations = <void Function(InspectionSession)>[
      (s) => s.setNote('Changed', customerVisible: true),
      (s) => s.beginCapture('engine_bay', CaptureKind.video),
      (s) => s.decide(
        s.observations.first,
        AiObservationStatus.confirmed,
        'New concern',
      ),
      (s) => s.setCustomer(
        const Customer(
          firstName: 'Same',
          lastName: 'Person',
          phone: '504-555-0100',
        ),
      ),
    ];
    for (final change in mutations) {
      final s = approved();
      review(s);
      final old = s.reportSnapshot!;
      change(s);
      expect(s.reportRevision, greaterThan(old.revision));
      expect(s.reportCurrent, isFalse);
      expect(s.deliveryConfirmations, everyElement(isFalse));
      expect(s.canSimulateSend, isFalse);
    }
  });

  test('internal notes preserve snapshot; channel changes require recipient review', () {
    final s = approved();
    review(s);
    final snapshot = s.reportSnapshot;
    s.setNote('private', customerVisible: false);
    expect(s.reportSnapshot, same(snapshot));
    expect(s.canSimulateSend, isTrue);
    s.selectDeliveryChannel(DeliveryChannel.email);
    expect(s.deliveryConfirmations, everyElement(isFalse));
    expect(s.audit.last.action, 'delivery_channel_changed');
  });

  test(
    'rapid sends serialize, preserve actual contact and record honest success',
    () async {
      final s = approved();
      review(s);
      final service = ControlledDelivery();
      final first = s.simulateDelivery(service);
      expect(await s.simulateDelivery(service), isFalse);
      expect(service.calls, 1);
      expect(service.recipient, s.customer!.phone);
      expect(service.inspection, s.id);
      expect(service.revision, s.reportRevision);
      service.gate.complete();
      expect(await first, isTrue);
      expect(
        s.deliveryMessage,
        'Simulation complete. Nothing was sent to the customer.',
      );
      expect(s.sending, isFalse);
      expect(s.audit.last.action, 'demo_delivery_completed');
      expect(s.audit.last.details['actualSend'], 'false');
    },
  );

  test('late results and failures never report successful delivery and release lock', () async {
    final s = approved();
    review(s);
    final service = ControlledDelivery();
    final pending = s.simulateDelivery(service);
    s.setNote('changed recommendation', customerVisible: true);
    service.gate.complete();
    expect(await pending, isFalse);
    expect(s.deliveryMessage, contains('Session changed'));
    expect(s.sending, isFalse);
    acknowledge(s);
    s.completeDemo();
    review(s);
    final failing = ControlledDelivery();
    final failed = s.simulateDelivery(failing);
    failing.gate.completeError(StateError('mock failure'));
    expect(await failed, isFalse);
    expect(s.deliveryMessage, contains('Simulation failed. Nothing was sent'));
    expect(s.sending, isFalse);
    expect(s.audit.last.action, 'demo_delivery_failed');
  });

  for (final width in [360.0, 1440.0]) {
    testWidgets('SCR-003 to report and simulated send at ${width}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = approved();
      s.setNote('Private text never shown', customerVisible: false);
      s.setNote('Discuss maintenance options', customerVisible: true);
      acknowledge(s);
      s.completeDemo();
      await tester.pumpWidget(MaterialApp(home: AiReviewScreen(session: s)));
      await tap(tester, find.text('VIEW DEMO CUSTOMER REPORT'));
      expect(find.byType(CustomerReportScreen), findsOneWidget);
      expect(find.textContaining('Intake Customer'), findsOneWidget);
      expect(find.text('Discuss maintenance options'), findsOneWidget);
      expect(find.textContaining('Private text never shown'), findsNothing);
      expect(find.text('Watch My Inspection'), findsOneWidget);
      expect(find.textContaining('Playback unavailable'), findsOneWidget);
      expect(s.deliveryConfirmations, everyElement(isFalse));
      await tap(tester, find.byKey(const ValueKey('delivery-confirm-0')));
      await tap(tester, find.byKey(const ValueKey('delivery-confirm-1')));
      await tap(tester, find.byKey(const ValueKey('simulate-send')));
      expect(
        find.text('Simulation complete. Nothing was sent to the customer.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'pending send survives leaving screen without widget updates or overlap',
    (tester) async {
      final s = approved();
      final service = ControlledDelivery();
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerReportScreen(session: s, service: service),
        ),
      );
      await tap(tester, find.byKey(const ValueKey('delivery-confirm-0')));
      await tap(tester, find.byKey(const ValueKey('delivery-confirm-1')));
      await tap(tester, find.byKey(const ValueKey('simulate-send')));
      expect(s.sending, isTrue);
      expect(service.calls, 1);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      service.gate.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(s.deliveryMessage, contains('Nothing was sent'));
    },
  );
}
