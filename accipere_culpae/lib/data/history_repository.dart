import 'history_fields.dart';

abstract class HistoryRepository {
  /// Load any persisted state into memory (safe to call multiple times).
  Future<void> warmup();

  /// Get suggestions for a field based on a query.
  /// Returned list should be ordered (usually MRU first).
  List<String> suggest(HistoryField field, String query, {int limit = 8});

  /// Add value to history for this field (dedupe, trim, enforce max size).
  Future<void> upsert(HistoryField field, String value);
}
