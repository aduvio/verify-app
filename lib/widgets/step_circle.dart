import 'package:flutter/material.dart';

class StepCircle extends StatelessWidget {
  final String number;
  final String label;
  final bool active;

  const StepCircle({
    super.key,
    required this.number,
    required this.label,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: active ? Colors.blue : Colors.grey.shade300,
          foregroundColor: active ? Colors.white : Colors.black54,
          child: Text(number),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: active ? Colors.blue : Colors.grey,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
