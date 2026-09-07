import 'package:flutter/material.dart';
import '../models/verification_item.dart';

class VerificationRow extends StatelessWidget {
  final VerificationItem item;

  const VerificationRow({
    super.key,
    required this.item,
  });

  Color get _statusColor {
    switch (item.status) {
      case VerificationStatus.verified:
        return Colors.green;
      case VerificationStatus.needsReview:
        return Colors.orange;
      case VerificationStatus.notAvailable:
      case VerificationStatus.notApplicable:
      case VerificationStatus.waiting:
        return Colors.grey;
    }
  }

  String get _statusText {
    switch (item.status) {
      case VerificationStatus.verified:
        return 'VERIFIED';
      case VerificationStatus.needsReview:
        return 'NEEDS REVIEW';
      case VerificationStatus.notAvailable:
        return 'NOT AVAILABLE';
      case VerificationStatus.notApplicable:
        return 'NOT APPLICABLE';
      case VerificationStatus.waiting:
        return 'WAITING';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              item.label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(flex: 3, child: Text(item.value)),
          Expanded(
            flex: 2,
            child: Text(
              item.source,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _statusText,
              style: TextStyle(
                color: _statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
