import 'package:flutter/material.dart';

import '../models/inspection_session.dart';
import '../services/local_inspection_repository.dart';
import 'new_inspection_screen.dart';
import 'guided_inspection_screen.dart';
import 'ai_review_screen.dart';
import 'customer_report_screen.dart';
import 'inspection_complete_screen.dart';

class SavedInspectionsScreen extends StatefulWidget {
  final LocalInspectionRepository repository;
  const SavedInspectionsScreen({super.key, required this.repository});
  @override
  State<SavedInspectionsScreen> createState() => _SavedInspectionsScreenState();
}

class _SavedInspectionsScreenState extends State<SavedInspectionsScreen> {
  bool loading = true, busy = false;
  String? error;
  InspectionSession? pendingNew;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await widget.repository.initialize();
    } catch (_) {
      error = 'Local storage could not open or its upgrade is blocked. Save and close older Project Verify tabs, then retry. Check browser storage permissions. No records were reset; do not clear site data. Use the same normal browser profile and address.';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> open(InspectionSession s) async {
    if (busy) return;
    setState(() => busy = true);
    if (!await s.flush()) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Save failed or conflicted. No session was discarded. Retry saving; keep this tab open.';
        });
      }
      return;
    }
    if (!mounted) return;
    final repo = widget.repository;
    final Widget screen = s.completionCurrent
        ? InspectionCompleteScreen(session: s, repository: repo)
        : !s.demoReady
        ? NewInspectionScreen(session: s, repository: repo)
        : s.demoApproved
        ? CustomerReportScreen(session: s, repository: repo)
        : s.allChecksComplete
        ? AiReviewScreen(session: s, repository: repo)
        : GuidedInspectionScreen(session: s, repository: repo);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => screen),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Project Verify — Saved Inspections')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Local demo records',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Saved only in this browser profile at this address. Not cloud backup or cross-device sync. Clearing site data can remove records. Use fictional demo information only.',
            ),
            if (loading) const LinearProgressIndicator(),
            if (error != null) ...[
              Text(error!),
              TextButton(
                onPressed: busy ? null : load,
                child: const Text('RETRY STORAGE'),
              ),
            ],
            ...widget.repository.recoveryMessages.map(
              (m) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(m),
                ),
              ),
            ),
            if (!loading && widget.repository.initialized) ...[
              for (final s in widget.repository.records.where((s) => s.active))
                Card(
                  child: ListTile(
                    title: Text(
                      '${s.customer?.displayName ?? 'New demo'} • ${s.id}',
                    ),
                    subtitle: Text(
                      '${s.completionCurrent ? 'Completed demo — read-only' : 'Incomplete demo'} • revision ${s.reportRevision}\n${s.updatedAt.toIso8601String()}',
                    ),
                    trailing: TextButton(
                      onPressed: busy ? null : () => open(s),
                      child: Text(s.completionCurrent ? 'VIEW' : 'RESUME'),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy
                    ? null
                    : () {
                        pendingNew ??= widget.repository.create(
                          technician: 'Armand',
                        );
                        open(pendingNew!);
                      },
                child: const Text('START NEW INSPECTION'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
