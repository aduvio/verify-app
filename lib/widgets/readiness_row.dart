import 'package:flutter/material.dart';

class ReadinessRow extends StatelessWidget {
  final String label;
  final bool complete;

  const ReadinessRow({
    super.key,
    required this.label,
    required this.complete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            complete ? Icons.check_circle : Icons.radio_button_unchecked,
            color: complete ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }
}
