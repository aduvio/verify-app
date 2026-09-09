import 'package:flutter/material.dart';

import '../models/verification_item.dart';

class VerificationRow extends StatelessWidget {
  final VerificationItem item;
  const VerificationRow({super.key, required this.item});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final label = Text(
          item.label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        );
        final value = Text(item.value);
        final source = Text(
          'Future source: ${item.source}',
          style: const TextStyle(fontSize: 12),
        );
        final badge = Text(
          item.displayStatus,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: item.genuinelyVerified ? Colors.green : Colors.deepOrange,
          ),
        );
        if (constraints.maxWidth < 600) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [label, value, source, badge],
          );
        }
        return Row(
          children: [
            Expanded(flex: 3, child: label),
            Expanded(flex: 3, child: value),
            Expanded(flex: 2, child: source),
            badge,
          ],
        );
      },
    ),
  );
}
