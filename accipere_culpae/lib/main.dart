import 'package:flutter/material.dart';

import 'com/anno/domini/app.dart';
import 'com/anno/domini/services/app_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppServices.history.warmup();
  await AppServices.entryPrefs.warmup();
  runApp(const App());
}
