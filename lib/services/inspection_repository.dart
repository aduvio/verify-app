import 'dart:math';

import '../models/inspection_session.dart';

abstract class InspectionRepository {
  InspectionSession create({required String technician});
  InspectionSession? find(String id);
}

/// No files, database, network, or durable storage. Reload loses all sessions.
class InMemoryInspectionRepository implements InspectionRepository {
  final SessionClock clock;
  final Map<String, InspectionSession> _sessions = {};
  final Random _random = Random.secure();
  InMemoryInspectionRepository({SessionClock? clock})
    : clock = clock ?? DateTime.now;
  @override
  InspectionSession create({required String technician}) {
    final id =
        'DEMO-${clock().microsecondsSinceEpoch}-${_random.nextInt(0x100000000).toRadixString(16)}-${_sessions.length + 1}';
    final session = InspectionSession(
      id: id,
      technician: technician,
      clock: clock,
    );
    _sessions[id] = session;
    return session;
  }

  @override
  InspectionSession? find(String id) => _sessions[id];
}
