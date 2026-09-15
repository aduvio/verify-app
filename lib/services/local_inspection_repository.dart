import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../models/local_media.dart';
import 'media_store.dart';

import '../models/inspection_session.dart';
import 'inspection_repository.dart';
import 'inspection_store.dart';

class LocalInspectionRepository extends InMemoryInspectionRepository {
  final InspectionStore store;
  final Duration debounce;
  final Map<String, _Writer> _writers = {};
  final List<String> recoveryMessages = [];
  bool initialized = false;
  LocalInspectionRepository(
    this.store, {
    this.debounce = const Duration(milliseconds: 300),
  });
  List<InspectionSession> get records =>
      _writers.values.map((w) => w.session).toList();

  Future<void> initialize() async {
    if (initialized) return;
    final records = await store
        .readAll(); // Failure leaves the DB intact; no memory fallback.
    for (var i = 0; i < records.length; i++) {
      try {
        final row = Map<String, dynamic>.from(records[i] as Map);
        final version = row['storageVersion'] as int;
        if (version < 1) throw const FormatException('Invalid storage version');
        final available = <String>{};
        final raw = row['session'] as Map;
        for (final a in raw['captures'] as List? ?? []) {
          if ((a as Map)['media'] != null && store is MediaStore) {
            final m = LocalMedia.fromMap(a['media'] as Map);
            final bytes = await (store as MediaStore).readMedia(
              row['id'] as String,
              m.id,
            );
            if (m.inspectionId == row['id'] &&
                bytes != null &&
                m.matches(bytes)) {
              available.add(m.id);
            }
          }
        }
        final s = restoreInspection(row['session'], availableMedia: available);
        if (row['id'] != s.id) {
          throw const FormatException('Record identity mismatch');
        }
        super.retain(s);
        _attach(s, version, jsonEncode(row['session']));
      } catch (_) {
        recoveryMessages.add(
          'Saved record ${i + 1} is damaged or uses an unsupported schema. It was not changed or opened. Keep this browser data for recovery.',
        );
      }
    }
    initialized = true;
  }

  void _attach(InspectionSession s, int version, String? committed) {
    final writer = _Writer(s, store, version, debounce, committed);
    _writers[s.id] = writer;
    s.persist = writer.flush;
    if (store is MediaStore) {
      s.loadMedia = (attemptId) =>
          (store as MediaStore).readMedia(s.id, attemptId);
    }
    s.addListener(writer.changed);
    writer.changed();
  }

  @override
  InspectionSession create({
    required String technician,
    String location = 'Costa Oil Change - Chalmette',
  }) {
    if (!initialized) {
      throw StateError('Load saved inspections before creating one.');
    }
    final s = super.create(technician: technician, location: location);
    _attach(s, 0, null);
    return s;
  }

  @override
  void retain(InspectionSession session) {
    if (!_writers.containsKey(session.id)) {
      throw StateError('Session does not belong to this local repository.');
    }
    super.retain(session);
  }

  void dispose() {
    for (final w in _writers.values) {
      w.dispose();
    }
    store.close();
  }
}

class _Writer {
  final InspectionSession session;
  final InspectionStore store;
  final Duration debounce;
  int version;
  String? committed;
  Timer? timer;
  Future<bool>? running;
  bool disposed = false;
  _Writer(
    this.session,
    this.store,
    this.version,
    this.debounce,
    this.committed,
  );

  void changed() {
    if (disposed || session.savePhase.value == SavePhase.conflict) return;
    final encoded = jsonEncode(session.toRecord());
    if (encoded == committed && running == null) {
      session.savePhase.value = SavePhase.saved;
      return;
    }
    if (session.savePhase.value == SavePhase.failed) {
      return; // Explicit retry after failure.
    }
    session.savePhase.value = SavePhase.saving;
    timer?.cancel();
    timer = Timer(debounce, flush);
  }

  Future<bool> flush() {
    timer?.cancel();
    if (disposed || session.savePhase.value == SavePhase.conflict) {
      return Future.value(false);
    }
    return running ??= _save().whenComplete(() => running = null);
  }

  Future<bool> _save() async {
    session.savePhase.value = SavePhase.saving;
    try {
      while (!disposed) {
        final encoded = jsonEncode(session.toRecord());
        if (encoded == committed) {
          session.savePhase.value = SavePhase.saved;
          return true;
        }
        final snapshot = Map<String, Object?>.from(jsonDecode(encoded) as Map);
        final media = Map<String, Uint8List>.from(session.pendingMedia);
        if (media.isNotEmpty) {
          if (store is! MediaStore) {
            throw StateError('Binary media storage unavailable');
          }
          version = await (store as MediaStore).writeWithMedia(
            session.id,
            version,
            snapshot,
            media,
          );
          session.mediaWriteConfirmed(media.keys);
        } else {
          version = await store.write(session.id, version, snapshot);
        }
        committed = encoded;
        // Repeat using newest state; an older async write never wins over newer edits.
      }
      return false;
    } on StorageConflict {
      session.savePhase.value = SavePhase.conflict;
      return false;
    } catch (_) {
      session.savePhase.value = SavePhase.failed;
      return false;
    }
  }

  void dispose() {
    disposed = true;
    timer?.cancel();
    session.removeListener(changed);
  }
}
