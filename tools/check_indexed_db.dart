// Browser-compiled adapter fixture. Does not access physical devices or app data.
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:idb_shim/idb_browser.dart';

import 'package:verify_app/services/indexed_db_inspection_store.dart';
import 'package:verify_app/services/inspection_store.dart';
import 'package:verify_app/models/local_media.dart';

@JS('adapterFixtureResult')
external set result(JSAny value);
Future<void> main() async {
  try {
    final name =
        'verify_dart_adapter_fixture_${DateTime.now().microsecondsSinceEpoch}';
    final factory = getIdbFactory()!;
    final legacy = await factory.open(
      name,
      version: 1,
      onUpgradeNeeded: (e) =>
          e.database.createObjectStore('inspections', keyPath: 'id'),
    );
    final transaction = legacy.transaction('inspections', idbModeReadWrite);
    await transaction.objectStore('inspections').put({
      'id': 'legacy-fixture',
      'storageVersion': 1,
      'session': {'preserve': true},
    });
    await transaction.completed;
    final a = IndexedDbInspectionStore(
      factory,
      databaseName: name,
      closeOnVersionChange: true,
    );
    var blocked = false;
    try {
      await a.readAll();
    } catch (e) {
      blocked = '$e'.contains('blocked');
    }
    if (!blocked) throw StateError('Upgrade did not report the older open tab');
    legacy.close();
    if ((await a.readAll()).length != 1) {
      throw StateError('Legacy record lost during migration');
    }
    final bytes = Uint8List.fromList([0, 1, 127, 128, 255]);
    await a.writeWithMedia(
      'fixture-inspection',
      0,
      {'schema': 2, 'fixture': true},
      {'fixture-attempt': bytes},
    );
    final b = IndexedDbInspectionStore(
      factory,
      databaseName: name,
      closeOnVersionChange: true,
    );
    final loaded = await b.readMedia('fixture-inspection', 'fixture-attempt');
    if (loaded == null || mediaChecksum(loaded) != mediaChecksum(bytes)) {
      throw StateError('Binary round trip mismatch');
    }
    if (await b.readMedia('other-inspection', 'fixture-attempt') != null) {
      throw StateError('Cross-inspection media leak');
    }
    var conflicted = false;
    try {
      await b.writeWithMedia(
        'fixture-inspection',
        0,
        {'bad': true},
        {'bad-file': bytes},
      );
    } on StorageConflict {
      conflicted = true;
    }
    if (!conflicted ||
        await b.readMedia('fixture-inspection', 'bad-file') != null) {
      throw StateError('Atomic conflict guard failed');
    }
    if ((await b.readAll()).length != 2) {
      throw StateError('Stored aggregate missing');
    }
    a.close();
    b.close();
    result = {
      'passed': true,
      'bytes': loaded.length,
      'checksum': mediaChecksum(loaded),
      'blockedUpgradeAndMigration': true,
    }.jsify()!;
  } catch (e) {
    result = {'passed': false, 'error': '$e'}.jsify()!;
  }
}
