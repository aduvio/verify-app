import 'package:flutter/material.dart';

import '../models/inspection_session.dart';

class SessionBanner extends StatelessWidget {
  final InspectionSession session;
  const SessionBanner({super.key, required this.session});
  @override
  Widget build(BuildContext context) => Card(
    color: Colors.amber.shade50,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DEMO ONLY • No real inspection approval',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text('${session.location} | Tech: ${session.technician}'),
          Text('Inspection: ${session.id}'),
          const Text(
            'Sample service data. Evidence controls distinguish real captured files from simulations. Screen controls are the glasses-first prototype/fallback. Check local save status before leaving. No cloud backup or cross-device sync.',
          ),
        ],
      ),
    ),
  );
}
