import 'package:idb_shim/idb.dart';

import 'inspection_store.dart';

class IndexedDbInspectionStore implements InspectionStore {
  final IdbFactory factory;
  final String databaseName;
  Future<Database>? _database;
  IndexedDbInspectionStore(
    this.factory, {
    this.databaseName = 'project_verify_local_v1',
  });
  Future<Database> _open() => _database ??= factory
      .open(
        databaseName,
        version: 1,
        onUpgradeNeeded: (e) {
          // Initial schema only. Never delete stores or records during upgrades.
          if (!e.database.objectStoreNames.contains('inspections')) {
            e.database.createObjectStore('inspections', keyPath: 'id');
          }
        },
      )
      .catchError((Object error) {
        _database =
            null; // A later explicit retry may succeed; never reset records.
        throw error;
      });
  @override
  Future<List<Object?>> readAll() async {
    final db = await _open();
    final tx = db.transaction('inspections', idbModeReadOnly);
    final outcome = tx.completed.then<Object?>(
      (_) => null,
      onError: (Object e) => e,
    );
    try {
      final result = await tx.objectStore('inspections').getAll();
      final error = await outcome;
      if (error != null) throw error;
      return result;
    } catch (_) {
      await outcome;
      rethrow;
    }
  }

  @override
  Future<int> write(
    String id,
    int expectedVersion,
    Map<String, Object?> session,
  ) async {
    final db = await _open();
    final tx = db.transaction('inspections', idbModeReadWrite);
    final done = tx.completed;
    // Attach an error handler immediately so an abort is never unhandled.
    final outcome = done.then<Object?>((_) => null, onError: (Object e) => e);
    try {
      final store = tx.objectStore('inspections');
      final previous = await store.getObject(id);
      final version = previous == null
          ? 0
          : (previous as Map)['storageVersion'];
      if (version != expectedVersion) throw const StorageConflict();
      final next = expectedVersion + 1;
      await store.put({'id': id, 'storageVersion': next, 'session': session});
      final error = await outcome;
      if (error != null) throw error;
      return next;
    } catch (_) {
      try {
        tx.abort();
      } catch (_) {
        /* Already completed or aborted. */
      }
      await outcome;
      rethrow;
    }
  }

  @override
  void close() {
    _database?.then<void>((db) => db.close(), onError: (Object _) {});
  }
}
