import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/idb_client_memory.dart';
import 'package:verify_app/models/ai_observation.dart';
import 'package:verify_app/services/inspection_store.dart';
import 'package:verify_app/models/inspection_session.dart';
import 'package:verify_app/models/local_media.dart';
import 'package:verify_app/services/camera_service.dart';
import 'package:verify_app/services/real_capture_controller.dart';
import 'package:verify_app/services/indexed_db_inspection_store.dart';
import 'package:verify_app/services/local_inspection_repository.dart';
import 'package:verify_app/services/media_store.dart';
import 'package:verify_app/widgets/real_capture_dialog.dart';
import 'package:verify_app/screens/guided_inspection_screen.dart';

import 'support.dart';
import 'local_storage_test.dart' show FaultStore;
import 'customer_report_test.dart' show approved;
import 'inspection_complete_test.dart' show finish;

// Contract fixtures, not a claim of physical capture or actual video decoding.
CapturedMedia fixture({
  int ms = 5000,
  bool empty = false,
  bool playable = true,
  bool photo = false,
}) => CapturedMedia(
  bytes: empty
      ? Uint8List(0)
      : Uint8List.fromList([137, 80, 78, 71, 1, 2, 3, ms % 255]),
  mimeType: photo ? 'image/png' : 'video/webm',
  duration: Duration(milliseconds: photo ? 0 : ms),
  playable: playable,
  source: 'fixture',
);

class MediaFaultStore extends FaultStore implements MediaStore {
  final Map<String, Uint8List> files = {};
  @override
  Future<Uint8List?> readMedia(String inspectionId, String attemptId) async =>
      files['$inspectionId/$attemptId'];
  @override
  Future<int> writeWithMedia(
    String id,
    int expectedVersion,
    Map<String, Object?> session,
    Map<String, Uint8List> media,
  ) async {
    final version = await write(id, expectedVersion, session);
    for (final e in media.entries) {
      files['$id/${e.key}'] = Uint8List.fromList(e.value);
    }
    return version;
  }
}

Future<(LocalInspectionRepository, InspectionSession)> stored(
  MediaFaultStore store, {
  InspectionSession? original,
}) async {
  final s = original ?? readySession();
  await store.write(s.id, 0, s.toRecord());
  final repo = LocalInspectionRepository(store);
  await repo.initialize();
  return (repo, repo.records.single);
}

CaptureAttempt captureFixture(
  InspectionSession s,
  String id,
  CapturedMedia result,
) {
  final a = s.beginCapture(
    id,
    id == 'dipstick' ? CaptureKind.photo : CaptureKind.video,
    realMedia: true,
  );
  s.finishRealCapture(a, result);
  return a;
}

class FixtureCamera implements CameraService {
  Completer<void>? openGate, startGate;
  Completer<CapturedMedia>? stopGate;
  String? failure;
  bool? requestedAudio;
  int opens = 0, starts = 0, stops = 0, releases = 0;
  @override
  Widget preview() => const Text('FIXTURE CAMERA');
  @override
  Future<void> open({required bool audio}) async {
    opens++;
    requestedAudio = audio;
    if (failure != null) throw StateError(failure!);
    await openGate?.future;
  }

  @override
  Future<void> start() async {
    starts++;
    await startGate?.future;
  }

  @override
  Future<CapturedMedia> photo() async => fixture(photo: true);
  @override
  Future<CapturedMedia> stop() async {
    stops++;
    return stopGate == null ? fixture() : await stopGate!.future;
  }

  @override
  void dispose() {
    releases++;
  }
}

