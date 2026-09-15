import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/wearables_service.dart';

class WearablesTestScreen extends StatefulWidget {
  const WearablesTestScreen({super.key, this.service});
  final WearablesService? service;

  @override
  State<WearablesTestScreen> createState() => _WearablesTestScreenState();
}

class _WearablesTestScreenState extends State<WearablesTestScreen> {
  late final controller = WearablesController(
    widget.service ?? IOSWearablesService(),
  );

  @override
  void initState() {
    super.initState();
    controller.initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Wearables Connection Test')),
    body: ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.status;
        final photo = state['photo'];
        Widget action(String label, String method, bool enabled) =>
            ElevatedButton(
              onPressed:
                  enabled && (!controller.busy || method == 'stopSession')
                  ? () => controller.run(method)
                  : null,
              child: Text(label),
            );
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('DEVELOPER TEST • Meta DAT 0.9.0 preview'),
            const Text(
              'No inspection evidence is saved. No audio capture is implemented. '
              'Connection and image reception have not yet been physically validated.',
            ),
            const SizedBox(height: 16),
            Text(
              'SDK: ${controller.available ? "Available in native build" : "Unavailable / checking"}',
            ),
            Text('Registration: ${state['registration'] ?? "Unknown"}'),
            Text('Devices: ${state['devices'] ?? "Not checked"}'),
            Text('Session: ${state['session'] ?? "Not started"}'),
            Text('Camera: ${state['camera'] ?? "Not requested"}'),
            Text('Stream: ${state['stream'] ?? "Stopped"}'),
            Text('Video frames received: ${state['frames'] ?? 0}'),
            const Text(
              'A frame count confirms reception only; it is not a saved recording.',
            ),
            if (controller.error != null)
              Text(
                controller.error!,
                style: const TextStyle(color: Colors.red),
              ),
            if (controller.busy) const LinearProgressIndicator(),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                action('Refresh status', 'status', true),
                action(
                  'Register with Meta AI',
                  'register',
                  controller.available && !controller.registered,
                ),
                action(
                  'Start glasses session',
                  'startSession',
                  controller.registered &&
                      (state['session'] == null ||
                          state['session'] == 'stopped'),
                ),
                action(
                  'Request glasses camera',
                  'requestCamera',
                  controller.sessionStarted &&
                      state['camera'] == 'Not requested',
                ),
                action(
                  'Start video stream (no audio)',
                  'startStream',
                  controller.sessionStarted &&
                      state['camera'] != 'Not requested' &&
                      !controller.streaming,
                ),
                action('Stop video stream', 'stopStream', controller.streaming),
                action(
                  'Capture test photo (memory only)',
                  'capturePhoto',
                  controller.streaming && state['photoPending'] != true,
                ),
                action(
                  'Stop session and release glasses',
                  'stopSession',
                  controller.available,
                ),
              ],
            ),
            if (photo is Uint8List) ...[
              const SizedBox(height: 16),
              const Text(
                'Received test photo • memory only • cleared when session stops',
              ),
              Image.memory(
                photo,
                height: 240,
                errorBuilder: (_, _, _) => const Text(
                  'Photo received but image could not be displayed.',
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Prepare a non-sensitive scene before requesting the camera. '
              'Each capture operation requires your button press. '
              'Leaving the app stops the session; it never resumes capture automatically.',
            ),
          ],
        );
      },
    ),
  );
}
