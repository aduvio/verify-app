import 'package:flutter/material.dart';

import '../models/inspection_session.dart';
import '../services/inspection_repository.dart';
import '../services/local_inspection_repository.dart';
import '../screens/saved_inspections_screen.dart';

/// Flushes pending text edits on Back. Forward actions also use saveAndProceed.
class SessionSaveBoundary extends StatefulWidget {
  final InspectionSession session;
  final InspectionRepository? repository;
  final Widget child;
  const SessionSaveBoundary({
    super.key,
    required this.session,
    this.repository,
    required this.child,
  });
  @override
  State<SessionSaveBoundary> createState() => _SessionSaveBoundaryState();
}

class _SessionSaveBoundaryState extends State<SessionSaveBoundary> {
  bool leaving = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    if (!s.persistenceEnabled) return widget.child;
    return ValueListenableBuilder<SavePhase>(
      valueListenable: s.savePhase,
      builder: (context, phase, _) => PopScope(
        canPop: s.saved && !s.sending,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop || leaving || s.sending || !s.editable) return;
          leaving = true;
          if (await s.flush() &&
              context.mounted &&
              Navigator.of(context).canPop()) {
            Navigator.pop(context);
          }
          leaving = false;
        },
        child: Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    children: [
                      Text(switch (phase) {
                        SavePhase.saved => 'Saved on this device.',
                        SavePhase.failed => 'Save failed — retry required.',
                        SavePhase.conflict => 'Save conflict — another tab saved newer changes. This tab is read-only; keep it open to preserve unsaved edits. Open saved inspections in a new tab to review the latest record.',
                        _ => 'Saving...',
                      }),
                      if (phase == SavePhase.failed)
                        TextButton(
                          onPressed: s.flush,
                          child: const Text('RETRY SAVE'),
                        ),
                      if (widget.repository is LocalInspectionRepository)
                        TextButton(
                          onPressed: s.sending || leaving
                              ? null
                              : () async {
                                  leaving = true;
                                  if (await s.flush() && context.mounted) {
                                    Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute<void>(
                                        builder: (_) => SavedInspectionsScreen(
                                          repository:
                                              widget.repository
                                                  as LocalInspectionRepository,
                                        ),
                                      ),
                                      (_) => false,
                                    );
                                  }
                                  leaving = false;
                                },
                          child: const Text('SAVED INSPECTIONS'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: AbsorbPointer(
                absorbing: phase == SavePhase.conflict,
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final _pendingActions = Expando<bool>();

Future<void> saveAndProceed(
  BuildContext context,
  InspectionSession session,
  VoidCallback action,
) async {
  if (!session.persistenceEnabled) {
    action();
    return;
  }
  if (_pendingActions[session] == true) return;
  _pendingActions[session] = true;
  try {
    if (await session.flush() && context.mounted) action();
  } finally {
    _pendingActions[session] = false;
  }
}
