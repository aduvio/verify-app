enum VerificationStatus {
  waiting,
  verified,
  needsReview,
  notAvailable,
  notApplicable,
}

class VerificationItem {
  final String label;
  final String value;
  final String source;
  final VerificationStatus status;

  const VerificationItem({
    required this.label,
    required this.value,
    required this.source,
    required this.status,
  });
}
