import 'package:flutter/material.dart';
import 'screens/new_inspection_screen.dart';

void main() {
  runApp(const ProjectVerifyApp());
}

class ProjectVerifyApp extends StatelessWidget {
  const ProjectVerifyApp({super.key});

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
      home: const NewInspectionScreen(),
    );
  }
}
