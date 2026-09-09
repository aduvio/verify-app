import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:verify_app/models/inspection_session.dart';
import 'package:verify_app/services/capture_controller.dart';

import 'support.dart';

void main() {
  test(
    'changed vehicle cancels pending capture and ignores its stale start',
    () async {
      final session = readySession();
      final service = ControlledRecordingService()
        ..startGate = Completer<void>();
      final controller = CaptureController(session, service);
      addTearDown(controller.dispose);
      final operation = controller.start('drain_plug');
      session.setVehicle(session.vehicle!, session.verificationItems);
      service.startGate!.complete();
      await operation;
      expect(controller.locked, isFalse);
      expect(session.attempts.single.status, CaptureStatus.cancelled);
      expect(session.step('drain_plug').isComplete, isFalse);
    },
  );
  test('rapid starts and stops serialize into one capture operation', () async {
    final clock = TestClock();
    final session = readySession(clock: clock);
    final service = ControlledRecordingService()..startGate = Completer<void>();
    final controller = CaptureController(session, service);
    addTearDown(controller.dispose);
    final start = controller.start('drain_plug');
    await controller.start('oil_filter');
    await controller.start('drain_plug');
    expect(controller.pending, isTrue);
    expect(service.starts, 1);
    expect(session.attempts, hasLength(1));
    service.startGate!.complete();
    await start;
    clock.advance(const Duration(seconds: 5));
    service.stopGate = Completer<void>();
    final stop = controller.stop();
    await controller.stop();
    await controller.start('oil_filter');
    expect(service.stops, 1);
    expect(service.starts, 1);
    service.stopGate!.complete();
    await stop;
    expect(controller.awaitingReview!.status, CaptureStatus.review);
    expect(controller.awaitingReview!.duration, const Duration(seconds: 5));
    controller.keep();
    expect(session.step('drain_plug').isComplete, isTrue);
  });

  test(
    'dispose during pending start cancels metadata and ignores late completion',
    () async {
      final session = readySession();
      final service = ControlledRecordingService()
        ..startGate = Completer<void>();
      final controller = CaptureController(session, service);
      final start = controller.start('drain_plug');
      controller.dispose();
      expect(session.attempts.single.status, CaptureStatus.cancelled);
      expect(service.cancelled, [session.attempts.single.id]);
      service.startGate!.complete();
      await start;
      expect(session.attempts.single.status, CaptureStatus.cancelled);
      expect(session.step('drain_plug').isComplete, isFalse);
    },
  );

  test('dispose during pending stop ignores late completion', () async {
    final clock = TestClock();
    final session = readySession(clock: clock);
    final service = ControlledRecordingService()..stopGate = Completer<void>();
    final controller = CaptureController(session, service);
    await controller.start('drain_plug');
    clock.advance(const Duration(seconds: 6));
    final stop = controller.stop();
    controller.dispose();
    service.stopGate!.complete();
    await stop;
    expect(session.attempts.single.status, CaptureStatus.cancelled);
    expect(session.currentCapture('drain_plug'), isNull);
  });

  test('abandoned session cannot be changed by late capture result', () async {
    final session = readySession();
    final service = ControlledRecordingService()..startGate = Completer<void>();
    final controller = CaptureController(session, service);
    addTearDown(controller.dispose);
    final operation = controller.start('drain_plug');
    session.abandon();
    service.startGate!.complete();
    await operation;
    expect(session.attempts.single.status, CaptureStatus.cancelled);
    expect(session.demoReady, isFalse);
    expect(controller.locked, isFalse);
    expect(session.realApproved, isFalse);
  });

  test(
    'start and stop failures release locks and allow a successful retry',
    () async {
      final clock = TestClock();
      final session = readySession(clock: clock);
      final service = ControlledRecordingService()..failStart = true;
      final controller = CaptureController(session, service);
      addTearDown(controller.dispose);
      await controller.start('drain_plug');
      expect(controller.locked, isFalse);
      expect(controller.error, isNotNull);
      expect(session.attempts.last.status, CaptureStatus.failed);
      service.failStart = false;
      service.failStop = true;
      await controller.start('drain_plug');
      clock.advance(const Duration(seconds: 5));
      await controller.stop();
      expect(controller.locked, isFalse);
      expect(session.attempts.last.status, CaptureStatus.failed);
      service.failStop = false;
      await controller.start('drain_plug');
      clock.advance(const Duration(seconds: 5));
      await controller.stop();
      controller.keep();
      expect(session.attempts, hasLength(3));
      expect(session.step('drain_plug').isComplete, isTrue);
    },
  );

  test(
    'retake failures retain attempt; repeated retakes do not overlap',
    () async {
      final clock = TestClock();
      final session = readySession(clock: clock);
      final service = ControlledRecordingService();
      final controller = CaptureController(session, service);
      addTearDown(controller.dispose);
      await controller.start('drain_plug');
      clock.advance(const Duration(seconds: 5));
      await controller.stop();
      service.failRetry = true;
      await controller.retry();
      expect(controller.pending, isFalse);
      expect(controller.awaitingReview, isNotNull);
      expect(controller.error, isNotNull);
      service.failRetry = false;
      service.retryGate = Completer<void>();
      final retry = controller.retry();
      await controller.retry();
      controller.keep();
      expect(
        service.retries,
        2,
      ); // One failed operation and one pending operation.
      expect(session.attempts.single.status, CaptureStatus.review);
      service.retryGate!.complete();
      await retry;
      expect(session.attempts.single.status, CaptureStatus.superseded);
      expect(session.attempts.single.internalOnly, isTrue);
      expect(controller.locked, isFalse);
    },
  );

  test('leaving during pending retake retains a reviewable attempt', () async {
    final clock = TestClock();
    final session = readySession(clock: clock);
    final service = ControlledRecordingService();
    final controller = CaptureController(session, service);
    await controller.start('drain_plug');
    clock.advance(const Duration(seconds: 5));
    await controller.stop();
    service.retryGate = Completer<void>();
    final retry = controller.retry();
    controller.dispose();
    service.retryGate!.complete();
    await retry;
    expect(session.attempts.single.status, CaptureStatus.review);
    final next = CaptureController(session, service);
    expect(next.awaitingReview, same(session.attempts.single));
    next.keep();
    expect(session.step('drain_plug').isComplete, isTrue);
    next.dispose();
  });
}
