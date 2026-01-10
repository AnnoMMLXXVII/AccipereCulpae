import 'package:anno_accipere_culpae/com/anno/domini/screens/about/about_screen.dart';
import 'package:anno_accipere_culpae/com/anno/domini/screens/history/scan_history.dart';
import 'package:flutter/material.dart';

import 'screens/landing/dark_action_landing_page.dart';
import 'screens/manual/manual_entry_screen.dart';
import 'screens/scan/scan_capture_screen.dart';
import 'theme/dark_theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildDarkTheme(),
      home: const DarkActionLandingPage(),
      routes: {
        '/about': (_) => const AboutScreen(),
        '/scan': (_) => const ScanCaptureScreen(),
        '/manual': (_) => const ManualEntryScreen(),
        '/scan_history': (_) => const ScanHistoryScreen()},
    );
  }
}
