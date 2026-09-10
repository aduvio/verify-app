import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/idb_client_memory.dart';
import 'package:verify_app/models/inspection_session.dart';
import 'package:verify_app/models/ai_observation.dart';
import 'package:verify_app/services/inspection_store.dart';
import 'package:verify_app/services/indexed_db_inspection_store.dart';
import 'package:verify_app/services/local_inspection_repository.dart';
import 'package:verify_app/widgets/session_save_boundary.dart';
import 'package:verify_app/screens/saved_inspections_screen.dart';

import 'support.dart';
import 'customer_report_test.dart' show approved, review, ControlledDelivery;
import 'inspection_complete_test.dart' show finish;

class FaultStore implements InspectionStore {
  final Map<String, Object?> rows = {};
  bool fail = false;
  Completer<void>? gate;
  int writes = 0;
  @override
  Future<List<Object?>> readAll() async =>
      jsonDecode(jsonEncode(rows.values.toList())) as List;
  @override
  Future<int> write(
    String id,
    int expectedVersion,
    Map<String, Object?> session,
  ) async {
    writes++;
    if (gate != null) await gate!.future;
    if (fail) throw StateError('quota');
    final old = rows[id] as Map?;
    if ((old?['storageVersion'] ?? 0) != expectedVersion) {
      throw const StorageConflict();
    }
    rows[id] = jsonDecode(
      jsonEncode({
        'id': id,
        'storageVersion': expectedVersion + 1,
        'session': session,
      }),
    );
    return expectedVersion + 1;
  }

  @override
  void close() {}
}

