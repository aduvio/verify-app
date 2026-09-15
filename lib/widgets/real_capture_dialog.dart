import 'package:flutter/material.dart';

import '../models/inspection_session.dart';
import '../services/browser_camera.dart';
import '../services/real_capture_controller.dart';
import '../services/camera_service.dart';
import 'local_media_view.dart';

Future<void> showRealCapture(
  BuildContext context,
  InspectionSession session,
  String stepId,
  CaptureKind kind, {
  CameraService? cameraService,
}) async {
  final service = cameraService ?? createCameraService();
  if (service == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Real capture requires the Chrome web app. No simulation was substituted.',
        ),
      ),
    );
    return;
  }
  final controller = RealCaptureController(session, service, stepId, kind);
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CaptureDialog(controller),
  );
}

class _CaptureDialog extends StatefulWidget {
  final RealCaptureController controller;
  const _CaptureDialog(this.controller);
  @override
  State<_CaptureDialog> createState() => _CaptureDialogState();
}

class _CaptureDialogState extends State<_CaptureDialog> {
  bool microphone = false;
  late final preview = widget.controller.service.preview();
  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      return AlertDialog(
        title: Text('Real ${c.kind.name} — demo inspection'),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Capture is not proof of service condition. No AI analysis, glasses control or upload. Use non-sensitive test footage.',
                ),
                Text(
                  c.cameraActive
                      ? 'CAMERA ACTIVE${c.audio ? ' • MICROPHONE ACTIVE' : ' • NO AUDIO'}${c.recording ? ' • RECORDING' : ' • PREVIEW ONLY'}'
                      : 'Camera and microphone off (or awaiting permission).',
                ),
                if (c.pending) const LinearProgressIndicator(),
                SizedBox(height: 220, child: preview),
                if (c.error != null)
                  Text(c.error!, style: const TextStyle(color: Colors.red)),
                if (c.attempt == null) ...[
                  SwitchListTile(
                    title: const Text('Include microphone narration'),
                    subtitle: const Text(
                      'Off by default. Enable before requesting permission. Check the displayed microphone name before Start; review playback to confirm audible narration.',
                    ),
                    value: microphone,
                    onChanged: c.pending || c.cameraActive
                        ? null
                        : (v) => setState(() => microphone = v),
                  ),
                  FilledButton(
                    onPressed: c.pending || c.cameraActive
                        ? null
                        : () => c.enable(microphone),
                    child: const Text('ENABLE CAMERA — REQUEST PERMISSION'),
                  ),
                ],
                if (c.attempt == null || c.recording)
                  FilledButton(
                    onPressed: c.pending || !c.cameraActive
                        ? null
                        : c.recording
                        ? c.stop
                        : c.capture,
                    child: Text(
                      c.recording
                          ? 'STOP AND VALIDATE CLIP'
                          : c.kind == CaptureKind.photo
                          ? 'TAKE ACTUAL PHOTO'
                          : 'START ACTUAL VIDEO',
                    ),
                  ),
                if (c.attempt != null && !c.recording && !c.pending)
                  const Text(
                    'Return to the inspection to review the saved result, Keep, or Record Again. Nothing is automatically accepted.',
                  ),
                if (!c.pending &&
                    c.attempt?.status == CaptureStatus.review) ...[
                  Text(
                    c.attempt!.mediaSaved
                        ? 'Saved locally, awaiting review — not accepted.'
                        : 'Save required before Keep. Return to inspection to retry saving.',
                  ),
                  if (c.attempt!.mediaSaved && c.attempt!.media != null)
                    LocalMediaView(
                      session: c.session,
                      media: c.attempt!.media!,
                    ),
                  FilledButton(
                    onPressed: !c.attempt!.mediaSaved
                        ? null
                        : () async {
                            c.session.acceptCapture(c.attempt!);
                            await c.session.flush();
                            if (context.mounted) Navigator.pop(context);
                          },
                    child: const Text('KEEP — RECORDING IS SUFFICIENT'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      c.session.retryCapture(c.attempt!);
                      Navigator.pop(context);
                    },
                    child: const Text('RECORD AGAIN'),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              c.recording || c.pending
                  ? 'CANCEL CAPTURE AND CLOSE'
                  : 'RETURN TO INSPECTION',
            ),
          ),
        ],
      );
    },
  );
}
