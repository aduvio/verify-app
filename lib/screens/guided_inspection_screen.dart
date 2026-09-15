import 'package:flutter/material.dart';

import '../widgets/session_save_boundary.dart';

import '../models/inspection_session.dart';
import '../models/inspection_step.dart';
import '../services/capture_controller.dart';
import '../services/inspection_repository.dart';
import '../services/mock_recording_service.dart';
import '../widgets/session_banner.dart';
import '../widgets/reason_dialog.dart';
import '../widgets/real_capture_dialog.dart';
import '../widgets/local_media_view.dart';
import 'ai_review_screen.dart';

class GuidedInspectionScreen extends StatefulWidget {
  final InspectionSession session;
  final InspectionRepository? repository;
  final RecordingService? recordingService;
  const GuidedInspectionScreen({
    super.key,
    required this.session,
    this.repository,
    this.recordingService,
  });
  @override
  State<GuidedInspectionScreen> createState() => _GuidedInspectionScreenState();
}

class _GuidedInspectionScreenState extends State<GuidedInspectionScreen> {
  InspectionSession get session => widget.session;
  late final capture = CaptureController(
    session,
    widget.recordingService ?? MockRecordingService(),
  );
  late final changes = Listenable.merge([session, capture]);
  @override
  void dispose() {
    capture.dispose();
    super.dispose();
  }

  Future<void> failCheck(InspectionStep step) async {
    final reasons = await requestReasons(context, 'Required check failed', [
      'Technician reason',
    ]);
    if (!mounted || reasons == null || capture.locked) return;
    session.failCheck(step.id, reasons.single);
  }

