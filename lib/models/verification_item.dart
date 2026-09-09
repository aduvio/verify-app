import 'provenance.dart';

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
  final DataProvenance provenance;

  bool get genuinelyVerified =>
      provenance == DataProvenance.verifiedProvider &&
      status == VerificationStatus.verified;

  String get displayStatus => provenance == DataProvenance.sample
      ? 'DEMO • UNVERIFIED'
      : genuinelyVerified
      ? 'VERIFIED'
      : 'NOT VERIFIED';

  const VerificationItem({
    required this.label,
    required this.value,
    required this.source,
    required this.status,
    this.provenance = DataProvenance.sample,
  });
}
