import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/inspection_session.dart';
import '../models/local_media.dart';
import 'media_player_stub.dart'
    if (dart.library.js_interop) 'media_player_web.dart';

class LocalMediaView extends StatefulWidget {
  final InspectionSession session;
  final LocalMedia media;
  const LocalMediaView({super.key, required this.session, required this.media});
  @override
  State<LocalMediaView> createState() => _LocalMediaViewState();
}

class _LocalMediaViewState extends State<LocalMediaView> {
  late final Future<Uint8List?> bytes = read();
  Future<Uint8List?> read() async {
    if (widget.media.inspectionId != widget.session.id) return null;
    final data = await widget.session.loadMedia?.call(widget.media.id);
    return data != null && widget.media.matches(data) ? data : null;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: bytes,
    builder: (context, value) {
      if (value.connectionState != ConnectionState.done) {
        return const Text('Loading saved local media…');
      }
      if (value.hasError || value.data == null) {
        return const Text(
          'Missing or corrupt local file. No playable media available. Keep browser data for recovery.',
        );
      }
      return SizedBox(
        height: 260,
        child: mediaPlayer(value.data!, widget.media.mimeType),
      );
    },
  );
}
