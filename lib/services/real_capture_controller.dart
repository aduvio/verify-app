import 'package:flutter/foundation.dart';

import '../models/inspection_session.dart';
import 'camera_service.dart';

class RealCaptureController extends ChangeNotifier {
  final InspectionSession session;
  final CameraService service;
  final String stepId;
  final CaptureKind kind;
  bool pending = false,
      cameraActive = false,
      recording = false,
      disposed = false;
  bool audio = false;
  int generation = 0;
  String? error;
  CaptureAttempt? attempt;
  RealCaptureController(this.session, this.service, this.stepId, this.kind);
  void changed() {
    if (!disposed) notifyListeners();
  }

  bool valid(int token) =>
      !disposed &&
      generation == token &&
      session.editable &&
      (attempt == null ||
          attempt!.status == CaptureStatus.starting ||
          attempt!.status == CaptureStatus.recording);
  Future<void> enable(bool microphone) async {
    if (pending || cameraActive || disposed) return;
    pending = true;
    error = null;
    final token = ++generation;
    changed();
    try {
      await service.open(audio: microphone);
      if (!valid(token)) {
        service.dispose();
        return;
      }
      audio = microphone;
      cameraActive = true;
    } catch (e) {
      if (!disposed) error = '$e';
    } finally {
      if (!disposed) {
        pending = false;
        changed();
      }
    }
  }

  Future<void> capture() async {
    if (pending || disposed || !cameraActive || recording) return;
    pending = true;
    error = null;
    final token = generation;
    changed();
    try {
      attempt = session.beginCapture(stepId, kind, realMedia: true);
      if (kind == CaptureKind.photo) {
        final result = await service.photo();
        cameraActive = false;
        if (!valid(token)) {
          session.cancelCapture(attempt!);
          return;
        }
        session.finishRealCapture(attempt!, result);
        if (!await session.flush() && !disposed) error = 'Media save failed. Retry saving before Keep; this is not accepted evidence.';
      } else {
        await service.start();
        if (!valid(token)) {
          service.dispose();
          session.cancelCapture(attempt!);
          return;
        }
        session.recordingStarted(attempt!);
        recording = true;
      }
    } catch (e) {
      if (attempt != null) session.cancelCapture(attempt!, failed: true);
      if (!disposed) error = '$e';
      service.dispose();
      cameraActive = false;
    } finally {
      if (!disposed) {
        pending = false;
        changed();
      }
    }
  }

  Future<void> stop() async {
    if (pending || disposed || !recording || attempt == null) return;
    pending = true;
    error = null;
    final token = generation;
    changed();
    try {
      final result = await service.stop();
      if (!valid(token)) {
        session.cancelCapture(attempt!);
        return;
      }
      session.finishRealCapture(attempt!, result);
      if (attempt!.status == CaptureStatus.rejected) {
        error =
            'Finalized clip is below the ${session.step(stepId).minimumSeconds}-second minimum. It remains staff-only; record again.';
      }
      if (!await session.flush() && !disposed) {
        error =
            'Media save failed. Retry saving; evidence cannot be accepted yet.';
      }
    } catch (e) {
      session.cancelCapture(attempt!, failed: true);
      if (!disposed) error = '$e';
    } finally {
      service.dispose();
      if (!disposed) {
        recording = false;
        cameraActive = false;
        pending = false;
        changed();
      }
    }
  }

  @override
  void dispose() {
    disposed = true;
    generation++;
    service.dispose();
    if (attempt != null) session.cancelCapture(attempt!);
    super.dispose();
  }
}
