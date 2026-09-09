import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verify_app/main.dart';
import 'package:verify_app/models/ai_observation.dart';
import 'package:verify_app/models/inspection_session.dart';
import 'package:verify_app/screens/new_inspection_screen.dart';
import 'package:verify_app/screens/guided_inspection_screen.dart';
import 'package:verify_app/screens/ai_review_screen.dart';

import 'support.dart';

Future<void> show(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('default app starts with a generated demo session', (
    tester,
  ) async {
    await tester.pumpWidget(const ProjectVerifyApp());
    await tester.pumpAndSettle();
    expect(
      find.text('DEMO ONLY • No real inspection approval'),
      findsOneWidget,
    );
    expect(find.textContaining('Inspection: DEMO-'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'critical concern requires explicit successful recheck acknowledgment',
    (tester) async {
      final session = readySession();
      completeChecks(session);
      final concern = addConcern(session);
      session.decide(concern, AiObservationStatus.confirmed, 'Concern exists');
      await tester.pumpWidget(
        MaterialApp(home: AiReviewScreen(session: session)),
      );
      await show(tester, find.text('RECORD SIMULATED CORRECTION + RECHECK'));
      await tester.tap(find.text('RECORD SIMULATED CORRECTION + RECHECK'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Corrected area',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Rechecked area; clear',
      );
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();
      expect(concern.resolved, isFalse);
      expect(
        find.text('Confirm a successful recheck before clearing this concern.'),
        findsOneWidget,
      );
      final acknowledgment = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(CheckboxListTile),
      );
      expect(tester.widget<CheckboxListTile>(acknowledgment).value, isFalse);
      await tester.tap(acknowledgment);
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();
      expect(concern.resolved, isTrue);
      expect(concern.recheckPassed, isTrue);
      expect(session.approvals, everyElement(isFalse));
    },
  );
  testWidgets(
    'explicitly labeled intake demo navigates; unsupported actions explain',
    (tester) async {
      final session = InspectionSession(
        id: 'DEMO-intake',
        technician: 'Intake Tech',
      );
      await tester.pumpWidget(
        MaterialApp(home: NewInspectionScreen(session: session)),
      );
      expect(
        find.text('DEMO ONLY • No real inspection approval'),
        findsOneWidget,
      );
      await show(tester, find.text('START DEMO INSPECTION'));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'START DEMO INSPECTION'),
            )
            .onPressed,
        isNull,
      );
      await show(tester, find.text('NEW CUSTOMER'));
      await tester.tap(find.text('NEW CUSTOMER'));
      await tester.pump();
      expect(
        find.textContaining('New customer creation is not implemented'),
        findsOneWidget,
      );
      expect(session.customer, isNull);
      await tester.tap(find.text('LOAD DEMO CUSTOMER'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await show(tester, find.text('SIMULATE VIN SCAN'));
      await tester.tap(find.text('SIMULATE VIN SCAN'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('DEMO VIN DECODE • UNVERIFIED'), findsOneWidget);
      expect(find.text('VERIFIED'), findsNothing);
      await show(tester, find.text('SIMULATE SQUARE LINK'));
      await tester.tap(find.text('SIMULATE SQUARE LINK'));
      await tester.pump();
      await show(tester, find.text('START DEMO INSPECTION'));
      await tester.tap(find.text('START DEMO INSPECTION'));
      await tester.pumpAndSettle();
      expect(find.byType(GuidedInspectionScreen), findsOneWidget);
      expect(
        tester
            .widget<GuidedInspectionScreen>(find.byType(GuidedInspectionScreen))
            .session,
        same(session),
      );
      expect(session.realApproved, isFalse);
    },
  );

  testWidgets(
    'customer vehicle notes and decisions survive backward/forward navigation',
    (tester) async {
      final session = readySession();
      completeChecks(session);
      final concern = addConcern(session);
      await tester.pumpWidget(
        MaterialApp(home: NewInspectionScreen(session: session)),
      );
      await show(tester, find.text('START DEMO INSPECTION'));
      await tester.tap(find.text('START DEMO INSPECTION'));
      await tester.pumpAndSettle();
      await show(tester, find.byKey(const ValueKey('finish-guided')));
      await tester.tap(find.byKey(const ValueKey('finish-guided')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Customer: Intake Customer'), findsOneWidget);
      expect(
        find.textContaining('Vehicle: 2024 Sample Vehicle Demo'),
        findsOneWidget,
      );
      await show(tester, find.text('DISMISS WITH REASON'));
      await tester.tap(find.text('DISMISS WITH REASON'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField),
        'Reviewed synthetic scenario',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(CheckboxListTile),
        ),
      );
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();
      expect(concern.status, AiObservationStatus.dismissed);
      expect(session.approvals, everyElement(isFalse));
      await show(tester, find.byKey(const ValueKey('internal-note')));
      await tester.enterText(
        find.byKey(const ValueKey('internal-note')),
        'Keep inside shop',
      );
      await show(tester, find.byKey(const ValueKey('customer-recommendation')));
      await tester.enterText(
        find.byKey(const ValueKey('customer-recommendation')),
        'Customer recommendation',
      );
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await show(tester, find.text('START DEMO INSPECTION'));
      await tester.tap(find.text('START DEMO INSPECTION'));
      await tester.pumpAndSettle();
      await show(tester, find.byKey(const ValueKey('finish-guided')));
      await tester.tap(find.byKey(const ValueKey('finish-guided')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<AiReviewScreen>(find.byType(AiReviewScreen)).session,
        same(session),
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('internal-note')))
            .controller!
            .text,
        'Keep inside shop',
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('customer-recommendation')),
            )
            .controller!
            .text,
        'Customer recommendation',
      );
      expect(concern.decisionReason, 'Reviewed synthetic scenario');
      expect(concern.decidedBy, session.technician);
      expect(session.approvals, everyElement(isFalse));
      for (var i = 0; i < 4; i++) {
        final checkbox = find.byKey(ValueKey('approval-$i'));
        await show(tester, checkbox);
        expect(tester.widget<CheckboxListTile>(checkbox).value, isFalse);
        await tester.tap(checkbox);
        await tester.pump();
      }
      await show(tester, find.byKey(const ValueKey('complete-demo')));
      await tester.tap(find.byKey(const ValueKey('complete-demo')));
      await tester.pump();
      expect(session.demoApproved, isTrue);
      expect(session.realApproved, isFalse);
    },
  );

  for (final duringStop in [false, true]) {
    testWidgets(
      'rapid taps and leaving during pending ${duringStop ? 'stop' : 'start'} have no disposed-widget errors',
      (tester) async {
        final clock = TestClock();
        final session = readySession(clock: clock);
        final service = ControlledRecordingService();
        if (duringStop) {
          service.stopGate = Completer<void>();
        } else {
          service.startGate = Completer<void>();
        }
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => GuidedInspectionScreen(
                        session: session,
                        recordingService: service,
                      ),
                    ),
                  ),
                  child: const Text('OPEN'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('OPEN'));
        await tester.pumpAndSettle();
        final start = find.byKey(const ValueKey('capture-drain_plug'));
        await show(tester, start);
        await tester.tap(start);
        await tester.tap(
          start,
        ); // Before a frame rebuild: controller must still reject.
        await tester.pump();
        expect(service.starts, 1);
        if (duringStop) {
          clock.advance(const Duration(seconds: 5));
          await tester.ensureVisible(
            find.byKey(const ValueKey('stop-capture')),
          );
          await tester.pump();
          await tester.tap(find.byKey(const ValueKey('stop-capture')));
          await tester.tap(find.byKey(const ValueKey('stop-capture')));
          await tester.pump();
          expect(service.stops, 1);
        }
        await tester.pageBack();
        await tester.pumpAndSettle();
        if (duringStop) {
          service.stopGate!.complete();
        } else {
          service.startGate!.complete();
        }
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(session.attempts, hasLength(1));
        expect(session.attempts.single.status, CaptureStatus.cancelled);
      },
    );
  }

  testWidgets(
    'five-second clip presents keep/retry and dipstick controls enforce order',
    (tester) async {
      final clock = TestClock();
      final session = readySession(clock: clock);
      final service = ControlledRecordingService();
      await tester.pumpWidget(
        MaterialApp(
          home: GuidedInspectionScreen(
            session: session,
            recordingService: service,
          ),
        ),
      );
      await show(tester, find.byKey(const ValueKey('capture-drain_plug')));
      await tester.tap(find.byKey(const ValueKey('capture-drain_plug')));
      await tester.pump();
      clock.advance(const Duration(seconds: 5));
      await tester.ensureVisible(find.byKey(const ValueKey('stop-capture')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('stop-capture')));
      await tester.pumpAndSettle();
      expect(find.text('KEEP DEMO ATTEMPT'), findsOneWidget);
      expect(find.text('RECORD AGAIN'), findsOneWidget);
      await show(tester, find.byKey(const ValueKey('keep-capture')));
      await tester.tap(find.byKey(const ValueKey('keep-capture')));
      await tester.pump();
      completeVehicleStage(session);
      await tester.pump();
      final touch = find.byKey(const ValueKey('capture-caps_touch'));
      expect(tester.widget<FilledButton>(touch).onPressed, isNull);
      final reinsertion = find.byKey(const ValueKey('confirm-dipstick'));
      expect(tester.widget<FilledButton>(reinsertion).onPressed, isNull);
      await show(tester, find.byKey(const ValueKey('capture-dipstick')));
      await tester.tap(find.byKey(const ValueKey('capture-dipstick')));
      await tester.pumpAndSettle();
      await show(tester, find.byKey(const ValueKey('keep-capture')));
      await tester.tap(find.byKey(const ValueKey('keep-capture')));
      await tester.pump();
      expect(tester.widget<FilledButton>(touch).onPressed, isNull);
      await show(tester, reinsertion);
      await tester.tap(reinsertion);
      await tester.pump();
      expect(tester.widget<FilledButton>(touch).onPressed, isNotNull);
      expect(session.dipstickReinserted, isTrue);
    },
  );

  for (final size in [const Size(360, 800), const Size(1440, 1000)]) {
    testWidgets(
      'all populated screens and controls fit ${size.width.toInt()}px viewport',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final session = readySession();
        await tester.pumpWidget(
          MaterialApp(home: NewInspectionScreen(session: session)),
        );
        await tester.pumpAndSettle();
        await show(tester, find.text('START DEMO INSPECTION'));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(
          MaterialApp(home: GuidedInspectionScreen(session: session)),
        );
        await tester.pumpAndSettle();
        await show(tester, find.byKey(const ValueKey('next-stage')));
        expect(tester.takeException(), isNull);
        completeChecks(session);
        await tester.pump();
        await show(tester, find.byKey(const ValueKey('finish-guided')));
        expect(tester.takeException(), isNull);
        addConcern(session);
        await tester.pumpWidget(
          MaterialApp(home: AiReviewScreen(session: session)),
        );
        await tester.pumpAndSettle();
        await show(tester, find.text('DISMISS WITH REASON'));
        await tester.tap(find.text('DISMISS WITH REASON'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('CANCEL'));
        await tester.pumpAndSettle();
        await show(tester, find.byKey(const ValueKey('complete-demo')));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
