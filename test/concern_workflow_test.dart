import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verify_app/models/ai_observation.dart';
import 'package:verify_app/models/inspection_session.dart';
import 'package:verify_app/screens/ai_review_screen.dart';

import 'support.dart';

const correctionButton = 'RECORD SIMULATED CORRECTION + RECHECK';
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  // Let any text-field caret reveal finish before scrolling to the next action.
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> assess(
  WidgetTester tester,
  String button,
  String reason, {
  bool dismiss = false,
}) async {
  await tapVisible(tester, find.text(button));
  await tester.enterText(find.byType(TextFormField), reason);
  if (dismiss) {
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(CheckboxListTile),
      ),
    );
  }
  await tapVisible(tester, find.text('SAVE'));
}

Future<void> correct(WidgetTester tester, {bool success = true}) async {
  await tapVisible(tester, find.text(correctionButton));
  await tester.enterText(
    find.byType(TextFormField).at(0),
    'Simulated correction by mechanic',
  );
  await tester.enterText(
    find.byType(TextFormField).at(1),
    success
        ? 'Simulated recheck: concern cleared'
        : 'Simulated recheck: concern remains',
  );
  if (success) {
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(CheckboxListTile),
      ),
    );
  }
  await tapVisible(
    tester,
    find.text(success ? 'SAVE' : 'SAVE FAILED / INCOMPLETE RECHECK'),
  );
}

Future<void> manualApproval(
  WidgetTester tester,
  InspectionSession session,
) async {
  expect(session.approvals, everyElement(isFalse));
  expect(session.demoApproved, isFalse);
  for (var i = 0; i < 4; i++) {
    final box = find.byKey(ValueKey('approval-$i'));
    expect(tester.widget<CheckboxListTile>(box).value, isFalse);
    expect(tester.widget<CheckboxListTile>(box).onChanged, isNotNull);
    await tapVisible(tester, box);
  }
  await tapVisible(tester, find.byKey(const ValueKey('complete-demo')));
  expect(session.demoApproved, isTrue);
  expect(session.realApproved, isFalse);
}

