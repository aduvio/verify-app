import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'screens/new_inspection_screen.dart';
import 'screens/saved_inspections_screen.dart';
import 'services/browser_store.dart';
import 'services/local_inspection_repository.dart';
import 'screens/wearables_test_screen.dart';

void main() {
  runApp(const ProjectVerifyApp());
}

class ProjectVerifyApp extends StatefulWidget {
  const ProjectVerifyApp({super.key});

  @override
  State<ProjectVerifyApp> createState() => _ProjectVerifyAppState();
}

class _ProjectVerifyAppState extends State<ProjectVerifyApp> {
  LocalInspectionRepository? repository;
  @override
  void initState() {
    super.initState();
    final store = createBrowserStore();
    if (store != null) repository = LocalInspectionRepository(store);
  }

  @override
  void dispose() {
    repository?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Project Verify',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.light,
      ),
      home: !kReleaseMode && const bool.fromEnvironment('WEARABLES_TEST')
          ? const WearablesTestScreen()
          : repository == null
          ? const NewInspectionScreen()
          : SavedInspectionsScreen(repository: repository!),
    );
  }
}
