import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/inspection_session.dart';
import 'mock_recording_service.dart';

/// Serializes capture work and ignores late results after screen/session exit.
class CaptureController extends ChangeNotifier {
  final InspectionSession session;
  final RecordingService service;
  final SessionClock clock;
  CaptureController(this.session, this.service, {SessionClock? clock})
    : clock = clock ?? session.clock;
  bool pending = false;
  bool _disposed = false;
  int _generation = 0;
  CaptureAttempt? activeAttempt;
  DateTime? _startedAt;
  Timer? _timer;
  String? error;
  bool get locked => pending || activeAttempt != null;
  Duration get elapsed =>
      _startedAt == null ? Duration.zero : clock().difference(_startedAt!);
  CaptureAttempt? get awaitingReview {
    final attempts = session.attempts.where(
      (a) => a.status == CaptureStatus.review,
    );
    return attempts.isEmpty ? null : attempts.last;
  }

  bool _valid(int generation) =>
      !_disposed && session.active && generation == _generation;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start(
    String stepId, {
    CaptureKind kind = CaptureKind.video,
  }) async {
    if (_disposed || !session.active || locked || awaitingReview != null) {
      return;
    }
    pending = true;
    error = null;
    final generation = ++_generation;
    _notify();
    CaptureAttempt? attempt;
    try {
      attempt = session.beginCapture(stepId, kind);
      activeAttempt = attempt;
      await service.startSegment(attempt.id);
      if (!_valid(generation) || attempt.status != CaptureStatus.starting) {
        session.cancelCapture(attempt);
        if (!_disposed && generation == _generation) cancel();
        return;
      }
      if (kind == CaptureKind.photo) {
        session.finishCapture(attempt, Duration.zero);
        activeAttempt = null;
      } else {
        session.recordingStarted(attempt);
        _startedAt = clock();
        _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
          if (!session.active) {
            cancel();
          } else {
            _notify();
          }
        });
      }
    } catch (_) {
      if (_valid(generation)) {
        if (attempt != null) session.cancelCapture(attempt, failed: true);
        activeAttempt = null;
        error = 'Simulated capture could not start. Please retry.';
      }
    } finally {
      if (_valid(generation)) {
        pending = false;
        _notify();
      }
    }
  }

  Future<void> stop() async {
    final attempt = activeAttempt;
    if (_disposed ||
        pending ||
        attempt == null ||
        attempt.status != CaptureStatus.recording) {
      return;
    }
    pending = true;
    error = null;
    final generation = _generation;
    final duration = elapsed;
    _timer?.cancel();
    _notify();
    try {
      await service.stopSegment(attempt.id);
      if (!_valid(generation) || attempt.status != CaptureStatus.recording) {
        session.cancelCapture(attempt);
        if (!_disposed && generation == _generation) cancel();
        return;
      }
      session.finishCapture(attempt, duration);
      if (attempt.status == CaptureStatus.rejected) {
        error =
            'Too short: ${session.step(attempt.stepId).minimumSeconds} seconds minimum. Simulate another clip.';
      }
    } catch (_) {
      if (_valid(generation)) {
        session.cancelCapture(attempt, failed: true);
        error = 'Simulated stop failed. Please retry the capture.';
      }
    } finally {
      if (_valid(generation)) {
        pending = false;
        activeAttempt = null;
        _startedAt = null;
        _notify();
      }
    }
  }

  void keep() {
    final attempt = awaitingReview;
    if (_disposed || locked || attempt == null) return;
    session.acceptCapture(attempt);
    _notify();
  }

  Future<void> retry() async {
    final attempt = awaitingReview;
    if (_disposed || locked || attempt == null) return;
    pending = true;
    error = null;
    final generation = ++_generation;
    _notify();
    try {
      await service.prepareRetake(attempt.id);
      if (_valid(generation)) session.retryCapture(attempt);
    } catch (_) {
      if (_valid(generation)) error = 'Could not prepare simulated retake. The attempt is retained; retry or keep it.';
    } finally {
      if (_valid(generation)) {
        pending = false;
        _notify();
      }
    }
  }

  void cancel() {
    ++_generation;
    _timer?.cancel();
    final attempt = activeAttempt;
    if (attempt != null) {
      if (_startedAt != null) attempt.duration = elapsed;
      service.cancel(attempt.id);
      session.cancelCapture(attempt);
    }
    // Completed attempts awaiting keep/retry remain reviewable on return.
    activeAttempt = null;
    _startedAt = null;
    pending = false;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    cancel();
    super.dispose();
  }
}
