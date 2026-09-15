import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verify_app/services/browser_store.dart';
import 'package:verify_app/services/local_inspection_repository.dart';
import 'package:verify_app/models/inspection_session.dart';

import 'support.dart';
import 'real_media_test.dart' show fixture, captureFixture;

void main() {
  test(
    'real browser IndexedDB adapter retains actual binary bytes across repository reload',
    () async {
      final name =
          'verify_media_adapter_fixture_${DateTime.now().microsecondsSinceEpoch}';
      final store = createBrowserStore(databaseName: name)!;
      final original = readySession();
      await store.write(original.id, 0, original.toRecord());
      final repo = LocalInspectionRepository(store);
      await repo.initialize();
      final s = repo.records.single;
      final a = captureFixture(s, 'drain_plug', fixture());
      expect(await s.flush(), isTrue);
      s.acceptCapture(a);
      expect(await s.flush(), isTrue);
      final next = LocalInspectionRepository(
        createBrowserStore(databaseName: name)!,
      );
      await next.initialize();
      final restored = next.records.single;
      expect(restored.attempts.single.status, CaptureStatus.accepted);
      expect(restored.attempts.single.mediaSaved, isTrue);
      expect(await restored.loadMedia!(a.id), fixture().bytes);
      repo.dispose();
      next.dispose();
    },
    skip: !kIsWeb
        ? 'Requires actual Chrome IndexedDB; run with --platform chrome.'
        : false,
  );
}
