import 'package:flutter/material.dart';

import '../models/inspection_session.dart';
import '../models/local_media.dart';
import 'local_media_view.dart';

class EvidenceGallery extends StatelessWidget {
  final InspectionSession session;
  final List<LocalMedia>? snapshotMedia;
  final bool staff;
  const EvidenceGallery({
    super.key,
    required this.session,
    this.snapshotMedia,
    this.staff = false,
  });
  @override
  Widget build(BuildContext context) {
    final media =
        snapshotMedia ??
        session.attempts
            .where((a) => a.media != null && a.status == CaptureStatus.accepted)
            .map((a) => a.media!)
            .toList();
    Widget tile(LocalMedia m) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${session.step(m.stepId).label} • ${m.source == 'fixture' ? 'TEST FIXTURE' : 'Real captured media'} in a DEMO • ${m.byteSize} bytes • ${m.mimeType}',
          ),
          Text(
            '${m.technician} • ${m.capturedAt.toIso8601String()} • ${m.durationMs / 1000}s',
          ),
          if (session.pendingMedia.containsKey(m.id))
            const Text('Saving / save required — file not yet available.')
          else
            LocalMediaView(key: ValueKey(m.id), session: session, media: m),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final stage in ['Under Vehicle', 'Under Hood']) ...[
          Text(
            '$stage — local media',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (!media.any((m) => m.stage == stage))
            const Text(
              'No accepted real capture in this group. Simulated metadata is not playable.',
            ),
          ...media.where((m) => m.stage == stage).map(tile),
        ],
        if (staff &&
            session.attempts.any((a) => a.internalOnly && a.media != null))
          ExpansionTile(
            title: const Text('Staff-only earlier / rejected media'),
            children: [
              for (final a in session.attempts.where(
                (a) => a.internalOnly && a.media != null,
              )) ...[
                Text(
                  'Attempt ${a.id} • ${a.status.name} • excluded from customer report',
                ),
                tile(a.media!),
              ],
            ],
          ),
      ],
    );
  }
}
