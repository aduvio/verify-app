import 'package:flutter/material.dart';

import '../models/inspection_session.dart';
import '../models/ai_observation.dart';
import '../services/inspection_repository.dart';
import '../widgets/reason_dialog.dart';
import 'guided_inspection_screen.dart';
import 'new_inspection_screen.dart';

class InspectionCompleteScreen extends StatefulWidget {
  final InspectionSession session;
  final InspectionRepository repository;
  const InspectionCompleteScreen({
    super.key,
    required this.session,
    required this.repository,
  });
  @override
  State<InspectionCompleteScreen> createState() =>
      _InspectionCompleteScreenState();
}

class _InspectionCompleteScreenState extends State<InspectionCompleteScreen> {
  bool busy = false;
  InspectionSession get session => widget.session;

  void startNew() {
    if (busy || !session.completionCurrent) return;
    setState(() => busy = true);
    final next = widget.repository.startNext(session);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) =>
            NewInspectionScreen(session: next, repository: widget.repository),
      ),
      (_) => false,
    );
  }

  Future<void> reopen() async {
    if (busy || !session.completionCurrent) return;
    setState(() => busy = true);
    final revision = session.completion!.snapshot.revision;
    final result = await requestReasons(
      context,
      'Reopen inspection?',
      ['Reason for reopening (required)'],
      requiredConfirmation: 'Reopen for editing and require fresh approval. The previous report and delivery records will be retained.',
    );
    if (!mounted) return;
    if (result == null) {
      setState(() => busy = false);
      return;
    }
    if (session.reopen(result.first, completedRevision: revision)) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => GuidedInspectionScreen(
            session: session,
            repository: widget.repository,
          ),
        ),
        (_) => false,
      );
    } else {
      setState(() => busy = false);
    }
  }

  Widget card(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        final completed = session.completion;
        if (!session.completionCurrent || completed == null) {
          return const Scaffold(
            body: Center(
              child: Text(
                'Completion unavailable. This session needs fresh review.',
              ),
            ),
          );
        }
        final data = completed.snapshot.data;
        final customer = data['customer'] as Map;
        final vehicle = data['vehicle'] as Map;
        final recommendation = data['recommendation'] as Map?;
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('Inspection Complete — Demo'),
          ),
          body: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      card('DEMO INSPECTION COMPLETE', [
                        const Text(
                          'Simulated delivery completed. Nothing was sent to the customer.',
                        ),
                        const SizedBox(height: 16),
                        Text('Inspection: ${completed.snapshot.inspectionId}'),
                        Text('Report revision: ${completed.snapshot.revision}'),
                        Text('Customer: ${customer['name']} (sample intake)'),
                        Text(
                          'Vehicle: ${vehicle['description']} (sample VIN decoding)',
                        ),
                        Text(
                          'Technician: ${data['technician']} (demo identity)',
                        ),
                        Text('Store: ${data['location']}'),
                        Text(
                          'Completed: ${completed.completedAt.toIso8601String()}',
                        ),
                        const Text(
                          'Demo acknowledgment only — not proof of a real inspection.',
                        ),
                      ]),
                      card('DELIVERY STATUS — SIMULATED', [
                        const Text('Demo report prepared.'),
                        const Text(
                          'Simulation complete. Nothing was sent to the customer.',
                        ),
                        Text(
                          'Selected method: ${completed.delivery.channel.name.toUpperCase()}',
                        ),
                        Text('Recipient used: ${completed.delivery.recipient}'),
                        const SizedBox(height: 12),
                        const Text(
                          'Video unavailable — recording is not connected.',
                        ),
                        const Text('Secure hosting not connected.'),
                        const Text(
                          'Customers will not need an account when secure delivery is connected.',
                        ),
                      ]),
                      card('CUSTOMER REPORT SUMMARY — DEMO', [
                        const Text(
                          'Documented prototype activity, not verified service facts.',
                        ),
                        for (final check in data['documentedChecks'] as List)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '${check['label']}: ${check['result']}',
                            ),
                          ),
                        if (recommendation != null &&
                            (recommendation['text'] as String)
                                .trim()
                                .isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Customer-visible recommendation — not a completed service action',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('${recommendation['text']}'),
                        ],
                      ]),
                      Card(
                        child: ExpansionTile(
                          title: const Text(
                            'STAFF ONLY — internal notes, advisory observations and event timeline',
                          ),
                          childrenPadding: const EdgeInsets.all(16),
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Excluded from customer-facing report data.',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const Text('Internal technician note'),
                                Text(
                                  session.internalNote?.text ??
                                      'No internal note.',
                                ),
                                if (session.internalNote != null)
                                  Text(
                                    '${session.internalNote!.author} • ${session.internalNote!.updatedAt.toIso8601String()}',
                                  ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Unverified AI observations — simulated advisory scenarios',
                                ),
                                ...session.observations.map(
                                  (o) => Text(
                                    '${o.title}: ${o.status.label}. ${o.description}',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Simulated delivery attempt history',
                                ),
                                ...session.deliveryAttempts.map(
                                  (a) => Text(
                                    '${a.id} • revision ${a.snapshot.revision} • ${a.channel.name.toUpperCase()} • ${a.recipient}\n'
                                    '${a.status.name} (simulated) • ${a.finishedAt?.toIso8601String() ?? 'Pending'}',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Actual in-memory event timeline — demo session actions, no live service',
                                ),
                                ...session.audit.map(
                                  (e) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      '${e.action.replaceAll('_', ' ')}\n${e.at.toIso8601String()} • ${e.actor} • Simulated/demo\n'
                                      '${e.details.entries.map((d) => '${d.key}: ${d.value}').join('; ')}',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        key: const ValueKey('start-new-inspection'),
                        onPressed: busy ? null : startNew,
                        child: const Text('START NEW INSPECTION'),
                      ),
                      OutlinedButton(
                        key: const ValueKey('reopen-inspection'),
                        onPressed: busy ? null : reopen,
                        child: const Text('REOPEN INSPECTION'),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => showDialog<void>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text(
                                    'VIEW HISTORY — PLACEHOLDER',
                                  ),
                                  content: const Text(
                                    'The history screen is not implemented. Completed inspections are retained only in the current in-memory repository.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('CLOSE'),
                                    ),
                                  ],
                                ),
                              ),
                        child: const Text('VIEW HISTORY — PLACEHOLDER'),
                      ),
                      const Text(
                        'Memory only: refreshing or closing the app can lose inspection records. Reopen explicitly to edit this inspection.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