void main() {
  test('complete aggregate round trip preserves snapshots, audit, notes, evidence, decisions and provenance', () async {
    final s = approved();
    s.setNote('PRIVATE', customerVisible: false);
    s.setNote('Consider maintenance', customerVisible: true);
    acknowledge(s);
    s.completeDemo();
    await finish(s);
    final before = jsonEncode(s.toRecord());
    final restored = restoreInspection(jsonDecode(before));
    expect(jsonEncode(restored.toRecord()), before);
    expect(restored.completionCurrent, isTrue);
    expect(restored.editable, isFalse);
    expect(restored.attempts.length, s.attempts.length);
    expect(restored.customer!.displayName, s.customer!.displayName);
    expect(restored.vehicle!.vin, s.vehicle!.vin);
    expect(restored.internalNote!.text, 'PRIVATE');
    final old = restored.completion!.snapshot;
    expect(jsonEncode(old.data), isNot(contains('PRIVATE')));
    expect(jsonEncode(old.data), isNot(contains('Synthetic possible leak')));
    expect(old.data['verifiedFacts'], isEmpty);
    expect(restored.realApproved, isFalse);
    expect(
      restored.reopen(
        'Correct note',
        completedRevision: restored.reportRevision,
      ),
      isTrue,
    );
    final reopened = restoreInspection(
      jsonDecode(jsonEncode(restored.toRecord())),
    );
    expect(reopened.completedRevisions.single.snapshot.data, old.data);
    expect(reopened.deliveryAttempts.single.recipient, s.customer!.phone);
    expect(reopened.audit.last.action, 'demo_inspection_reopened');
    expect(reopened.approvals, everyElement(isFalse));
  });

  test('unresolved concern, missing evidence, stale revision and dipstick sequence cannot become approved on reload', () {
    final s = approved();
    final o = s.observations.first;
    s.decide(o, AiObservationStatus.furtherInspection, 'Mechanic needed');
    var r = restoreInspection(s.toRecord());
    expect(r.flagsResolved, isFalse);
    expect(r.prepareReport(), isFalse);
    final good = approved();
    final record = good.toRecord();
    record['approvedRevision'] = -1;
    r = restoreInspection(record);
    expect(r.demoApproved, isFalse);
    expect(r.approvals, everyElement(isFalse));
    final missing = approved().toRecord();
    missing['captures'] = [];
    r = restoreInspection(missing);
    expect(r.allChecksComplete, isFalse);
    expect(r.demoApproved, isFalse);
    final short = approved().toRecord();
    for (final a in short['captures'] as List) {
      if (a['stepId'] == 'drain_plug' || a['stepId'] == 'oil_filter') {
        a['durationMs'] = 4999;
      }
    }
    r = restoreInspection(short);
    expect(r.step('drain_plug').isComplete, isFalse);
    final awaitingReview = readySession();
    final attempt = awaitingReview.beginCapture(
      'drain_plug',
      CaptureKind.video,
    );
    awaitingReview.recordingStarted(attempt);
    awaitingReview.finishCapture(attempt, const Duration(seconds: 5));
    expect(attempt.status, CaptureStatus.review);
    final cancelledReview = restoreInspection(awaitingReview.toRecord());
    expect(cancelledReview.attempts.single.status, CaptureStatus.cancelled);
    expect(cancelledReview.step('drain_plug').isComplete, isFalse);
    expect(r.step('oil_filter').isComplete, isFalse);
    final wrongOrder = approved().toRecord();
    final captures = wrongOrder['captures'] as List;
    final photo = captures.removeAt(
      captures.indexWhere((a) => a['stepId'] == 'dipstick'),
    );
    captures.add(photo);
    r = restoreInspection(wrongOrder);
    expect(r.step('caps_touch').isComplete, isFalse);
  });

  test(
    'five-second top filter, retakes and corrected concern survive restoration',
    () {
      final s = readySession();
      s.setFilterUnderHood(true);
      completeChecks(s);
      captureAndKeep(s, 'top_filter');
      final o = addConcern(s);
      s.decide(o, AiObservationStatus.confirmed, 'Concern exists');
      s.addressConcern(
        o,
        'Simulated cleanup',
        'Simulated successful recheck',
        recheckPassed: true,
      );
      final r = restoreInspection(s.toRecord());
      expect(r.requiredSteps.any((step) => step.id == 'top_filter'), isTrue);
      expect(r.step('top_filter').minimumSeconds, 5);
      expect(
        r.currentCapture('top_filter')!.duration,
        const Duration(seconds: 5),
      );
      expect(
        r.attempts.where((a) => a.status == CaptureStatus.superseded),
        hasLength(1),
      );
      expect(r.observations.single.correctiveAction, 'Simulated cleanup');
      expect(r.observations.single.addressedBy, s.technician);
      expect(r.flagsResolved, isTrue);
    },
  );

  test('interrupted capture and delivery become cancelled/stale, never accepted or resent', () async {
    final s = readySession();
    s.beginCapture('drain_plug', CaptureKind.video);
    final r = restoreInspection(s.toRecord());
    expect(r.attempts.single.status, CaptureStatus.cancelled);
    expect(r.step('drain_plug').isComplete, isFalse);
    final a = approved();
    review(a);
    final service = ControlledDelivery();
    final pending = a.simulateDelivery(service);
    final restored = restoreInspection(a.toRecord());
    expect(
      restored.deliveryAttempts.single.status,
      DeliveryAttemptStatus.stale,
    );
    expect(restored.completion, isNull);
    expect(restored.canSimulateSend, isFalse);
    expect(restored.deliveryConfirmations, everyElement(isFalse));
    service.gate.complete();
    await pending;
    expect(restored.completion, isNull);
  });

  test('atomic IndexedDB adapter semantics retain multiple records and reject concurrent stale versions', () async {
    final factory = newIdbFactoryMemory();
    final a = IndexedDbInspectionStore(factory);
    final b = IndexedDbInspectionStore(factory);
    final s = readySession();
    expect(await a.write(s.id, 0, s.toRecord()), 1);
    await a.write('second', 0, {'separate': true});
    expect(await b.write(s.id, 1, s.toRecord()), 2);
    await expectLater(
      a.write(s.id, 1, {'bad': 'stale'}),
      throwsA(isA<StorageConflict>()),
    );
    final rows = await b.readAll();
    expect(rows, hasLength(2));
    expect(
      (rows.firstWhere((r) => (r as Map)['id'] == s.id) as Map)['session'],
      s.toRecord(),
    );
    a.close();
    b.close();
  });

  test('serialized autosaves retain last committed state after failure and newest edit after retry', () async {
    final store = FaultStore();
    final repo = LocalInspectionRepository(store);
    await repo.initialize();
    final s = repo.create(technician: 'Test');
    expect(s.savePhase.value, SavePhase.saving);
    expect(await s.flush(), isTrue);
    final old = jsonEncode(store.rows);
    store.fail = true;
    s.setNote('Unsaved', customerVisible: false);
    expect(await s.flush(), isFalse);
    expect(s.savePhase.value, SavePhase.failed);
    expect(jsonEncode(store.rows), old);
    s.setNote('Newest edit', customerVisible: false);
    store.fail = false;
    expect(await s.flush(), isTrue);
    expect(s.savePhase.value, SavePhase.saved);
    final reloaded = LocalInspectionRepository(store);
    await reloaded.initialize();
    expect(reloaded.records.single.internalNote!.text, 'Newest edit');
    repo.dispose();
    reloaded.dispose();
  });

  test('an older pending write is followed by latest state and cannot show Saved early', () async {
    final store = FaultStore();
    final repo = LocalInspectionRepository(store);
    await repo.initialize();
    final s = repo.create(technician: 'Test');
    await s.flush();
    store.gate = Completer<void>();
    s.setNote('first', customerVisible: false);
    final pending = s.flush();
    s.setNote('latest', customerVisible: false);
    expect(s.savePhase.value, SavePhase.saving);
    store.gate!.complete();
    expect(await pending, isTrue);
    expect(s.savePhase.value, SavePhase.saved);
    expect(
      ((store.rows[s.id] as Map)['session'] as Map)['internalNote']['text'],
      'latest',
    );
    repo.dispose();
  });

  test(
    'corrupt and unsupported records are preserved without destructive reset',
    () async {
      final store = FaultStore();
      store.rows['broken'] = {
        'id': 'broken',
        'storageVersion': 1,
        'session': {'schema': 1},
      };
      store.rows['future'] = {
        'id': 'future',
        'storageVersion': 1,
        'session': {'schema': 999},
      };
      final before = jsonEncode(store.rows);
      final repo = LocalInspectionRepository(store);
      await repo.initialize();
      expect(repo.records, isEmpty);
      expect(repo.recoveryMessages, hasLength(2));
      expect(jsonEncode(store.rows), before);
      expect(store.writes, 0);
      repo.dispose();
    },
  );

  test(
    'two repository editors cannot silently overwrite one another',
    () async {
      final store = FaultStore();
      final a = LocalInspectionRepository(store);
      await a.initialize();
      final first = a.create(technician: 'Test');
      await first.flush();
      final b = LocalInspectionRepository(store);
      await b.initialize();
      final other = b.records.single;
      first.setNote('Winner', customerVisible: false);
      await first.flush();
      other.setNote('Retain unsaved conflict', customerVisible: false);
      expect(await other.flush(), isFalse);
      expect(other.savePhase.value, SavePhase.conflict);
      expect(other.editable, isFalse);
      expect(other.internalNote!.text, 'Retain unsaved conflict');
      expect(
        ((store.rows[first.id] as Map)['session']
            as Map)['internalNote']['text'],
        'Winner',
      );
      a.dispose();
      b.dispose();
    },
  );

  test('failed prerequisite save prevents service and completion; failed completion save prevents success', () async {
    final store = FaultStore();
    final original = approved();
    await store.write(original.id, 0, original.toRecord());
    final repo = LocalInspectionRepository(store);
    await repo.initialize();
    final s = repo.records.single;
    review(s);
    store.fail = true;
    final service = ControlledDelivery();
    expect(await s.simulateDelivery(service), isFalse);
    expect(service.calls, 0);
    expect(s.completion, isNull);
    store.fail = false;
    await s.flush();
    review(s);
    final next = ControlledDelivery();
    final result = s.simulateDelivery(next);
    // Wait for the service start after its successful prerequisite transaction.
    while (next.calls == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    store.fail = true;
    next.gate.complete();
    expect(await result, isFalse);
    expect(s.saved, isFalse);
    expect(s.deliveryMessage, contains('saving failed'));
    final persisted = restoreInspection((store.rows[s.id] as Map)['session']);
    expect(persisted.completion, isNull);
    store.fail = false;
    expect(await s.flush(), isTrue);
    expect(
      restoreInspection((store.rows[s.id] as Map)['session']).completionCurrent,
      isTrue,
    );
    repo.dispose();
  });

  testWidgets(
    'save indicator confirms writes only and exposes retry on failure',
    (tester) async {
      final store = FaultStore();
      final repo = LocalInspectionRepository(store);
      await repo.initialize();
      final s = repo.create(technician: 'Test');
      store.fail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: SessionSaveBoundary(
            session: s,
            child: const Scaffold(body: Text('Demo')),
          ),
        ),
      );
      expect(find.text('Saving...'), findsOneWidget);
      await s.flush();
      await tester.pump();
      expect(find.text('Save failed — retry required.'), findsOneWidget);
      expect(find.text('Saved on this device.'), findsNothing);
      store.fail = false;
      await tester.tap(find.text('RETRY SAVE'));
      await tester.pumpAndSettle();
      expect(find.text('Saved on this device.'), findsOneWidget);
      repo.dispose();
    },
  );

  testWidgets(
    'saved inspection chooser retains separate records at phone and desktop sizes',
    (tester) async {
      final store = FaultStore();
      final completed = approved();
      await finish(completed);
      await store.write(completed.id, 0, completed.toRecord());
      final repo = LocalInspectionRepository(store);
      await repo.initialize();
      final next = repo.create(technician: 'Test');
      await next.flush();
      for (final size in [const Size(360, 800), const Size(1440, 1000)]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          MaterialApp(home: SavedInspectionsScreen(repository: repo)),
        );
        await tester.pumpAndSettle();
        expect(find.text('VIEW'), findsOneWidget);
        expect(find.text('RESUME'), findsOneWidget);
        expect(find.textContaining(completed.id), findsOneWidget);
        expect(find.textContaining(next.id), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.binding.setSurfaceSize(null);
      repo.dispose();
    },
  );

  testWidgets('conflict feedback blocks editing and fits phone and desktop', (
    tester,
  ) async {
    final repo = LocalInspectionRepository(FaultStore());
    await repo.initialize();
    final s = repo.create(technician: 'Test');
    await s.flush();
    var taps = 0;
    s.savePhase.value = SavePhase.conflict;
    for (final size in [const Size(360, 800), const Size(1440, 1000)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          home: SessionSaveBoundary(
            session: s,
            child: Scaffold(
              body: TextButton(
                onPressed: () => taps++,
                child: const Text('Edit'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Save conflict'), findsOneWidget);
      final position = tester.getCenter(find.text('Edit'));
      await tester.tapAt(position);
      expect(taps, 0);
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
    repo.dispose();
  });
}