  Widget stepCard(InspectionStep step) {
    final blocked = capture.locked || capture.awaitingReview != null;
    final photo = step.id == 'dipstick';
    final video = session.usesVideo(step.id);
    final current = session.currentCapture(step.id);
    final controls = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (video || photo)
          OutlinedButton.icon(
            onPressed:
                !blocked &&
                    session.canCapture(step.id) &&
                    session.persistenceEnabled
                ? () => showRealCapture(
                    context,
                    session,
                    step.id,
                    photo ? CaptureKind.photo : CaptureKind.video,
                  )
                : null,
            icon: const Icon(Icons.camera_alt),
            label: Text(
              photo ? 'USE REAL CAMERA — PHOTO' : 'USE REAL CAMERA — VIDEO',
            ),
          ),
        if (video || photo)
          FilledButton.icon(
            key: ValueKey('capture-${step.id}'),
            onPressed: !blocked && session.canCapture(step.id)
                ? () => capture.start(
                    step.id,
                    kind: photo ? CaptureKind.photo : CaptureKind.video,
                  )
                : null,
            icon: Icon(photo ? Icons.photo_camera : Icons.videocam),
            label: Text(
              photo
                  ? (current == null ? 'SIMULATE PHOTO' : 'RETAKE DEMO PHOTO')
                  : (current == null ? 'SIMULATE CLIP' : 'RETAKE DEMO CLIP'),
            ),
          ),
        if (!video)
          FilledButton.icon(
            key: ValueKey('confirm-${step.id}'),
            onPressed:
                !blocked &&
                    !step.isComplete &&
                    (!photo ||
                        (current != null &&
                            step.status == InspectionStepStatus.captured))
                ? () => session.confirmStatement(step.id)
                : null,
            icon: const Icon(Icons.check),
            label: Text(
              photo ? 'CONFIRM DIPSTICK REINSERTED' : 'CONFIRM STATEMENT',
            ),
          ),
        OutlinedButton(
          onPressed: blocked ? null : () => failCheck(step),
          child: const Text('FLAG FAILED CHECK'),
        ),
      ],
    );
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          step.label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        Text(step.guidance),
        Text('Demo check: ${step.status.name}'),
        if (current != null)
          Text(
            current.realMedia
                ? 'Real ${current.kind.name} in a demo: ${current.duration.inMilliseconds / 1000}s • ${current.mediaSaved ? 'saved locally' : 'save required'}'
                : 'Simulated ${current.kind.name}: ${current.duration.inSeconds}s • metadata only',
          ),
        if (photo)
          Text(
            session.dipstickReinserted
                ? 'Technician confirmed reinsertion.'
                : 'Photo metadata and reinsertion are separate requirements.',
          ),
        if (current?.realMedia == true && !current!.mediaSaved)
          Text(
            session.pendingMedia.containsKey(current.id)
                ? 'Media save pending or failed. Retry saving before approval.'
                : 'Local file is missing or corrupt. Retake this evidence; the required check remains incomplete.',
          ),
        if (current?.realMedia == true &&
            current!.status == CaptureStatus.accepted) ...[
          const Text('Accepted by the technician — demo inspection.'),
          if (current.mediaSaved && current.media != null)
            ExpansionTile(
              title: const Text('PLAY ACCEPTED LOCAL RECORDING'),
              children: [
                LocalMediaView(session: session, media: current.media!),
              ],
            ),
        ],
        if (step.id == 'caps_touch' && !session.dipstickReinserted)
          const Text(
            'First keep the oil-level photo and confirm dipstick reinsertion.',
          ),
      ],
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  step.isComplete
                      ? Icons.check_circle
                      : step.status == InspectionStepStatus.needsRetry
                      ? Icons.error
                      : Icons.radio_button_unchecked,
                  color: step.isComplete ? Colors.green : Colors.grey,
                  size: 30,
                ),
                const SizedBox(width: 14),
                Expanded(child: info),
              ],
            ),
            const SizedBox(height: 12),
            controls,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SessionSaveBoundary(
    session: session,
    repository: widget.repository,
    child: buildScreen(context),
  );

  Widget buildScreen(BuildContext context) => AnimatedBuilder(
    animation: changes,
    builder: (context, _) {
      final stage = session.underHoodStage ? 'Under Hood' : 'Under Vehicle';
      final completed = session.currentSteps.where((s) => s.isComplete).length;
      final review = capture.awaitingReview;
      final free = !capture.locked && review == null;
      return Scaffold(
        backgroundColor: const Color(0xfff5f7fa),
        appBar: AppBar(
          title: const Text(
            'Project Verify — Guided Inspection',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SessionBanner(session: session),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Stage: $stage',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Targeted final-verification evidence only. The intended glasses interface is not connected.',
                          ),
                          const SizedBox(height: 16),
                          LinearProgressIndicator(
                            value: completed / session.currentSteps.length,
                          ),
                          Text(
                            '$completed of ${session.currentSteps.length} complete',
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!session.underHoodStage)
                    Card(
                      child: SwitchListTile(
                        title: const Text(
                          'Oil filter is located under the hood',
                        ),
                        subtitle: const Text(
                          'Moves the required five-second filter clip to the under-hood stage.',
                        ),
                        value: session.filterUnderHood,
                        onChanged: free ? session.setFilterUnderHood : null,
                      ),
                    ),
                  if (capture.pending)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: LinearProgressIndicator(),
                    ),
                  if (capture.error != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        capture.error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  if (capture.activeAttempt != null)
                    Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Text(
                              'SIMULATED CAPTURE • NO MEDIA FILE',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              session.step(capture.activeAttempt!.stepId).label,
                            ),
                            Text(
                              '${capture.elapsed.inSeconds}s',
                              style: const TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            FilledButton.icon(
                              key: const ValueKey('stop-capture'),
                              onPressed: capture.pending ? null : capture.stop,
                              icon: const Icon(Icons.stop),
                              label: const Text('STOP DEMO RECORDING'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (review != null)
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Review ${review.realMedia ? 'real captured' : 'simulated'} ${review.kind.name}: ${session.step(review.stepId).label}',
                            ),
                            if (review.realMedia && review.mediaSaved)
                              const Text(
                                'Saved locally, awaiting review — not accepted.',
                              ),
                            Text(
                              review.realMedia
                                  ? '${review.duration.inMilliseconds / 1000}s finalized media • ${review.mediaSaved ? 'Saved locally' : 'Save required before Keep'} • not proof of service condition'
                                  : '${review.duration.inSeconds}s • Metadata only; there is no image or video to inspect.',
                            ),
                            Text(
                              review.realMedia
                                  ? 'Review the actual file before Keep. Record Again retains this footage for staff only.'
                                  : 'Keep this demo attempt or simulate another. Earlier attempts remain internal metadata.',
                            ),
                            if (review.realMedia &&
                                review.mediaSaved &&
                                review.media != null)
                              LocalMediaView(
                                key: ValueKey(review.id),
                                session: session,
                                media: review.media!,
                              ),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                FilledButton(
                                  key: const ValueKey('keep-capture'),
                                  onPressed:
                                      capture.pending ||
                                          (review.realMedia &&
                                              !review.mediaSaved)
                                      ? null
                                      : capture.keep,
                                  child: Text(
                                    review.realMedia
                                        ? 'KEEP — RECORDING IS SUFFICIENT'
                                        : 'KEEP DEMO ATTEMPT',
                                  ),
                                ),
                                OutlinedButton(
                                  key: const ValueKey('retry-capture'),
                                  onPressed: capture.pending
                                      ? null
                                      : capture.retry,
                                  child: Text(
                                    review.kind == CaptureKind.photo
                                        ? 'CAPTURE AGAIN'
                                        : 'RECORD AGAIN',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  ...session.currentSteps.map(stepCard),
                  Card(
                    color: Colors.blue.shade50,
                    child: const Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        'AI Guidance (Mock): No glasses control or AI analysis is connected. Real camera capture is optional and saves locally. Simulations remain metadata only. Tire-pressure confirmation is a technician statement, not an AI-verified measurement.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!session.underHoodStage)
                    FilledButton.icon(
                      key: const ValueKey('next-stage'),
                      onPressed: session.stageComplete && free
                          ? () => saveAndProceed(
                              context,
                              session,
                              () => session.setStage(true),
                            )
                          : null,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('CONTINUE TO UNDER HOOD'),
                    )
                  else ...[
                    OutlinedButton(
                      onPressed: free ? () => session.setStage(false) : null,
                      child: const Text('REVIEW UNDER-VEHICLE CHECKS'),
                    ),
                    FilledButton.icon(
                      key: const ValueKey('finish-guided'),
                      onPressed: session.allChecksComplete && free
                          ? () => saveAndProceed(
                              context,
                              session,
                              () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => AiReviewScreen(
                                    session: session,
                                    repository: widget.repository,
                                  ),
                                ),
                              ),
                            )
                          : null,
                      icon: const Icon(Icons.fact_check),
                      label: const Text('FINISH DEMO GUIDED INSPECTION'),
                    ),
                  ],
                  if (!session.stageComplete)
                    Text(
                      'Complete all required $stage items before continuing.',
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
