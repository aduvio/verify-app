import 'dart:async';
import 'package:flutter/material.dart';

import '../models/inspection_step.dart';
import '../services/mock_recording_service.dart';

class GuidedInspectionScreen extends StatefulWidget {
  const GuidedInspectionScreen({super.key});

  @override
  State<GuidedInspectionScreen> createState() => _GuidedInspectionScreenState();
}

class _GuidedInspectionScreenState extends State<GuidedInspectionScreen> {
  final MockRecordingService recordingService = MockRecordingService();

  bool filterUnderHood = false;
  bool underHoodStage = false;

  Timer? timer;
  int elapsedSeconds = 0;
  InspectionStep? activeStep;

  late final List<InspectionStep> underVehicleSteps = [
    InspectionStep(
      id: 'drain_plug',
      label: 'Drain Plug',
      guidance: 'Record the drain plug and surrounding area. Minimum 5 seconds.',
      minimumSeconds: 5,
    ),
    InspectionStep(
      id: 'oil_filter',
      label: 'Oil Filter',
      guidance: 'Record the oil filter and surrounding area. Minimum 5 seconds.',
      minimumSeconds: 5,
    ),
    InspectionStep(
      id: 'axle_area',
      label: 'Differential / Axle Area',
      guidance: 'Record a short sweep of the axle or differential area for visible leaks.',
    ),
    InspectionStep(
      id: 'engine_underside',
      label: 'Engine Underside',
      guidance: 'Record a short sweep under the engine for visible leaks or residual oil.',
    ),
    InspectionStep(
      id: 'clean_residual_oil',
      label: 'Residual Oil Cleaned',
      guidance:
          'Confirm spilled oil has been cleaned from the engine, oil pan, crossmember, axle, and surrounding areas.',
    ),
  ];

  late final List<InspectionStep> underHoodSteps = [
    InspectionStep(
      id: 'top_filter',
      label: 'Oil Filter (Top-Mounted)',
      guidance: 'Record the oil filter under the hood. Minimum 5 seconds.',
      minimumSeconds: 5,
    ),
    InspectionStep(
      id: 'dipstick',
      label: 'Oil Level / Dipstick',
      guidance:
          'Remove the dipstick and capture the final oil level. Reinstall the dipstick completely before continuing.',
    ),
    InspectionStep(
      id: 'caps_touch',
      label: 'Cap & Component Touch Sequence',
      guidance:
          'Confirm the dipstick is fully seated, then touch and verify: oil cap, coolant cap, brake fluid, washer-fluid cap, and battery terminals.',
    ),
    InspectionStep(
      id: 'engine_bay',
      label: 'Engine Bay Leak Sweep',
      guidance: 'Record a short engine-bay sweep for visible leaks or concerns.',
    ),
    InspectionStep(
      id: 'tire_pressure',
      label: 'Tire Pressure Check',
      guidance:
          'Confirm tire pressures were checked and either adjusted to specification or required no adjustment.',
    ),
    InspectionStep(
      id: 'oil_light',
      label: 'Oil Change Light Reset',
      guidance: 'Confirm the oil-change reminder has been reset.',
    ),
  ];

  List<InspectionStep> get currentSteps {
    if (!underHoodStage) {
      return underVehicleSteps
          .where((step) => !(filterUnderHood && step.id == 'oil_filter'))
          .toList();
    }
    return underHoodSteps
        .where((step) => !(!filterUnderHood && step.id == 'top_filter'))
        .toList();
  }

  bool get stageComplete =>
      currentSteps.where((step) => step.required).every((step) => step.isComplete);

  int get completedCount => currentSteps.where((step) => step.isComplete).length;

  double get progress =>
      currentSteps.isEmpty ? 0 : completedCount / currentSteps.length;

