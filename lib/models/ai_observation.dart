import 'provenance.dart';

enum AiObservationStatus { pending, confirmed, dismissed, furtherInspection }

extension AiObservationStatusLabel on AiObservationStatus {
  String get label => switch (this) {
    AiObservationStatus.pending => 'Not yet assessed',
    AiObservationStatus.confirmed => 'Concern confirmed',
    AiObservationStatus.dismissed => 'Dismissed — not an actual concern',
    AiObservationStatus.furtherInspection => 'Needs further inspection',
  };
}

class AiObservation {
  final String id;
  final String title;
  final String description;
  final String stage;
  final int confidencePercent;
  final bool requiresAction;
  final DataProvenance provenance = DataProvenance.sample;
  AiObservationStatus status;
  String? decisionReason;
  String? decidedBy;
  DateTime? decidedAt;
  String? correctiveAction;
  String? recheck;
  String? addressedBy;
  DateTime? addressedAt;
  bool recheckPassed = false;
  // Current assessment only; previous assessments remain in the session audit.
  bool concernEstablished = false;

  String get nextAction {
    if (!requiresAction) return 'Advisory only; no required concern to clear.';
    if (resolved) {
      return status == AiObservationStatus.dismissed
          ? 'Dismissed with a technician reason. Independent required checks still apply.'
          : 'Simulated correction and successful recheck recorded. Independent required checks still apply.';
    }
    return switch (status) {
      AiObservationStatus.pending => 'Assess this observation: confirm a problem, request further inspection, or dismiss it only if it is not an actual concern.',
      AiObservationStatus.furtherInspection => 'Arrange further inspection (for example, by a mechanic). Then select CONFIRM CONCERN if a problem exists and record the simulated correction and recheck. Select DISMISS WITH REASON only if it is not an actual concern.',
      AiObservationStatus.confirmed =>
        recheckPassed
            ? 'Record both the correction and recheck description before this concern can clear.'
            : 'Select RECORD SIMULATED CORRECTION + RECHECK. Describe the correction and recheck, and explicitly confirm success. A failed or incomplete recheck stays blocking.',
      AiObservationStatus.dismissed => 'A dismissal requires a technician reason and acknowledgment that this is not an actual concern.',
    };
  }

  AiObservation({
    required this.id,
    required this.title,
    required this.description,
    required this.stage,
    required this.confidencePercent,
    required this.requiresAction,
    this.status = AiObservationStatus.pending,
  });

  bool get resolved =>
      !requiresAction ||
      (status == AiObservationStatus.dismissed &&
          !concernEstablished &&
          (decisionReason?.trim().isNotEmpty ?? false) &&
          decidedBy != null &&
          decidedAt != null) ||
      (concernEstablished &&
          (status == AiObservationStatus.confirmed ||
              status == AiObservationStatus.dismissed) &&
          recheckPassed &&
          (correctiveAction?.trim().isNotEmpty ?? false) &&
          (recheck?.trim().isNotEmpty ?? false) &&
          addressedBy != null &&
          addressedAt != null);
}
