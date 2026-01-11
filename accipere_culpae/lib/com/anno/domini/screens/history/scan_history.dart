import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/scan_history_item.dart';

class ScanHistoryScreen extends StatefulWidget {
  const ScanHistoryScreen({super.key});

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  List<ScanHistoryItem> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('scanned_values') ?? [];

    setState(() {
      _history = history.map((e) => ScanHistoryItem.fromString(e)).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Sort by timestamp descending
      _isLoading = false;
    });
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear scan history?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('scanned_values');
      setState(() => _history.clear());
    }
  }

  Future<void> _deleteItem(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final updatedHistory = List<ScanHistoryItem>.from(_history);
    updatedHistory.removeAt(index);

    await prefs.setStringList(
      'scanned_values',
      updatedHistory.reversed.map((item) => '${item.timestamp.millisecondsSinceEpoch}|${item.barcode}').toList(),
    );

    setState(() => _history = updatedHistory);
  }

  void _copyToClipboard(String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan History'),
        actions: [if (_history.isNotEmpty) IconButton(tooltip: 'Clear all', onPressed: _clearHistory, icon: const Icon(Icons.delete_sweep))],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text('No scan history yet', style: TextStyle(fontSize: 18, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Text('Scanned barcodes will appear here', style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant.withValues(alpha: 0.7))),
                ],
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 40,
                  dataRowMinHeight: 32,
                  dataRowMaxHeight: 48,
                  columnSpacing: 24,
                  headingRowColor: WidgetStateProperty.all(scheme.surfaceContainerHighest.withValues(alpha: 0.3)),
                  border: TableBorder.all(color: scheme.outlineVariant.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(8)),
                  columns: [
                    DataColumn(
                      label: Text(
                        'Barcode',
                        style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Timestamp',
                        style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Actions',
                        style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface),
                      ),
                    ),
                  ],
                  rows: _history.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;

                    return DataRow(
                      cells: [
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Text(
                                item.barcode,
                                style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            item.formattedTimestamp,
                            style: TextStyle(color: scheme.onSurfaceVariant, fontFamily: 'monospace', fontSize: 12),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Copy',
                                onPressed: () => _copyToClipboard(item.barcode),
                                icon: const Icon(Icons.copy, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Delete',
                                onPressed: () => _deleteItem(index),
                                icon: const Icon(Icons.delete_outline, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
    );
  }
}
