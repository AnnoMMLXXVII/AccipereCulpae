import 'entry_prefs.dart';

abstract class EntryPrefsRepository {
  Future<void> warmup();

  bool getBool(EntryPrefKey key, {required bool fallback});

  Future<void> setBool(EntryPrefKey key, bool value);
}
