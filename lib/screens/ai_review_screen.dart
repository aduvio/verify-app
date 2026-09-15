import 'package:flutter/material.dart';

import '../widgets/evidence_gallery.dart';

import '../widgets/session_save_boundary.dart';

import 'customer_report_screen.dart';

import '../models/ai_observation.dart';
import '../models/inspection_session.dart';
import '../services/mock_ai_review_service.dart';
import '../services/inspection_repository.dart';
import '../widgets/session_banner.dart';
import '../widgets/reason_dialog.dart';

class AiReviewScreen extends StatefulWidget {
  final InspectionSession session;
  final InspectionRepository? repository;
  const AiReviewScreen({super.key, required this.session, this.repository});
  @override
  State<AiReviewScreen> createState() => _AiReviewScreenState();
}

class _AiReviewScreenState extends State<AiReviewScreen> {
  InspectionSession get session => widget.session;
  late final internalController = TextEditingController(
    text: session.internalNote?.text ?? '',
  );
  late final recommendationController = TextEditingController(
    text: session.customerRecommendation?.text ?? '',
  );
  bool loading = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (session.observationsLoaded || loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final values = await MockAiReviewService().loadObservations();
      if (mounted && session.active) session.loadObservations(values);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Demo observations could not load. Retry.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    internalController.dispose();
    recommendationController.dispose();
    super.dispose();
  }

  Future<void> decide(
    AiObservation observation,
    AiObservationStatus assessment,
  ) async {
    final values = await requestReasons(
      context,
      'Technician assessment: ${assessment.label}',
      ['Technician reason (required)'],
      requiredConfirmation: assessment == AiObservationStatus.dismissed
          ? 'I determined this observation is not an actual concern. This also corrects any earlier mistaken assessment.'
          : null,
    );
    if (!mounted || values == null) return;
    session.decide(
      observation,
      assessment,
      values.single,
      notActualConcern: assessment == AiObservationStatus.dismissed,
    );
  }

  Future<void> address(AiObservation observation) async {
    final values = await requestReasons(
      context,
      'Record simulated correction and recheck',
      [
        'Simulated correction description (required)',
        'Simulated recheck description and result (required)',
      ],
      requiredConfirmation: 'I performed the recheck and confirm this concern is cleared in the demo.',
      allowBlockingRecheck: true,
    );
    if (!mounted || values == null) return;
    session.addressConcern(
      observation,
      values[0],
      values[1],
      recheckPassed: values[2] == 'true',
    );
  }

  Widget card(String title, List<Widget> children, {Color? color}) => Card(
    color: color,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );

