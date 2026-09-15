import 'package:idb_shim/idb.dart';

import 'dart:typed_data';
import 'dart:async';

import 'media_store.dart';

import 'inspection_store.dart';

class IndexedDbInspectionStore implements InspectionStore, MediaStore {
  final IdbFactory factory;
  final String databaseName;
  // Browser IndexedDB supports this; idb_shim's in-memory engine does not.
  final bool closeOnVersionChange;
  Future<Database>? _database;
  IndexedDbInspectionStore(
    this.factory, {
    this.databaseName = 'project_verify_local_v1',
    this.closeOnVersionChange = false,
  });
  Future<Database> _open() =>
      _database ??= _connect().catchError((Object error) {
        _database = null;
        throw error;
      });

  Future<Database> _connect() {
    final result = Completer<Database>();
    factory
        .open(
          databaseName,
          version: 2,
          onBlocked: (_) {
            if (!result.isCompleted) {
              result.completeError(
                StateError(
                  'Storage upgrade blocked. Save and close older Project Verify tabs, then retry. Do not clear site data.',
                ),
              );
            }
          },
          onUpgradeNeeded: (e) {
            // Initial schema only. Never delete stores or records during upgrades.
            if (!e.database.objectStoreNames.contains('inspections')) {
              e.database.createObjectStore('inspections', keyPath: 'id');
            }
            if (!e.database.objectStoreNames.contains('media')) {
              e.database.createObjectStore('media', keyPath: 'key');
            }
          },
        )
        .then(
          (db) {
            if (result.isCompleted) {
              db.close();
              return;
            }
            try {
              if (closeOnVersionChange) {
                db.onVersionChange.take(1).listen((_) {
                  db.close();
                  _database = null;
                });
              }
              result.complete(db);
            } catch (e) {
              db.close();
              result.completeError(e);
            }
          },
          onError: (Object error) {
            if (!result.isCompleted) result.completeError(error);
          },
        );
    return result.future;
  }

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
  ) => writeWithMedia(id, expectedVersion, session, {});

  @override
  Future<Uint8List?> readMedia(String inspectionId, String attemptId) async {
    final db = await _open();
    final tx = db.transaction('media', idbModeReadOnly);
    final outcome = tx.completed.then<Object?>(
      (_) => null,
      onError: (Object e) => e,
    );
    try {
      final row = await tx
          .objectStore('media')
          .getObject('$inspectionId/$attemptId');
      final error = await outcome;
      if (error != null) throw error;
      if (row == null) return null;
      final value = row as Map;
      if (value['inspectionId'] != inspectionId ||
          value['attemptId'] != attemptId) {
        throw const FormatException('Media ownership mismatch');
      }
      return Uint8List.fromList((value['bytes'] as List).cast<int>());
    } catch (_) {
      await outcome;
      rethrow;
    }
  }

  @override
  Future<int> writeWithMedia(
    String id,
    int expectedVersion,
    Map<String, Object?> session,
    Map<String, Uint8List> media,
  ) async {
    final db = await _open();
    final tx = db.transactionList(['inspections', 'media'], idbModeReadWrite);
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
      for (final entry in media.entries) {
        final key = '$id/${entry.key}';
        // Files are immutable. Never replace a prior recording under its ID.
        final files = tx.objectStore('media');
        if (await files.getObject(key) != null) {
          throw StateError('Media ID already stored; original retained.');
        }
        await files.add({
          'key': key,
          'inspectionId': id,
          'attemptId': entry.key,
          'bytes': entry.value,
        });
      }
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
