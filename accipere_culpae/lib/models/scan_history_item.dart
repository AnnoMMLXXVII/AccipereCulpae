import 'package:intl/intl.dart';

class ScanHistoryItem {
  final String barcode;
  final DateTime timestamp;

  ScanHistoryItem({required this.barcode, required this.timestamp});

  factory ScanHistoryItem.fromString(String entry) {
    final parts = entry.split('|');
    if (parts.length == 2) {
      final timestamp = DateTime.fromMicrosecondsSinceEpoch(int.parse(parts[0]));
      return ScanHistoryItem(barcode: parts[1], timestamp: timestamp);
    }
    // Fallback for legacy entries without timestamp
    return ScanHistoryItem(barcode: entry, timestamp: DateTime.now());
  }

  String get formattedTimestamp {
    return DateFormat('MM-dd-yyyy HH:mm:ss.SSS').format(timestamp);
  }
}
