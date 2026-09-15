import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:verify_app/models/ai_observation.dart';
import 'package:verify_app/models/inspection_session.dart';
import 'package:verify_app/models/provenance.dart';
import 'package:verify_app/models/verification_item.dart';
import 'package:verify_app/services/inspection_repository.dart';
import 'package:verify_app/services/mock_verification_service.dart';
import 'package:verify_app/services/mock_ai_review_service.dart';

import 'support.dart';

void main() {
  test('correcting an accidental confirmation requires explicit not-an-actual-concern determination and preserves audit', () {
    final session = readySession();
    completeChecks(session);
    final concern = addConcern(session);
    session.decide(
      concern,
      AiObservationStatus.confirmed,
      'Underlying concern exists',
    );
    expect(
      () => session.decide(
        concern,
        AiObservationStatus.dismissed,
        'Advisory wording was inaccurate',
      ),
      throwsArgumentError,
    );
    expect(concern.status, AiObservationStatus.confirmed);
    expect(concern.resolved, isFalse);
    session.decide(
      concern,
      AiObservationStatus.dismissed,
      'Earlier confirmation was accidental; inspection found no actual concern.',
      notActualConcern: true,
    );
    expect(concern.status, AiObservationStatus.dismissed);
    expect(concern.concernEstablished, isFalse);
    expect(concern.resolved, isTrue);
    expect(session.approvals, everyElement(isFalse));
    expect(
      session.audit
          .where((e) => e.action == 'observation_assessed')
          .map((e) => e.details['assessment']),
      ['confirmed', 'dismissed'],
    );
    expect(session.audit.last.details['previousAssessment'], 'confirmed');
    expect(session.audit.last.details['notActualConcern'], 'true');
  });
  test('an unsuccessful documented recheck leaves the concern blocking', () {
    final session = readySession();
    completeChecks(session);
    final concern = addConcern(session);
    session.decide(concern, AiObservationStatus.confirmed, 'Concern confirmed');
    session.addressConcern(
      concern,
      'Attempted correction',
      'Concern remains',
      recheckPassed: false,
    );
    expect(concern.resolved, isFalse);
    expect(session.flagsResolved, isFalse);
    expect(session.audit.last.details['recheckPassed'], 'false');
    acknowledge(session);
    expect(session.completeDemo(), isFalse);
  });

  test('capture metadata from another session cannot complete a check', () {
    final first = readySession();
    final second = readySession();
    final attempt = first.beginCapture('drain_plug', CaptureKind.video);
    first.finishCapture(attempt, const Duration(seconds: 5));
    second.acceptCapture(attempt);
    expect(second.step('drain_plug').isComplete, isFalse);
    expect(second.attempts, isEmpty);
    expect(attempt.status, CaptureStatus.review);
  });
  test('mock provider results never qualify as genuinely verified', () async {
    final results = await MockVerificationService().verifyVehicle();
    expect(results, hasLength(5));
    for (final item in results) {
      expect(item.provenance, DataProvenance.sample);
      expect(item.genuinelyVerified, isFalse);
      expect(item.status, isNot(VerificationStatus.verified));
      expect(item.displayStatus, 'DEMO • UNVERIFIED');
    }
    const mislabeled = VerificationItem(
      label: 'Sample',
      value: 'Unavailable',
      source: 'Mock',
      status: VerificationStatus.verified,
    );
    expect(mislabeled.genuinelyVerified, isFalse);
    expect(mislabeled.displayStatus, 'DEMO • UNVERIFIED');
    expect(readySession().realServiceReady, isFalse);
  });

  test('unique sessions and repository preserve identity and timestamps', () {
    final clock = TestClock();
    final repository = InMemoryInspectionRepository(clock: clock.call);
    final first = repository.create(technician: 'Employee A');
    final second = repository.create(technician: 'Employee B');
    expect(first.id, isNot(second.id));
    expect(repository.find(first.id), same(first));
    expect(first.createdAt, clock.now);
    clock.advance(const Duration(minutes: 1));
    first.setNote('Internal', customerVisible: false, author: 'Employee C');
    expect(first.internalNote!.author, 'Employee C');
    expect(first.updatedAt, clock.now);
    expect(first.internalNote!.updatedAt, clock.now);
    expect(first.audit.last.actor, 'Employee C');
  });

  test('explicit demo can complete but never produces real approval', () {
    final session = readySession();
    expect(session.demoReady, isTrue);
    completeChecks(session);
    final concern = addConcern(session);
    session.decide(
      concern,
      AiObservationStatus.dismissed,
      'Synthetic scenario reviewed, concern not present in demo.',
      notActualConcern: true,
    );
    expect(session.approvals, everyElement(isFalse));
    acknowledge(session);
    expect(session.completeDemo(), isTrue);
    expect(session.demoApproved, isTrue);
    expect(session.realApproved, isFalse);
    expect(session.realServiceReady, isFalse);
  });

  for (final state in [
    AiObservationStatus.pending,
    AiObservationStatus.furtherInspection,
    AiObservationStatus.confirmed,
  ]) {
    test('$state required concern blocks approval', () {
      final session = readySession();
      completeChecks(session);
      final concern = addConcern(session);
      if (state != AiObservationStatus.pending) {
        session.decide(concern, state, 'Technician assessment');
      }
      acknowledge(session);
      expect(concern.resolved, isFalse);
      expect(session.flagsResolved, isFalse);
      expect(session.canCompleteDemo, isFalse);
      expect(session.completeDemo(), isFalse);
      expect(session.approvals, everyElement(isFalse));
    });
  }

  test('critical correction requires explicit action and recheck; boxes stay manual', () {
    final clock = TestClock();
    final session = readySession(clock: clock);
    completeChecks(session);
    final concern = addConcern(session);
    session.decide(
      concern,
      AiObservationStatus.confirmed,
      'Concern exists in the scenario.',
    );
    expect(
      () => session.addressConcern(
        concern,
        'Cleaned area',
        '',
        recheckPassed: true,
      ),
      throwsArgumentError,
    );
    expect(
      () => session.addressConcern(
        concern,
        '',
        'No leak after recheck',
        recheckPassed: true,
      ),
      throwsArgumentError,
    );
    expect(concern.resolved, isFalse);
    clock.advance(const Duration(minutes: 1));
    session.addressConcern(
      concern,
      'Corrected and cleaned area',
      'Rechecked; concern cleared in demo',
      recheckPassed: true,
    );
    expect(concern.resolved, isTrue);
    expect(concern.addressedBy, session.technician);
    expect(concern.addressedAt, clock.now);
    expect(session.approvals, everyElement(isFalse));
    expect(session.canCompleteDemo, isFalse);
    acknowledge(session);
    expect(session.canCompleteDemo, isTrue);
  });

  test('dismissal needs reason, identity, timestamp and cannot clear a failed check', () {
    final clock = TestClock();
    final session = readySession(clock: clock);
    completeChecks(session);
    final concern = addConcern(session);
    expect(
      () => session.decide(
        concern,
        AiObservationStatus.dismissed,
        '  ',
        notActualConcern: true,
      ),
      throwsArgumentError,
    );
    expect(concern.status, AiObservationStatus.pending);
    session.failCheck('drain_plug', 'Required check failed');
    session.decide(
      concern,
      AiObservationStatus.dismissed,
      'This advisory was unrelated to the failed check.',
      notActualConcern: true,
    );
    expect(concern.resolved, isTrue);
    expect(concern.decidedBy, session.technician);
    expect(concern.decidedAt, clock.now);
    expect(session.step('drain_plug').isComplete, isFalse);
    acknowledge(session);
    expect(session.completeDemo(), isFalse);
    final audit = session.audit.lastWhere(
      (e) => e.action == 'observation_assessed',
    );
    expect(audit.details['reason'], concern.decisionReason);
    expect(audit.actor, session.technician);
  });

  test('decision changes invalidate approval and retain audit history', () {
    final session = readySession();
    completeChecks(session);
    final concern = addConcern(session);
    session.decide(
      concern,
      AiObservationStatus.dismissed,
      'First assessment',
      notActualConcern: true,
    );
    acknowledge(session);
    expect(session.completeDemo(), isTrue);
    session.decide(
      concern,
      AiObservationStatus.furtherInspection,
      'New concern',
    );
    expect(session.approvals, everyElement(isFalse));
    expect(session.demoApproved, isFalse);
    expect(
      session.audit
          .where((e) => e.action == 'observation_assessed')
          .map((e) => e.details['reason']),
      ['First assessment', 'New concern'],
    );
  });

  test(
    'changed evidence invalidates decisions, recheck and dependent approval',
    () {
      final session = readySession();
      completeChecks(session);
      final concern = addConcern(session);
      session.decide(
        concern,
        AiObservationStatus.confirmed,
        'Concern confirmed',
      );
      session.addressConcern(
        concern,
        'Corrected',
        'Rechecked and cleared',
        recheckPassed: true,
      );
      acknowledge(session);
      session.completeDemo();
      session.setStage(false);
      session.beginCapture('drain_plug', CaptureKind.video);
      expect(session.approvals, everyElement(isFalse));
      expect(session.demoApproved, isFalse);
      expect(concern.status, AiObservationStatus.pending);
      expect(concern.resolved, isFalse);
      expect(concern.recheck, isNull);
    },
  );

  for (final id in ['drain_plug', 'oil_filter', 'top_filter']) {
    for (final milliseconds in [4999, 5000]) {
      test('$id at ${milliseconds}ms enforces minimum before keep/retry', () {
        final session = readySession();
        if (id == 'oil_filter') captureAndKeep(session, 'drain_plug');
        if (id == 'top_filter') {
          session.setFilterUnderHood(true);
          completeVehicleStage(session);
        }
        final attempt = session.beginCapture(id, CaptureKind.video);
        session.finishCapture(attempt, Duration(milliseconds: milliseconds));
        expect(
          attempt.status,
          milliseconds < 5000 ? CaptureStatus.rejected : CaptureStatus.review,
        );
        expect(session.step(id).isComplete, isFalse);
        session.acceptCapture(attempt);
        expect(session.step(id).isComplete, milliseconds >= 5000);
        expect(attempt.inspectionId, session.id);
        expect(attempt.technician, session.technician);
        expect(attempt.duration.inMilliseconds, milliseconds);
      });
    }
  }

  test('moving filter keeps required check and invalidates former location evidence', () {
    final session = readySession();
    captureAndKeep(session, 'drain_plug');
    final previous = captureAndKeep(session, 'oil_filter');
    session.setFilterUnderHood(true);
    expect(
      session.underVehicleSteps.map((s) => s.id),
      isNot(contains('oil_filter')),
    );
    expect(session.underHoodSteps.first.id, 'top_filter');
    expect(session.step('top_filter').minimumSeconds, 5);
    expect(session.step('top_filter').required, isTrue);
    expect(previous.status, CaptureStatus.superseded);
    completeVehicleStage(session);
    expect(session.allChecksComplete, isFalse);
    session.setStage(false);
    session.setFilterUnderHood(false);
    expect(session.step('oil_filter').isComplete, isFalse);
    expect(session.step('oil_filter').minimumSeconds, 5);
  });

  test('photo then reinsertion precede cap sequence; failed retake cannot reuse old photo', () {
    final session = readySession();
    completeVehicleStage(session);
    expect(
      session.underHoodSteps.map((s) => s.id).toList().indexOf('dipstick'),
      lessThan(
        session.underHoodSteps.map((s) => s.id).toList().indexOf('caps_touch'),
      ),
    );
    session.confirmStatement('dipstick');
    expect(session.step('dipstick').isComplete, isFalse);
    expect(
      () => session.beginCapture('caps_touch', CaptureKind.video),
      throwsStateError,
    );
    final photo = captureAndKeep(session, 'dipstick');
    expect(photo.kind, CaptureKind.photo);
    expect(photo.provenance, DataProvenance.sample);
    expect(session.dipstickReinserted, isFalse);
    expect(session.canCapture('caps_touch'), isFalse);
    session.confirmStatement('dipstick');
    expect(session.canCapture('caps_touch'), isTrue);
    captureAndKeep(session, 'caps_touch');
    final replacement = session.beginCapture('dipstick', CaptureKind.photo);
    session.cancelCapture(replacement, failed: true);
    session.confirmStatement('dipstick');
    expect(session.dipstickReinserted, isFalse);
    expect(session.step('caps_touch').isComplete, isFalse);
    expect(session.canCapture('caps_touch'), isFalse);
  });

  test('retakes preserve superseded internal metadata and replace current only when accepted', () {
    final session = readySession();
    final original = captureAndKeep(session, 'drain_plug');
    final rejectedReplacement = session.beginCapture(
      'drain_plug',
      CaptureKind.video,
    );
    session.finishCapture(rejectedReplacement, const Duration(seconds: 5));
    session.retryCapture(rejectedReplacement);
    expect(rejectedReplacement.status, CaptureStatus.superseded);
    expect(rejectedReplacement.internalOnly, isTrue);
    expect(session.currentCapture('drain_plug'), same(original));
    final replacement = captureAndKeep(session, 'drain_plug', seconds: 6);
    expect(session.attempts, hasLength(3));
    expect(original.status, CaptureStatus.superseded);
    expect(original.internalOnly, isTrue);
    expect(original.duration, const Duration(seconds: 5));
    expect(session.currentCapture('drain_plug'), same(replacement));
  });

  test('projection excludes internal notes, AI, and unverified facts with sample provenance intact', () {
    final session = readySession();
    final concern = addConcern(session);
    session.setNote('INTERNAL SECRET', customerVisible: false);
    session.setNote('Customer recommendation', customerVisible: true);
    session.decide(
      concern,
      AiObservationStatus.dismissed,
      'INTERNAL REASON',
      notActualConcern: true,
    );
    final projection = projectCustomerReport(session);
    final encoded = jsonEncode(projection);
    expect(encoded, isNot(contains('INTERNAL')));
    expect(encoded, isNot(contains(concern.title)));
    expect(encoded, contains('Customer recommendation'));
    expect(projection['verifiedFacts'], isEmpty);
    expect(projection['isDemo'], isTrue);
    expect(projection['realApproved'], isFalse);
    expect((projection['vehicle'] as Map)['provenance'], 'sample');
    expect(
      (projection['recommendation'] as Map)['provenance'],
      'technicianStatement',
    );
  });

  test('customer recommendation changes invalidate completed approval', () {
    final session = readySession();
    completeChecks(session);
    final concern = addConcern(session);
    session.decide(
      concern,
      AiObservationStatus.dismissed,
      'Reviewed',
      notActualConcern: true,
    );
    acknowledge(session);
    session.completeDemo();
    session.setNote('Changed recommendation', customerVisible: true);
    expect(session.demoApproved, isFalse);
    expect(session.approvals, everyElement(isFalse));
  });

  test('mock AI makes no actual dipstick interpretation claim', () async {
    final observations = await MockAiReviewService().loadObservations();
    final dipstick = observations.singleWhere((o) => o.id == 'oil_level');
    expect(
      dipstick.description,
      contains('has not seen or interpreted an actual dipstick image'),
    );
    expect(dipstick.status, AiObservationStatus.pending);
  });
}
