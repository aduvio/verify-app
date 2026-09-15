import 'package:idb_shim/idb_browser.dart';

import 'inspection_store.dart';
import 'indexed_db_inspection_store.dart';

InspectionStore? createBrowserStore({
  String databaseName = 'project_verify_local_v1',
}) => IndexedDbInspectionStore(
  getIdbFactory()!,
  databaseName: databaseName,
  closeOnVersionChange: true,
);
