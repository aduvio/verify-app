enum AiObservationStatus {
  pending,
  confirmed,
  dismissed,
  furtherInspection,
}

class AiObservation {
  final String id;
  final String title;
  final String description;
  final String stage;
  final int confidencePercent;
  final bool requiresAction;
  AiObservationStatus status;

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
      !requiresAction || status != AiObservationStatus.pending;
}
