import 'package:shared_preferences/shared_preferences.dart';
import 'entry_prefs.dart';
import 'entry_prefs_repository.dart';

class LocalEntryPrefsRepository implements EntryPrefsRepository {
  bool _warmed = false;
  final Map<EntryPrefKey, bool> _cache = {};

  @override
  Future<void> warmup() async {
    if (_warmed) return;

    final prefs = await SharedPreferences.getInstance();

    for (final k in EntryPrefKey.values) {
      final v = prefs.getBool(k.key);
      if (v != null) _cache[k] = v;
    }

    _warmed = true;
  }

  @override
  bool getBool(EntryPrefKey key, {required bool fallback}) {
    return _cache[key] ?? fallback;
  }

  @override
  Future<void> setBool(EntryPrefKey key, bool value) async {
    _cache[key] = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key.key, value);
  }
}
