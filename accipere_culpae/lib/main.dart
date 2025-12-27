import 'package:flutter/material.dart';

import 'app.dart';
import 'app_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppServices.history.warmup();
  await AppServices.entryPrefs.warmup();
  runApp(const App());
}
