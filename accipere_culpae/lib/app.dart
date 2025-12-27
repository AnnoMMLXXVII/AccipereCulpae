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
        '/scan': (_) => const ScanCaptureScreen(),
        '/manual': (_) => const ManualEntryScreen(),
      },
    );
  }
}
