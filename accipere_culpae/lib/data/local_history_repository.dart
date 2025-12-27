import 'package:shared_preferences/shared_preferences.dart';
import 'history_fields.dart';
import 'history_repository.dart';

class LocalHistoryRepository implements HistoryRepository {
  LocalHistoryRepository({
    this.maxItemsPerField = 200,
    Map<HistoryField, List<String>>? seed,
  }) : _seed = seed ?? const {};

  final int maxItemsPerField;
  final Map<HistoryField, List<String>> _seed;

  final Map<HistoryField, List<String>> _cache = {};
  bool _warmed = false;

  @override
  Future<void> warmup() async {
    if (_warmed) return;

    // Initialize cache with seed first (MRU order assumed)
    for (final f in HistoryField.values) {
      _cache[f] = List<String>.from(_seed[f] ?? const []);
    }

    final prefs = await SharedPreferences.getInstance();

    for (final f in HistoryField.values) {
      final saved = prefs.getStringList(f.key);
      if (saved != null && saved.isNotEmpty) {
        _cache[f] = _dedupeMRU(saved);
      } else {
        // keep seeded values (already loaded)
        _cache[f] = _dedupeMRU(_cache[f] ?? const []);
      }
    }

    _warmed = true;
  }

  @override
  List<String> suggest(HistoryField field, String query, {int limit = 8}) {
    final q = query.trim().toLowerCase();
    final list = _cache[field] ?? const [];

    if (q.isEmpty) {
      return list.take(limit).toList();
    }

    final filtered = list.where((v) => v.toLowerCase().contains(q));
    return filtered.take(limit).toList();
  }

  @override
  Future<void> upsert(HistoryField field, String value) async {
    final v = value.trim();
    if (v.isEmpty) return;

    final list = List<String>.from(_cache[field] ?? const []);

    // Remove existing (case-insensitive)
    list.removeWhere((x) => x.toLowerCase() == v.toLowerCase());
    // Add to front (MRU)
    list.insert(0, v);

    // Truncate
    if (list.length > maxItemsPerField) {
      list.removeRange(maxItemsPerField, list.length);
    }

    _cache[field] = list;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(field.key, list);
  }

  List<String> _dedupeMRU(List<String> items) {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in items) {
      final v = raw.trim();
      if (v.isEmpty) continue;
      final k = v.toLowerCase();
      if (seen.add(k)) out.add(v);
    }
    return out;
  }
}