void main() {
  testWidgets(
    'saved review survives reload and requires explicit Keep; accepted clip remains accessible',
    (tester) async {
      final store = MediaFaultStore();
      final (repo, s) = await stored(store);
      final attempt = captureFixture(s, 'drain_plug', fixture());
      await s.flush();
      final auditLength = s.audit.length;
      final restored = LocalInspectionRepository(store);
      await restored.initialize();
      final session = restored.records.single;
      expect(session.attempts.single.status, CaptureStatus.review);
      expect(session.step('drain_plug').isComplete, isFalse);
      await tester.pumpWidget(
        MaterialApp(home: GuidedInspectionScreen(session: session)),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Saved locally, awaiting review — not accepted.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('KEEP — RECORDING IS SUFFICIENT'));
      await tester.tap(find.text('KEEP — RECORDING IS SUFFICIENT'));
      await tester.pumpAndSettle();
      expect(session.attempts.single.status, CaptureStatus.accepted);
      expect(session.audit.length, greaterThan(auditLength));
      expect(await session.loadMedia!(attempt.id), fixture().bytes);
      expect(find.text('PLAY ACCEPTED LOCAL RECORDING'), findsOneWidget);
      await session.flush();
      final next = LocalInspectionRepository(store);
      await next.initialize();
      expect(
        next.records.single.attempts.single.status,
        CaptureStatus.accepted,
      );
      repo.dispose();
      restored.dispose();
      next.dispose();
    },
  );
  test('media checksum is stable across VM and browser', () {
    expect(mediaChecksum([0, 1, 127, 128, 255]), 'd9901cb6');
  });
  test('real-media bytes, association, provenance and status survive atomic save/reload', () async {
    final store = MediaFaultStore();
    final (repo, s) = await stored(store);
    final a = captureFixture(s, 'drain_plug', fixture());
    s.acceptCapture(a);
    expect(a.status, CaptureStatus.review);
    expect(await s.flush(), isTrue);
    s.acceptCapture(a);
    await s.flush();
    final next = LocalInspectionRepository(store);
    await next.initialize();
    final r = next.records.single;
    final restored = r.attempts.single;
    expect(restored.mediaSaved, isTrue);
    expect(restored.status, CaptureStatus.accepted);
    expect(restored.media!.inspectionId, r.id);
    expect(restored.media!.stepId, 'drain_plug');
    expect(restored.media!.source, 'fixture');
    expect(restored.media!.matches((await r.loadMedia!(restored.id))!), isTrue);
    expect(await store.readMedia('another-inspection', a.id), isNull);
    expect(r.realApproved, isFalse);
    expect(projectCustomerReport(r)['verifiedFacts'], isEmpty);
    repo.dispose();
    next.dispose();
  });
  for (final id in ['drain_plug', 'oil_filter', 'top_filter']) {
    for (final ms in [4999, 5000]) {
      test(
        'finalized $id at $ms ms preserves its actual duration and gate',
        () async {
          final original = readySession();
          if (id == 'oil_filter') captureAndKeep(original, 'drain_plug');
          if (id == 'top_filter') {
            original.setFilterUnderHood(true);
            completeVehicleStage(original);
          }
          final store = MediaFaultStore();
          final (repo, s) = await stored(store, original: original);
          final a = captureFixture(s, id, fixture(ms: ms));
          await s.flush();
          s.acceptCapture(a);
          expect(s.step(id).isComplete, ms >= 5000);
          expect(a.media!.durationMs, ms);
          expect(
            a.media!.stage,
            id == 'top_filter' ? 'Under Hood' : 'Under Vehicle',
          );
          repo.dispose();
        },
      );
    }
  }
  test(
    'empty, undecodable and unknown-duration payloads never complete evidence',
    () {
      for (final result in [
        fixture(empty: true),
        fixture(playable: false),
        fixture(ms: 0),
      ]) {
        final s = readySession();
        expect(() => captureFixture(s, 'drain_plug', result), throwsStateError);
        expect(s.step('drain_plug').isComplete, isFalse);
        expect(s.attempts.single.status, CaptureStatus.failed);
      }
    },
  );
  test('media write failure retains last committed state and prevents Keep until retry', () async {
    final store = MediaFaultStore();
    final (repo, s) = await stored(store);
    await s.flush();
    final previous = jsonEncode(store.rows);
    store.fail = true;
    final a = captureFixture(s, 'drain_plug', fixture());
    expect(await s.flush(), isFalse);
    s.acceptCapture(a);
    expect(a.status, CaptureStatus.review);
    expect(a.mediaSaved, isFalse);
    expect(s.savePhase.value, SavePhase.failed);
    expect(jsonEncode(store.rows), previous);
    expect(store.files, isEmpty);
    store.fail = false;
    expect(await s.flush(), isTrue);
    s.acceptCapture(a);
    expect(s.step('drain_plug').isComplete, isTrue);
    repo.dispose();
  });
  test('retakes retain old bytes; changed evidence invalidates approvals and immutable completed media references', () async {
    final store = MediaFaultStore();
    final (repo, s) = await stored(store, original: approved());
    s.setStage(false);
    final first = captureFixture(s, 'drain_plug', fixture());
    await s.flush();
    s.acceptCapture(first);
    // A fresh simulated assessment is still required after real evidence changes.
    final concern = s.observations.first;
    s.decide(concern, concern.status, 'not a real concern');
    // Use the existing explicit dismissal behavior.
    final snapshotBefore = first.media!.toMap();
    final oldBytes = await store.readMedia(s.id, first.id);
    final second = captureFixture(s, 'drain_plug', fixture(ms: 6000));
    expect(s.approvals, everyElement(isFalse));
    expect(s.demoApproved, isFalse);
    await s.flush();
    s.acceptCapture(second);
    await s.flush();
    expect(first.status, CaptureStatus.superseded);
    expect(first.media!.toMap(), snapshotBefore);
    expect(await store.readMedia(s.id, first.id), oldBytes);
    expect(
      jsonEncode(projectCustomerReport(s)),
      isNot(contains('"id":"${first.id}"')),
    );
    expect(jsonEncode(projectCustomerReport(s)), contains(second.id));
    repo.dispose();
  });
  test('completed snapshots retain original media IDs across reopen and replacement', () async {
    final original = approved();
    original.setStage(false);
    final store = MediaFaultStore();
    final (repo, s) = await stored(store, original: original);
    final a = captureFixture(s, 'drain_plug', fixture());
    await s.flush();
    s.acceptCapture(a);
    // Existing fixture helper builds valid approval using explicit model decisions.
    for (final o in s.observations.where((o) => o.requiresAction)) {
      s.decide(
        o,
        AiObservationStatus.dismissed,
        'Fixture is not a concern',
        notActualConcern: true,
      );
    }
    acknowledge(s);
    s.completeDemo();
    await finish(s);
    await s.flush();
    final snapshot = s.completion!.snapshot;
    s.reopen('Fixture revision test', completedRevision: s.reportRevision);
    s.setStage(false);
    final b = captureFixture(s, 'drain_plug', fixture(ms: 6000));
    await s.flush();
    s.acceptCapture(b);
    await s.flush();
    expect(jsonEncode(snapshot.data), contains(a.id));
    expect(jsonEncode(snapshot.data), isNot(contains(b.id)));
    final restored = LocalInspectionRepository(store);
    await restored.initialize();
    expect(
      restored.records.single.completedRevisions.single.snapshot.data,
      snapshot.data,
    );
    repo.dispose();
    restored.dispose();
  });
  test(
    'missing/corrupt file invalidates restored required check and approval',
    () async {
      final store = MediaFaultStore();
      final (repo, s) = await stored(store);
      final a = captureFixture(s, 'drain_plug', fixture());
      await s.flush();
      s.acceptCapture(a);
      await s.flush();
      store.files['${s.id}/${a.id}'] = Uint8List.fromList([0]);
      final r = LocalInspectionRepository(store);
      await r.initialize();
      expect(r.records.single.step('drain_plug').isComplete, isFalse);
      expect(r.records.single.approvals, everyElement(isFalse));
      repo.dispose();
      r.dispose();
    },
  );
  test('IndexedDB v1 migration preserves original records and writes files atomically', () async {
    final factory = newIdbFactoryMemory();
    final db = await factory.open(
      'migration',
      version: 1,
      onUpgradeNeeded: (e) =>
          e.database.createObjectStore('inspections', keyPath: 'id'),
    );
    final tx = db.transaction('inspections', idbModeReadWrite);
    final old = readySession().toRecord()..['schema'] = 1;
    await tx.objectStore('inspections').put({
      'id': 'old',
      'storageVersion': 1,
      'session': old,
    });
    await tx.completed;
    db.close();
    final adapter = IndexedDbInspectionStore(
      factory,
      databaseName: 'migration',
    );
    expect((await adapter.readAll()).single, {
      'id': 'old',
      'storageVersion': 1,
      'session': old,
    });
    await adapter.writeWithMedia(
      'new',
      0,
      {'fixture': true},
      {'a': fixture().bytes},
    );
    expect(await adapter.readMedia('new', 'a'), fixture().bytes);
    await expectLater(
      adapter.writeWithMedia('new', 0, {'bad': true}, {'b': fixture().bytes}),
      throwsA(isA<StorageConflict>()),
    );
    expect(await adapter.readMedia('new', 'b'), isNull);
    expect((await adapter.readAll()).length, 2);
    adapter.close();
  });
  test('permission/device errors never create a simulated success', () async {
    for (final message in [
      'Permission denied',
      'No camera',
      'Camera in use',
      'Unsupported format',
    ]) {
      final service = FixtureCamera()..failure = message;
      final s = readySession();
      final c = RealCaptureController(
        s,
        service,
        'drain_plug',
        CaptureKind.video,
      );
      await c.enable(false);
      expect(c.error, contains(message));
      expect(c.cameraActive, isFalse);
      expect(s.attempts, isEmpty);
      c.dispose();
    }
  });
  test('rapid starts/stops and navigation discard stale results and release resources', () async {
    final service = FixtureCamera()
      ..startGate = Completer<void>()
      ..stopGate = Completer<CapturedMedia>();
    final s = readySession();
    final c = RealCaptureController(
      s,
      service,
      'drain_plug',
      CaptureKind.video,
    );
    await c.enable(false);
    final start = c.capture();
    await c.capture();
    expect(service.starts, 1);
    service.startGate!.complete();
    await start;
    final stop = c.stop();
    await c.stop();
    expect(service.stops, 1);
    c.dispose();
    service.stopGate!.complete(fixture());
    await stop;
    expect(s.attempts.single.status, CaptureStatus.cancelled);
    expect(s.pendingMedia, isEmpty);
    expect(service.releases, greaterThan(0));
  });
  test(
    'leaving unanswered permission cannot activate a stale camera',
    () async {
      final service = FixtureCamera()..openGate = Completer<void>();
      final s = readySession();
      final c = RealCaptureController(
        s,
        service,
        'drain_plug',
        CaptureKind.video,
      );
      final pending = c.enable(true);
      c.dispose();
      service.openGate!.complete();
      await pending;
      expect(s.attempts, isEmpty);
      expect(c.cameraActive, isFalse);
      expect(service.releases, greaterThan(0));
    },
  );
  for (final size in [const Size(360, 800), const Size(1440, 1000)]) {
    testWidgets(
      'actual camera dialog controls require explicit permission and capture at ${size.width}px',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        final store = MediaFaultStore();
        final (repo, s) = await stored(store);
        final camera = FixtureCamera();
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showRealCapture(
                    context,
                    s,
                    'drain_plug',
                    CaptureKind.video,
                    cameraService: camera,
                  ),
                  child: const Text('Open camera'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open camera'));
        await tester.pumpAndSettle();
        expect(camera.opens, 0);
        expect(camera.starts, 0);
        expect(
          tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isFalse,
        );
        await tester.ensureVisible(find.text('Include microphone narration'));
        await tester.tap(find.text('Include microphone narration'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.text('ENABLE CAMERA — REQUEST PERMISSION'),
        );
        await tester.tap(find.text('ENABLE CAMERA — REQUEST PERMISSION'));
        await tester.pumpAndSettle();
        expect(camera.opens, 1);
        expect(camera.requestedAudio, isTrue);
        expect(camera.starts, 0);
        await tester.ensureVisible(find.text('START ACTUAL VIDEO'));
        await tester.tap(find.text('START ACTUAL VIDEO'));
        await tester.pumpAndSettle();
        expect(camera.starts, 1);
        expect(s.attempts.single.status, CaptureStatus.recording);
        await tester.ensureVisible(find.text('STOP AND VALIDATE CLIP'));
        await tester.tap(find.text('STOP AND VALIDATE CLIP'));
        await tester.pumpAndSettle();
        expect(camera.stops, 1);
        expect(s.attempts.single.status, CaptureStatus.review);
        expect(s.attempts.single.mediaSaved, isTrue);
        expect(s.step('drain_plug').isComplete, isFalse);
        expect(find.text('KEEP — RECORDING IS SUFFICIENT'), findsOneWidget);
        expect(find.text('RECORD AGAIN'), findsOneWidget);
        await tester.ensureVisible(find.text('KEEP — RECORDING IS SUFFICIENT'));
        await tester.tap(find.text('KEEP — RECORDING IS SUFFICIENT'));
        await tester.pumpAndSettle();
        expect(s.attempts.single.status, CaptureStatus.accepted);
        expect(camera.releases, greaterThan(0));
        expect(tester.takeException(), isNull);
        repo.dispose();
        await tester.binding.setSurfaceSize(null);
      },
    );
  }
}