void main() {
  for (final dismiss in [false, true]) {
    testWidgets(
      'mechanic needed -> ${dismiss ? 'legitimate dismissal' : 'confirm, correct, successful recheck'} -> manual approval retains notes and audit',
      (tester) async {
        final clock = TestClock();
        final session = readySession(clock: clock);
        completeChecks(session);
        final concern = addConcern(session);
        await tester.pumpWidget(
          MaterialApp(home: AiReviewScreen(session: session)),
        );
        await tester.ensureVisible(find.byKey(const ValueKey('internal-note')));
        await tester.enterText(
          find.byKey(const ValueKey('internal-note')),
          'Shop note survives',
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('customer-recommendation')),
        );
        await tester.enterText(
          find.byKey(const ValueKey('customer-recommendation')),
          'Recommendation survives',
        );
        await assess(tester, 'NEEDS FURTHER INSPECTION', 'mechanic needed');
        expect(concern.resolved, isFalse);
        expect(
          find.textContaining('Assessment: Needs further inspection'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Assessment: furtherInspection'),
          findsNothing,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, correctionButton),
              )
              .onPressed,
          isNull,
        );
        clock.advance(const Duration(minutes: 1));
        if (dismiss) {
          await assess(
            tester,
            'DISMISS WITH REASON',
            'Mechanic determined no actual concern',
            dismiss: true,
          );
        } else {
          await assess(tester, 'CONFIRM CONCERN', 'Mechanic confirms concern');
          expect(concern.resolved, isFalse);
          expect(
            tester
                .widget<CheckboxListTile>(
                  find.byKey(const ValueKey('approval-0')),
                )
                .onChanged,
            isNull,
          );
          await correct(tester);
          expect(concern.addressedBy, session.technician);
          expect(concern.addressedAt, clock.now);
          expect(session.audit.last.action, 'concern_addressed');
          expect(session.audit.last.details['recheckPassed'], 'true');
        }
        expect(concern.resolved, isTrue);
        expect(session.internalNote!.text, 'Shop note survives');
        expect(session.customerRecommendation!.text, 'Recommendation survives');
        final decisions = session.audit
            .where((e) => e.action == 'observation_assessed')
            .toList();
        expect(decisions.first.details['reason'], 'mechanic needed');
        expect(
          decisions.last.details['previousAssessment'],
          'furtherInspection',
        );
        expect(decisions.last.actor, session.technician);
        expect(decisions.last.at, clock.now);
        await manualApproval(tester, session);
        await assess(
          tester,
          'NEEDS FURTHER INSPECTION',
          'New information requires another inspection',
        );
        expect(session.demoApproved, isFalse);
        expect(session.approvals, everyElement(isFalse));
        expect(session.internalNote!.text, 'Shop note survives');
        expect(
          session.audit.where((e) => e.action == 'observation_assessed'),
          hasLength(3),
        );
      },
    );
  }

  testWidgets(
    'missing correction or unacknowledged success blocks; failed recheck saved and remains blocking',
    (tester) async {
      final session = readySession();
      completeChecks(session);
      final concern = addConcern(session);
      await tester.pumpWidget(
        MaterialApp(home: AiReviewScreen(session: session)),
      );
      await assess(tester, 'CONFIRM CONCERN', 'Problem exists');
      await tapVisible(tester, find.text(correctionButton));
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Recheck description only',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(CheckboxListTile),
        ),
      );
      await tapVisible(tester, find.text('SAVE'));
      expect(find.text('Required'), findsOneWidget);
      expect(concern.resolved, isFalse);
      await tapVisible(tester, find.text('CANCEL'));
      await correct(tester, success: false);
      expect(concern.recheckPassed, isFalse);
      expect(concern.resolved, isFalse);
      expect(
        find.textContaining('Failed or incomplete — still blocking'),
        findsOneWidget,
      );
      expect(session.audit.last.details['recheckPassed'], 'false');
      expect(
        tester
            .widget<CheckboxListTile>(find.byKey(const ValueKey('approval-0')))
            .onChanged,
        isNull,
      );
      await correct(tester);
      expect(concern.resolved, isTrue);
      expect(
        session.audit
            .where((e) => e.action == 'concern_addressed')
            .map((e) => e.details['recheckPassed']),
        ['false', 'true'],
      );
    },
  );

  for (final dismiss in [false, true]) {
    testWidgets(
      '${dismiss ? 'dismissal' : 'successful correction'} cannot bypass a missing required capture',
      (tester) async {
        final session = readySession();
        completeChecks(session);
        final concern = addConcern(session);
        session.setStage(false);
        final retake = session.beginCapture('drain_plug', CaptureKind.video);
        session.cancelCapture(retake);
        await tester.pumpWidget(
          MaterialApp(home: AiReviewScreen(session: session)),
        );
        if (dismiss) {
          await assess(
            tester,
            'DISMISS WITH REASON',
            'Not an actual concern',
            dismiss: true,
          );
        } else {
          await assess(tester, 'CONFIRM CONCERN', 'Problem exists');
          await correct(tester);
        }
        expect(concern.resolved, isTrue);
        expect(session.allChecksComplete, isFalse);
        expect(
          find.textContaining(
            'Required inspection check incomplete or failed: Drain Plug',
          ),
          findsOneWidget,
        );
        expect(
          tester
              .widget<CheckboxListTile>(
                find.byKey(const ValueKey('approval-0')),
              )
              .onChanged,
          isNull,
        );
        expect(session.completeDemo(), isFalse);
      },
    );
  }

  testWidgets(
    'accidental confirmed assessment can be corrected with explicit dismissal and audited reason',
    (tester) async {
      final session = readySession();
      completeChecks(session);
      final concern = addConcern(session);
      await tester.pumpWidget(
        MaterialApp(home: AiReviewScreen(session: session)),
      );
      await assess(tester, 'CONFIRM CONCERN', 'Accidental selection');
      await tapVisible(tester, find.text('DISMISS WITH REASON'));
      await tester.enterText(
        find.byType(TextFormField),
        'Inspection found no actual concern; correcting accidental confirmation',
      );
      await tapVisible(tester, find.text('SAVE'));
      expect(concern.status, AiObservationStatus.confirmed);
      expect(
        find.text('Confirm this determination before saving.'),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(CheckboxListTile),
        ),
      );
      await tapVisible(tester, find.text('SAVE'));
      expect(concern.resolved, isTrue);
      expect(session.audit.last.details['previousAssessment'], 'confirmed');
      expect(session.audit.last.details['notActualConcern'], 'true');
      await manualApproval(tester, session);
    },
  );
}