  Widget observationCard(AiObservation observation) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          observation.title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        Text('DEMO ADVISORY • ${observation.stage} • synthetic scenario'),
        Text(observation.description),
        const SizedBox(height: 8),
        Text(
          'Assessment: ${observation.status.label} | ${observation.resolved ? 'No unresolved required concern' : 'BLOCKING: issue not cleared'}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: observation.resolved ? Colors.blue : Colors.red,
          ),
        ),
        Text(observation.nextAction),
        if (observation.decidedAt != null)
          Text(
            'Reason: ${observation.decisionReason}\n${observation.decidedBy} • ${observation.decidedAt!.toIso8601String()}',
          ),
        if (observation.addressedAt != null)
          Text(
            'Simulated correction: ${observation.correctiveAction}\nSimulated recheck: ${observation.recheck}\nResult: ${observation.recheckPassed ? 'Successful — concern cleared' : 'Failed or incomplete — still blocking'}\n${observation.addressedBy} • ${observation.addressedAt!.toIso8601String()}',
          ),
        if (observation.requiresAction) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: () =>
                    decide(observation, AiObservationStatus.confirmed),
                child: const Text('CONFIRM CONCERN'),
              ),
              OutlinedButton(
                onPressed: () =>
                    decide(observation, AiObservationStatus.dismissed),
                child: const Text('DISMISS WITH REASON'),
              ),
              OutlinedButton(
                onPressed: () =>
                    decide(observation, AiObservationStatus.furtherInspection),
                child: const Text('NEEDS FURTHER INSPECTION'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: observation.status == AiObservationStatus.confirmed
                ? () => address(observation)
                : null,
            icon: const Icon(Icons.fact_check),
            label: const Text('RECORD SIMULATED CORRECTION + RECHECK'),
          ),
          if (observation.status != AiObservationStatus.confirmed &&
              !observation.resolved)
            const Text(
              'First select CONFIRM CONCERN and save your reason to enable correction and recheck.',
            ),
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => SessionSaveBoundary(
    session: session,
    repository: widget.repository,
    child: buildScreen(context),
  );

  Widget buildScreen(BuildContext context) => AnimatedBuilder(
    animation: session,
    builder: (context, _) {
      final gatesReady =
          session.demoReady &&
          session.allChecksComplete &&
          session.flagsResolved;
      final blockers = <String>[
        if (!session.active) 'This session is no longer active.',
        if (!session.demoReady) 'Complete the demo customer, vehicle, placeholder-data and Square readiness checks in intake.',
        if (!session.observationsLoaded) 'Load the demo AI observations.',
        for (final step in session.requiredSteps.where((s) => !s.isComplete))
          'Required inspection check incomplete or failed: ${step.label}. Return to Guided Inspection to finish it.',
        for (final observation in session.observations.where(
          (o) => !o.resolved,
        ))
          '${observation.title}: ${observation.status.label}. ${observation.nextAction}',
      ];
      final accepted = session.attempts.where(
        (a) => a.status == CaptureStatus.accepted,
      );
      return Scaffold(
        backgroundColor: const Color(0xfff5f7fa),
        appBar: AppBar(
          title: const Text(
            'Project Verify — AI Review',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SessionBanner(session: session),
                  card('INSPECTION SUMMARY', [
                    Wrap(
                      spacing: 30,
                      runSpacing: 14,
                      children: [
                        Text(
                          'Customer: ${session.customer?.displayName ?? 'Not selected'}\n${session.customer?.phone ?? ''}',
                        ),
                        Text(
                          'Vehicle: ${session.vehicle?.displayName ?? 'Not selected'}\nSample VIN: ${session.vehicle?.vin ?? ''}',
                        ),
                        Text(
                          'Technician: ${session.technician}\nStore: ${session.location}',
                        ),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 16),
                  card('AI Summary (Mock)', [
                    const Text(
                      'DEMO ADVISORY — NOT VERIFIED',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'Synthetic scenarios only; no actual image or video was analyzed. A confirmed concern remains blocking until corrective action and a successful recheck are documented.',
                    ),
                    Text(
                      'Required concerns cleared: ${session.observations.where((o) => o.requiresAction && o.resolved).length} of ${session.observations.where((o) => o.requiresAction).length}',
                    ),
                  ], color: Colors.blue.shade50),
                  const SizedBox(height: 16),
                  card('AI OBSERVATIONS', [
                    if (loading) const LinearProgressIndicator(),
                    if (error != null) ...[
                      Text(error!),
                      TextButton(onPressed: load, child: const Text('RETRY')),
                    ],
                    ...session.observations.map(observationCard),
                  ]),
                  const SizedBox(height: 16),
                  card('INSPECTION MEDIA — DEMO WORKFLOW', [
                    Text(
                      session.attempts.any((a) => a.realMedia)
                          ? 'Real captured files are browser-local evidence of capture, not verified service facts. Earlier/rejected media is staff-only.'
                          : 'No actual media files or playback. Retakes are retained as internal-only metadata, not durable archives.',
                    ),
                    EvidenceGallery(session: session, staff: true),
                    if (accepted.isEmpty)
                      const Text('No accepted simulated captures.'),
                    ...accepted
                        .where((a) => !a.realMedia)
                        .map(
                          (a) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              '${session.step(a.stepId).label} • simulated ${a.kind.name} • ${a.duration.inSeconds}s\n${a.technician} • ${a.createdAt.toIso8601String()}',
                            ),
                          ),
                        ),
                    Text(
                      'Internal attempt history: ${session.attempts.where((a) => a.internalOnly).length} attempts retained.',
                    ),
                  ]),
                  const SizedBox(height: 16),
                  card('NOTES & RECOMMENDATIONS', [
                    TextField(
                      key: const ValueKey('internal-note'),
                      controller: internalController,
                      maxLines: 3,
                      onChanged: (text) =>
                          session.setNote(text, customerVisible: false),
                      decoration: const InputDecoration(
                        labelText: 'Internal Technician Note (optional)',
                        hintText:
                            'Shop-only. Excluded from customer-facing data.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (session.internalNote != null)
                      Text(
                        'Updated by ${session.internalNote!.author} • ${session.internalNote!.updatedAt.toIso8601String()}',
                      ),
                    const SizedBox(height: 14),
                    TextField(
                      key: const ValueKey('customer-recommendation'),
                      controller: recommendationController,
                      maxLines: 3,
                      onChanged: (text) =>
                          session.setNote(text, customerVisible: true),
                      decoration: const InputDecoration(
                        labelText: 'Customer-Visible Recommendation (optional)',
                        hintText: 'Technician recommendation; may appear in a future report.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (session.customerRecommendation != null)
                      Text(
                        'Updated by ${session.customerRecommendation!.author} • ${session.customerRecommendation!.updatedAt.toIso8601String()}',
                      ),
                  ]),
                  const SizedBox(height: 16),
                  card('TECHNICIAN APPROVAL — DEMO ONLY', [
                    if (!gatesReady) ...[
                      const Text(
                        'What still prevents progression:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      ...blockers.map(
                        (text) => Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('• $text'),
                        ),
                      ),
                    ] else
                      Text(
                        'All required concerns and inspection checks are cleared for this demo. Manually select the ${session.approvals.where((checked) => !checked).length} remaining acknowledgments below, then COMPLETE DEMO REVIEW.',
                      ),
                    for (var i = 0; i < 4; i++)
                      CheckboxListTile(
                        key: ValueKey('approval-$i'),
                        contentPadding: EdgeInsets.zero,
                        value: session.approvals[i],
                        onChanged: gatesReady
                            ? (value) => saveAndProceed(
                                context,
                                session,
                                () => session.setApproval(i, value ?? false),
                              )
                            : null,
                        title: Text(
                          const [
                            'I reviewed the demo observations and simulated evidence metadata.',
                            'All required concerns and failed checks have been addressed in this demo.',
                            'I understand the sample information is unverified.',
                            'I acknowledge demo completion only, not real inspection approval.',
                          ][i],
                        ),
                      ),
                    if (session.demoApproved)
                      const Text(
                        'DEMO REVIEW COMPLETE • No real approval or report authorization.',
                      ),
                  ]),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const ValueKey('complete-demo'),
                    onPressed: session.canCompleteDemo
                        ? () async {
                            if (!await session.flush() || !context.mounted) {
                              return;
                            }
                            session.completeDemo();
                            if (!await session.flush() || !context.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Demo review complete. You can now preview the demo customer report.',
                                ),
                              ),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.fact_check),
                    label: const Text('COMPLETE DEMO REVIEW'),
                  ),
                  if (session.demoApproved)
                    OutlinedButton(
                      onPressed: () => saveAndProceed(
                        context,
                        session,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => CustomerReportScreen(
                              session: session,
                              repository: widget.repository,
                            ),
                          ),
                        ),
                      ),
                      child: const Text('VIEW DEMO CUSTOMER REPORT'),
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
