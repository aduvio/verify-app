import 'package:idb_shim/idb_browser.dart';

import 'inspection_store.dart';
import 'indexed_db_inspection_store.dart';

InspectionStore? createBrowserStore() =>
    IndexedDbInspectionStore(getIdbFactory()!);