  String get timerText {
    final minutes = elapsedSeconds ~/ 60;
    final seconds = elapsedSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> startRecording(InspectionStep step) async {
    if (activeStep != null) return;
    await recordingService.startSegment(step.id);
    setState(() {
      activeStep = step;
      elapsedSeconds = 0;
      step.status = InspectionStepStatus.recording;
    });
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => elapsedSeconds++);
    });
  }

  Future<void> stopRecording() async {
    final step = activeStep;
    if (step == null) return;

    timer?.cancel();
    await recordingService.stopSegment(step.id, elapsedSeconds);
    final recordedSeconds = elapsedSeconds;

    if (recordedSeconds < step.minimumSeconds) {
      setState(() {
        step.capturedSeconds = recordedSeconds;
        step.status = InspectionStepStatus.needsRetry;
        activeStep = null;
        elapsedSeconds = 0;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${step.label} requires at least ${step.minimumSeconds} seconds. Record again.',
          ),
        ),
      );
      return;
    }

    setState(() {
      step.capturedSeconds = recordedSeconds;
      step.status = InspectionStepStatus.captured;
      activeStep = null;
      elapsedSeconds = 0;
    });

    if (!mounted) return;
    await _askSufficient(step);
  }

  Future<void> _askSufficient(InspectionStep step) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Recording stopped'),
          content: Text(
            'Was the ${step.label.toLowerCase()} recording sufficient?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('RECORD AGAIN'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('YES, KEEP IT'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (result == true) {
      setState(() => step.status = InspectionStepStatus.confirmed);
    } else {
      await recordingService.archiveAndReplaceLastSegment(step.id);
      setState(() {
        step.status = InspectionStepStatus.pending;
        step.capturedSeconds = 0;
      });
    }
  }

  void confirmNonVideoStep(InspectionStep step) {
    setState(() => step.status = InspectionStepStatus.confirmed);
  }

  bool _usesRecording(InspectionStep step) {
    return {
      'drain_plug',
      'oil_filter',
      'axle_area',
      'engine_underside',
      'top_filter',
      'caps_touch',
      'engine_bay',
    }.contains(step.id);
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stageLabel = underHoodStage ? 'Under Hood' : 'Under Vehicle';

    return Scaffold(
      backgroundColor: const Color(0xfff5f7fa),
      appBar: AppBar(
        title: const Text(
          'Project Verify — Guided Inspection',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 20),
            child: Center(child: Text('Inspection ID: DEMO-001')),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Stage: $stageLabel',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          underHoodStage
                              ? 'Complete the under-hood final verification. The glasses are the primary interface; this screen mirrors progress.'
                              : 'Complete under-vehicle verification first. The glasses are the primary interface; this screen mirrors progress.',
                        ),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(value: progress),
                        const SizedBox(height: 6),
                        Text('$completedCount of ${currentSteps.length} complete'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                if (!underHoodStage)
                  Card(
                    child: SwitchListTile(
                      title: const Text('Oil filter is located under the hood'),
                      subtitle: const Text(
                        'When enabled, oil-filter verification moves to the under-hood stage.',
                      ),
                      value: filterUnderHood,
                      onChanged: activeStep == null
                          ? (value) => setState(() => filterUnderHood = value)
                          : null,
                    ),
                  ),

                if (activeStep != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.fiber_manual_record, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'MOCK RECORDING',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            activeStep!.label,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            timerText,
                            style: const TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (activeStep!.minimumSeconds > 0)
                            Text('Minimum ${activeStep!.minimumSeconds} seconds'),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            onPressed: stopRecording,
                            icon: const Icon(Icons.stop),
                            label: const Text('STOP RECORDING'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                ...currentSteps.map((step) {
                  final isRecording = activeStep == step;
                  final complete = step.isComplete;
                  final retry = step.status == InspectionStepStatus.needsRetry;
                  final usesRecording = _usesRecording(step);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              complete
                                  ? Icons.check_circle
                                  : retry
                                      ? Icons.error
                                      : Icons.radio_button_unchecked,
                              color: complete
                                  ? Colors.green
                                  : retry
                                      ? Colors.orange
                                      : Colors.grey,
                              size: 30,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    step.label,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(step.guidance),
                                  if (step.capturedSeconds > 0) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Last segment: ${step.capturedSeconds}s',
                                      style: const TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (!complete && usesRecording)
                              FilledButton.icon(
                                onPressed: activeStep == null
                                    ? () => startRecording(step)
                                    : isRecording
                                        ? stopRecording
                                        : null,
                                icon: Icon(
                                  isRecording ? Icons.stop : Icons.videocam,
                                ),
                                label: Text(
                                  retry ? 'RECORD AGAIN' : 'RECORD',
                                ),
                              ),
                            if (!complete && !usesRecording)
                              FilledButton.icon(
                                onPressed: activeStep == null
                                    ? () => confirmNonVideoStep(step)
                                    : null,
                                icon: const Icon(Icons.check),
                                label: const Text('CONFIRM'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                Card(
                  color: Colors.blue.shade50,
                  child: const Padding(
                    padding: EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.blue),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'AI Guidance (Mock): Guidance is stage-aware and only references the current inspection stage. Real glasses, video capture, speech, and AI analysis are not connected yet.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                if (!underHoodStage)
                  SizedBox(
                    height: 60,
                    child: FilledButton.icon(
                      onPressed: stageComplete && activeStep == null
                          ? () => setState(() => underHoodStage = true)
                          : null,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text(
                        'CONTINUE TO UNDER HOOD',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 60,
                    child: FilledButton.icon(
                      onPressed: stageComplete && activeStep == null
                          ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'SCR-002 complete. SCR-003 AI Review will connect here.',
                                  ),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.fact_check),
                      label: const Text(
                        'FINISH GUIDED INSPECTION',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                if (!stageComplete) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Complete all required $stageLabel items before continuing.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
