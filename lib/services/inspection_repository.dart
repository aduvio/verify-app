import 'dart:math';

import '../models/inspection_session.dart';

abstract class InspectionRepository {
  InspectionSession create({
    required String technician,
    String location = 'Costa Oil Change - Chalmette',
  });
  InspectionSession? find(String id);
  void retain(InspectionSession session);
  InspectionSession startNext(InspectionSession completed);
}

/// No files, database, network, or durable storage. Reload loses all sessions.
class InMemoryInspectionRepository implements InspectionRepository {
  final SessionClock clock;
  final Map<String, InspectionSession> _sessions = {};
  final Map<String, InspectionSession> _nextSessions = {};
  final Random _random = Random.secure();
  InMemoryInspectionRepository({SessionClock? clock})
    : clock = clock ?? DateTime.now;
  @override
  InspectionSession create({
    required String technician,
    String location = 'Costa Oil Change - Chalmette',
  }) {
    final id =
        'DEMO-${clock().microsecondsSinceEpoch}-${_random.nextInt(0x100000000).toRadixString(16)}-${_sessions.length + 1}';
    final session = InspectionSession(
      id: id,
      technician: technician,
      location: location,
      clock: clock,
    );
    _sessions[id] = session;
    return session;
  }

  @override
  InspectionSession? find(String id) => _sessions[id];

  @override
  void retain(InspectionSession session) {
    final previous = _sessions[session.id];
    if (previous != null && !identical(previous, session)) {
      throw StateError('An inspection with this ID is already retained.');
    }
    _sessions[session.id] = session;
  }

  @override
  InspectionSession startNext(InspectionSession completed) {
    if (!completed.completionCurrent) {
      throw StateError('Complete the current demo first.');
    }
    retain(completed);
    final key = '${completed.id}:${completed.completion!.snapshot.revision}';
    return _nextSessions.putIfAbsent(
      key,
      () => create(
        technician: completed.technician,
        location: completed.location,
      ),
    );
  }
}
