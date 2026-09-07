import 'package:flutter/material.dart';

import '../models/ai_observation.dart';
import '../services/mock_ai_review_service.dart';

class AiReviewScreen extends StatefulWidget {
  const AiReviewScreen({super.key});

  @override
  State<AiReviewScreen> createState() => _AiReviewScreenState();
}

class _AiReviewScreenState extends State<AiReviewScreen> {
  final MockAiReviewService reviewService = MockAiReviewService();

  bool loading = true;
  List<AiObservation> observations = [];

  bool reviewedAllMedia = false;
  bool actionedFlags = false;
  bool infoAccurate = false;
  bool approveForReport = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await reviewService.loadObservations();
    if (!mounted) return;
    setState(() {
      observations = result;
      loading = false;
    });
  }

  bool get allRequiredObservationsResolved =>
      observations.where((item) => item.requiresAction).every((item) => item.resolved);

  bool get approvalComplete =>
      reviewedAllMedia &&
      actionedFlags &&
      infoAccurate &&
      approveForReport &&
      allRequiredObservationsResolved;

  void resolve(
    AiObservation observation,
    AiObservationStatus status,
  ) {
    setState(() {
      observation.status = status;
      actionedFlags = allRequiredObservationsResolved;
    });
  }

  Color _statusColor(AiObservation observation) {
    switch (observation.status) {
      case AiObservationStatus.confirmed:
        return Colors.green;
      case AiObservationStatus.dismissed:
        return Colors.grey;
      case AiObservationStatus.furtherInspection:
        return Colors.orange;
      case AiObservationStatus.pending:
        return observation.requiresAction ? Colors.red : Colors.blue;
    }
  }

  String _statusText(AiObservation observation) {
    switch (observation.status) {
      case AiObservationStatus.confirmed:
        return 'CONFIRMED';
      case AiObservationStatus.dismissed:
        return 'DISMISSED';
      case AiObservationStatus.furtherInspection:
        return 'FURTHER INSPECTION';
      case AiObservationStatus.pending:
        return observation.requiresAction ? 'REQUIRES ACTION' : 'AI OBSERVED';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f7fa),
      appBar: AppBar(
        title: const Text(
          'Project Verify — AI Review',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 20),
            child: Center(child: Text('Inspection ID: DEMO-001')),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 16),
                      _buildSummary(),
                      const SizedBox(height: 16),
                      _buildObservations(),
                      const SizedBox(height: 16),
                      _buildMedia(),
                      const SizedBox(height: 16),
                      _buildNotes(),
                      const SizedBox(height: 16),
                      _buildApproval(),
                      const SizedBox(height: 16),
                      _buildNextButton(),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Wrap(
          spacing: 30,
          runSpacing: 14,
          children: [
            _InfoItem(label: 'Customer', value: 'Sample Customer'),
            _InfoItem(label: 'Vehicle', value: '2024 Toyota Camry SE'),
            _InfoItem(label: 'Technician', value: 'Armand'),
            _InfoItem(label: 'Store', value: 'Costa Oil Change - Chalmette'),
            _InfoItem(label: 'Status', value: 'AI Review'),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final flagged = observations.where((item) => item.requiresAction).length;
    final resolved = observations
        .where((item) => item.requiresAction && item.resolved)
        .length;

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.blue),
                SizedBox(width: 10),
                Text(
                  'AI Summary (Mock)',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 10),
                Chip(label: Text('AI OBSERVED — NOT VERIFIED')),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'AI observations are advisory only. A technician must resolve all flagged items before the customer report can be generated.',
            ),
            const SizedBox(height: 12),
            Text('Flagged items resolved: $resolved of $flagged'),
          ],
        ),
      ),
    );
  }

  Widget _buildObservations() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'AI OBSERVATIONS',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...observations.map((observation) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            observation.requiresAction
                                ? Icons.warning_amber
                                : Icons.info_outline,
                            color: _statusColor(observation),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              observation.title,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Chip(
                            label: Text(_statusText(observation)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(observation.description),
                      const SizedBox(height: 8),
                      Text(
                        '${observation.stage} • AI confidence: ${observation.confidencePercent}%',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      if (observation.requiresAction &&
                          observation.status == AiObservationStatus.pending) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: () => resolve(
                                observation,
                                AiObservationStatus.confirmed,
                              ),
                              icon: const Icon(Icons.check_circle),
                              label: const Text('CONFIRM'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => resolve(
                                observation,
                                AiObservationStatus.dismissed,
                              ),
                              icon: const Icon(Icons.block),
                              label: const Text('DISMISS'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => resolve(
                                observation,
                                AiObservationStatus.furtherInspection,
                              ),
                              icon: const Icon(Icons.search),
                              label: const Text('NEEDS FURTHER INSPECTION'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMedia() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'INSPECTION MEDIA (MOCK)',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Under Vehicle',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: const [
                _MediaTile(label: 'Drain Plug'),
                _MediaTile(label: 'Oil Filter'),
                _MediaTile(label: 'Axle Area'),
                _MediaTile(label: 'Engine Underside'),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Under Hood',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: const [
                _MediaTile(label: 'Oil Level'),
                _MediaTile(label: 'Touch Sequence'),
                _MediaTile(label: 'Engine Bay'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotes() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            Text(
              'NOTES & RECOMMENDATIONS',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 14),
            TextField(
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Internal Technician Note (optional)',
                hintText:
                    'Shop-only note. This will not appear on the customer report.',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 14),
            TextField(
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Customer-Visible Recommendation (optional)',
                hintText:
                    'Example: Tires need attention. This may appear on the customer report.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApproval() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'TECHNICIAN APPROVAL',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: reviewedAllMedia,
              onChanged: (value) =>
                  setState(() => reviewedAllMedia = value ?? false),
              title: const Text('I reviewed the AI observations and inspection media.'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: actionedFlags,
              onChanged: allRequiredObservationsResolved
                  ? (value) => setState(() => actionedFlags = value ?? false)
                  : null,
              title: const Text('All flagged items have been addressed.'),
              subtitle: !allRequiredObservationsResolved
                  ? const Text('Resolve all required AI flags first.')
                  : null,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: infoAccurate,
              onChanged: (value) =>
                  setState(() => infoAccurate = value ?? false),
              title: const Text('The verified information is accurate to the best of my knowledge.'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: approveForReport,
              onChanged: (value) =>
                  setState(() => approveForReport = value ?? false),
              title: const Text('I approve this inspection for the customer report.'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextButton() {
    return SizedBox(
      height: 62,
      child: FilledButton.icon(
        onPressed: approvalComplete
            ? () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'SCR-003 complete. SCR-004 Customer Report will connect here.',
                    ),
                  ),
                );
              }
            : null,
        icon: const Icon(Icons.description),
        label: const Text(
          'GENERATE CUSTOMER REPORT',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;

  const _InfoItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  final String label;

  const _MediaTile({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      height: 95,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.play_circle_outline, size: 34),
          const SizedBox(height: 6),
          Text(label),
        ],
      ),
    );
  }
}
