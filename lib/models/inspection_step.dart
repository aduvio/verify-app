enum InspectionStepStatus {
  pending,
  recording,
  captured,
  needsRetry,
  confirmed,
}

class InspectionStep {
  final String id;
  final String label;
  final String guidance;
  final int minimumSeconds;
  final bool required;
  InspectionStepStatus status;
  int capturedSeconds;

  InspectionStep({
    required this.id,
    required this.label,
    required this.guidance,
    this.minimumSeconds = 0,
    this.required = true,
    this.status = InspectionStepStatus.pending,
    this.capturedSeconds = 0,
  });

  bool get isComplete => status == InspectionStepStatus.confirmed;
}
