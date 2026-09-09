import 'dart:async';

import 'package:verify_app/models/ai_observation.dart';
import 'package:verify_app/models/customer.dart';
import 'package:verify_app/models/inspection_session.dart';
import 'package:verify_app/models/vehicle.dart';
import 'package:verify_app/models/verification_item.dart';
import 'package:verify_app/services/mock_recording_service.dart';

class TestClock {
  DateTime now = DateTime.utc(2026, 9, 7, 12);
  DateTime call() => now;
  void advance(Duration amount) {
    now = now.add(amount);
  }
}

InspectionSession readySession({TestClock? clock}) {
  final session = InspectionSession(
    id: 'DEMO-test',
    technician: 'Test Technician',
    clock: clock?.call,
  );
  session.setCustomer(
    const Customer(
      firstName: 'Intake',
      lastName: 'Customer',
      phone: '504-555-0199',
    ),
  );
  session.setVehicle(
    const Vehicle(
      vin: 'DEMO-ONLY',
      year: 2024,
      make: 'Sample',
      model: 'Vehicle',
      trim: 'Demo',
      engine: 'Sample',
      drivetrain: 'Sample',
    ),
    [
      const VerificationItem(
        label: 'Oil Viscosity',
        value: 'Unavailable in demo',
        source: 'AMSOIL',
        status: VerificationStatus.notAvailable,
      ),
    ],
  );
  session.simulateSquare();
  return session;
}

CaptureAttempt captureAndKeep(
  InspectionSession session,
  String stepId, {
  int seconds = 5,
}) {
  final attempt = session.beginCapture(
    stepId,
    stepId == 'dipstick' ? CaptureKind.photo : CaptureKind.video,
  );
  session.finishCapture(attempt, Duration(seconds: seconds));
  session.acceptCapture(attempt);
  return attempt;
}

void completeVehicleStage(InspectionSession session) {
  for (final step in session.underVehicleSteps) {
    if (session.usesVideo(step.id)) {
      captureAndKeep(session, step.id);
    } else {
      session.confirmStatement(step.id);
    }
  }
  session.setStage(true);
}

void completeChecks(InspectionSession session) {
  completeVehicleStage(session);
  for (final step in session.underHoodSteps) {
    if (session.usesVideo(step.id) || step.id == 'dipstick') {
      captureAndKeep(session, step.id);
    }
    if (!session.usesVideo(step.id)) {
      session.confirmStatement(step.id);
    }
  }
}

AiObservation addConcern(InspectionSession session) {
  final observation = AiObservation(
    id: 'critical',
    title: 'Synthetic possible leak',
    description: 'No actual media analyzed',
    stage: 'Under Vehicle',
    confidencePercent: 0,
    requiresAction: true,
  );
  session.loadObservations([observation]);
  return observation;
}

void acknowledge(InspectionSession session) {
  for (var i = 0; i < 4; i++) {
    session.setApproval(i, true);
  }
}

class ControlledRecordingService implements RecordingService {
  Completer<void>? startGate;
  Completer<void>? stopGate;
  Completer<void>? retryGate;
  bool failStart = false;
  bool failStop = false;
  bool failRetry = false;
  int starts = 0;
  int stops = 0;
  int retries = 0;
  final List<String> cancelled = [];
  @override
  Future<void> startSegment(String attemptId) async {
    starts++;
    if (failStart) throw StateError('start failed');
    if (startGate != null) await startGate!.future;
  }

  @override
  Future<void> stopSegment(String attemptId) async {
    stops++;
    if (failStop) throw StateError('stop failed');
    if (stopGate != null) await stopGate!.future;
  }

  @override
  Future<void> prepareRetake(String attemptId) async {
    retries++;
    if (failRetry) throw StateError('retake failed');
    if (retryGate != null) await retryGate!.future;
  }

  @override
  void cancel(String attemptId) {
    cancelled.add(attemptId);
  }
}
