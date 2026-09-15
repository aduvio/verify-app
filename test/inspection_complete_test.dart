import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verify_app/models/ai_observation.dart';
import 'package:verify_app/models/customer.dart';
import 'package:verify_app/models/inspection_session.dart';
import 'package:verify_app/screens/customer_report_screen.dart';
import 'package:verify_app/screens/inspection_complete_screen.dart';
import 'package:verify_app/screens/guided_inspection_screen.dart';
import 'package:verify_app/screens/new_inspection_screen.dart';
import 'package:verify_app/services/inspection_repository.dart';

import 'support.dart';
import 'customer_report_test.dart'
    show approved, review, ControlledDelivery, tap;

Future<void> finish(InspectionSession s) async {
  review(s);
  final service = ControlledDelivery();
  final future = s.simulateDelivery(service);
  service.gate.complete();
  expect(await future, isTrue);
}

void main() {
  test('completion stores actual event time, snapshot, recipient and independent demo states', () async {
    final clock = TestClock();
    final s = readySession(clock: clock);
    completeChecks(s);
    final o = addConcern(s);
    s.decide(
      o,
      AiObservationStatus.dismissed,
      'No actual concern',
      notActualConcern: true,
    );
    acknowledge(s);
    s.completeDemo();
    review(s);
    final revision = s.reportRevision;
    final service = ControlledDelivery();
    final sending = s.simulateDelivery(service);
    clock.advance(const Duration(minutes: 1));
    service.gate.complete();
    expect(await sending, isTrue);
    final c = s.completion!;
    expect(c.snapshot.inspectionId, s.id);
    expect(c.snapshot.revision, revision);
    expect(c.delivery.recipient, s.customer!.phone);
    expect(c.delivery.channel, DeliveryChannel.sms);
    expect(c.completedAt, clock.now);
    expect(
      c.completedAt,
      s.audit.singleWhere((e) => e.action == 'demo_inspection_completed').at,
    );
    clock.advance(const Duration(days: 1));
    expect(s.completion!.completedAt, c.completedAt);
    expect(s.demoApproved, isTrue);
    expect(s.realApproved, isFalse);
    expect(s.deliveryAttempts.single.status, DeliveryAttemptStatus.succeeded);
    expect(s.editable, isFalse);
  });

  test('successful revision cannot be changed or sent again without explicit reopen', () async {
    final s = approved();
    await finish(s);
    final revision = s.reportRevision;
    final events = s.audit.length;
    final original = s.customer;
    s.setCustomer(
      const Customer(
        firstName: 'Wrong',
        lastName: 'Person',
        phone: '504-555-0100',
      ),
    );
    s.setNote('Changed', customerVisible: true);
    s.setNote('Changed private', customerVisible: false);
    s.decide(s.observations.first, AiObservationStatus.confirmed, 'Changed');
    s.setApproval(0, false);
    s.failCheck('drain_plug', 'Changed');
    s.setStage(false);
    s.abandon();
    expect(
      () => s.beginCapture('engine_bay', CaptureKind.video),
      throwsStateError,
    );
    expect(s.prepareReport(), isFalse);
    final service = ControlledDelivery();
    expect(await s.simulateDelivery(service), isFalse);
    expect(service.calls, 0);
    expect(s.customer, same(original));
    expect(s.reportRevision, revision);
    expect(s.audit.length, events);
    expect(s.completedRevisions, hasLength(1));
  });

  test('failed and stale attempts retain their own immutable revision and recipient without completion', () async {
    final s = approved();
    review(s);
    final old = s.reportSnapshot!;
    final failed = ControlledDelivery();
    final p = s.simulateDelivery(failed);
    failed.gate.completeError(StateError('Mock failed'));
    expect(await p, isFalse);
    final first = s.deliveryAttempts.single;
    expect(first.status, DeliveryAttemptStatus.failed);
    expect(s.completion, isNull);
    s.setCustomer(
      const Customer(
        firstName: 'Intake',
        lastName: 'Customer',
        phone: '504-555-0100',
      ),
    );
    acknowledge(s);
    s.completeDemo();
    review(s);
    final stale = ControlledDelivery();
    final q = s.simulateDelivery(stale);
    s.setNote('new report text', customerVisible: true);
    stale.gate.complete();
    expect(await q, isFalse);
    expect(s.deliveryAttempts.first, same(first));
    expect(first.snapshot, same(old));
    expect(first.recipient, '504-555-0199');
    expect(s.deliveryAttempts.last.recipient, '504-555-0100');
    expect(s.deliveryAttempts.last.status, DeliveryAttemptStatus.stale);
    expect(s.completion, isNull);
    expect(
      s.audit.where((e) => e.action == 'demo_inspection_completed'),
      isEmpty,
    );
  });

  test('reopen requires reason, retains records and evidence, invalidates approval once', () async {
    final s = approved();
    s.setNote('private note', customerVisible: false);
    await finish(s);
    final old = s.completion!;
    final encoded = jsonEncode(old.snapshot.data);
    final count = s.audit.length;
    final evidence = s.attempts.length;
    expect(
      () => s.reopen(' ', completedRevision: old.snapshot.revision),
      throwsArgumentError,
    );
    expect(s.audit.length, count);
    expect(
      s.reopen(
        'Correct recommendation',
        completedRevision: old.snapshot.revision,
      ),
      isTrue,
    );
    expect(
      s.reopen('Duplicate', completedRevision: old.snapshot.revision),
      isFalse,
    );
    expect(s.id, old.snapshot.inspectionId);
    expect(s.reportRevision, greaterThan(old.snapshot.revision));
    expect(s.completedRevisions.single, same(old));
    expect(s.deliveryAttempts.single, same(old.delivery));
    expect(jsonEncode(old.snapshot.data), encoded);
    expect(s.attempts.length, evidence);
    expect(s.internalNote!.text, 'private note');
    expect(s.approvals, everyElement(isFalse));
    expect(s.reportSnapshot, isNull);
    expect(s.deliveryConfirmations, everyElement(isFalse));
    expect(s.completion, isNull);
    expect(s.prepareReport(), isFalse);
    final event = s.audit.last;
    expect(event.action, 'demo_inspection_reopened');
    expect(event.actor, s.technician);
    expect(event.details['reason'], 'Correct recommendation');
    expect(event.at, s.updatedAt);
    acknowledge(s);
    s.completeDemo();
    await finish(s);
    expect(s.completedRevisions, hasLength(2));
    expect(s.deliveryAttempts, hasLength(2));
    expect(jsonEncode(old.snapshot.data), encoded);
  });

  test('starting next retains old record and returns one clean session for repeated requests', () async {
    final repo = InMemoryInspectionRepository();
    final s = approved();
    await finish(s);
    final next = repo.startNext(s);
    expect(repo.startNext(s), same(next));
    expect(repo.find(s.id), same(s));
    expect(repo.find(next.id), same(next));
    expect(next.id, isNot(s.id));
    expect(next.technician, s.technician);
    expect(next.location, s.location);
    expect(next.customer, isNull);
    expect(next.vehicle, isNull);
    expect(next.attempts, isEmpty);
    expect(next.internalNote, isNull);
    expect(next.customerRecommendation, isNull);
    expect(next.observations, isEmpty);
    expect(next.approvals, everyElement(isFalse));
    expect(next.requiredSteps.every((step) => !step.isComplete), isTrue);
    expect(next.deliveryAttempts, isEmpty);
    expect(next.completion, isNull);
    expect(next.reportSnapshot, isNull);
    expect(next.deliveryMessage, isNull);
    expect(next.deliveryConfirmations, everyElement(isFalse));
    expect(next.demoApproved, isFalse);
    expect(s.completedRevisions, hasLength(1));
    expect(() => repo.startNext(next), throwsStateError);
  });

  testWidgets(
    'duplicate clicks open one completion and Back cannot reach old routes',
    (tester) async {
      final s = approved();
      final repo = InMemoryInspectionRepository();
      final service = ControlledDelivery();
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerReportScreen(
            session: s,
            repository: repo,
            service: service,
          ),
        ),
      );
      await tap(tester, find.byKey(const ValueKey('delivery-confirm-0')));
      await tap(tester, find.byKey(const ValueKey('delivery-confirm-1')));
      final send = find.byKey(const ValueKey('simulate-send'));
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.tap(send);
      expect(service.calls, 1);
      service.gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(InspectionCompleteScreen), findsOneWidget);
      expect(find.byType(CustomerReportScreen), findsNothing);
      expect(
        s.audit.where((e) => e.action == 'demo_inspection_completed'),
        hasLength(1),
      );
      expect(s.deliveryAttempts, hasLength(1));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(InspectionCompleteScreen), findsOneWidget);
      expect(s.editable, isFalse);
      expect(find.text('Recipient used: 504-555-0199'), findsOneWidget);
      expect(
        find.text('Completed: ${s.completion!.completedAt.toIso8601String()}'),
        findsOneWidget,
      );
    },
  );

  testWidgets('failed send stays on report and retry succeeds', (tester) async {
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
    service.gate.completeError(StateError('demo failure'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerReportScreen), findsOneWidget);
    expect(find.byType(InspectionCompleteScreen), findsNothing);
    expect(
      find.textContaining('Simulation failed. Nothing was sent'),
      findsOneWidget,
    );
    expect(s.sending, isFalse);
    expect(s.completion, isNull);
    // Fresh service stands in for a recovered transport on the next attempt.
    final retry = ControlledDelivery();
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerReportScreen(session: s, service: retry),
      ),
    );
    await tap(tester, find.byKey(const ValueKey('delivery-confirm-0')));
    await tap(tester, find.byKey(const ValueKey('delivery-confirm-1')));
    await tap(tester, find.byKey(const ValueKey('simulate-send')));
    retry.gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(InspectionCompleteScreen), findsOneWidget);
    expect(s.deliveryAttempts.map((a) => a.status), [
      DeliveryAttemptStatus.failed,
      DeliveryAttemptStatus.succeeded,
    ]);
  });

  testWidgets(
    'reopen cancel is unchanged; blank reason cannot reopen; confirmed reason returns to editing',
    (tester) async {
      final s = approved();
      await finish(s);
      final repo = InMemoryInspectionRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: InspectionCompleteScreen(session: s, repository: repo),
        ),
      );
      final events = s.audit.length;
      final completed = s.completion;
      await tap(tester, find.byKey(const ValueKey('reopen-inspection')));
      await tap(tester, find.text('CANCEL'));
      expect(s.audit.length, events);
      expect(s.completion, same(completed));
      await tap(tester, find.byKey(const ValueKey('reopen-inspection')));
      await tap(tester, find.text('SAVE'));
      expect(s.completion, same(completed));
      await tester.enterText(
        find.byType(TextFormField),
        'Review recommendation',
      );
      await tap(tester, find.byType(CheckboxListTile));
      await tap(tester, find.text('SAVE'));
      expect(find.byType(GuidedInspectionScreen), findsOneWidget);
      expect(find.byType(InspectionCompleteScreen), findsNothing);
      expect(s.approvals, everyElement(isFalse));
      expect(s.completedRevisions, hasLength(1));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(InspectionCompleteScreen), findsNothing);
    },
  );

  for (final width in [360.0, 1440.0]) {
    testWidgets(
      'completion privacy, staff timeline and new inspection at ${width}px',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final s = approved();
        s.setNote('INTERNAL ONLY', customerVisible: false);
        await finish(s);
        final repo = InMemoryInspectionRepository();
        repo.retain(s);
        await tester.pumpWidget(
          MaterialApp(
            home: InspectionCompleteScreen(session: s, repository: repo),
          ),
        );
        expect(find.text('DEMO INSPECTION COMPLETE'), findsOneWidget);
        expect(
          find.text(
            'Video unavailable — no real recording was included in this report.',
          ),
          findsOneWidget,
        );
        expect(find.text('Secure hosting not connected.'), findsOneWidget);
        expect(find.text('INTERNAL ONLY'), findsNothing);
        final encoded = jsonEncode(s.completion!.snapshot.data);
        expect(encoded, isNot(contains('INTERNAL ONLY')));
        expect(encoded, isNot(contains('Synthetic possible leak')));
        final staffHeader = find.text(
          'STAFF ONLY — internal notes, advisory observations and event timeline',
        );
        await tap(tester, staffHeader);
        expect(find.text('INTERNAL ONLY'), findsOneWidget);
        expect(
          find.textContaining('demo inspection completed'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tap(tester, staffHeader);
        expect(find.text('INTERNAL ONLY'), findsNothing);
        final start = find.byKey(const ValueKey('start-new-inspection'));
        await tester.ensureVisible(start);
        await tester.pumpAndSettle();
        final startPoint = tester.getCenter(start);
        await tester.tapAt(startPoint);
        await tester.tapAt(startPoint);
        await tester.pumpAndSettle();
        final intake = tester.widget<NewInspectionScreen>(
          find.byType(NewInspectionScreen),
        );
        expect(intake.session!.id, isNot(s.id));
        expect(intake.session!.customer, isNull);
        expect(repo.find(s.id), same(s));
        expect(s.completion, isNotNull);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(InspectionCompleteScreen), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
