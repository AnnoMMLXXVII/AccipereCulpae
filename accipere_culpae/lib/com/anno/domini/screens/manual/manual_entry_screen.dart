import 'package:flutter/material.dart';

import '../../data/entry_prefs.dart';
import '../../data/history_fields.dart';
import '../../models/transaction_entry.dart';
import '../../services/app_services.dart';
import '../../widgets/history_autocomplete_field.dart';
import 'manual_preview_screen.dart';

class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  DateTime _date = DateTime.now();
  bool _showBarcode = false;

  final _descCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _unitCtrl = TextEditingController();
  final _sourceCtrl = TextEditingController();
  final _catCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();

  // Quick-add behavior toggles (persisted)
  late bool _keepDate;
  late bool _keepSource;
  late bool _keepCategory;
  late bool _keepQuantity;

  late bool _keepDescription;
  late bool _keepUnitPrice;
  late bool _keepBarcode;

  late bool _showQuickAddSettings;

  // Save last successful entry for "Copy last"
  TransactionEntry? _lastSavedEntry;

  bool _dirty = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    _qtyCtrl.dispose();
    _unitCtrl.dispose();
    _sourceCtrl.dispose();
    _catCtrl.dispose();
    _barcodeCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    // Defaults: good POS behavior
    _keepDate = AppServices.entryPrefs.getBool(EntryPrefKey.keepDate, fallback: true);
    _keepSource = AppServices.entryPrefs.getBool(EntryPrefKey.keepSource, fallback: true);
    _keepCategory = AppServices.entryPrefs.getBool(EntryPrefKey.keepCategory, fallback: true);
    _keepQuantity = AppServices.entryPrefs.getBool(EntryPrefKey.keepQuantity, fallback: true);

    _keepDescription = AppServices.entryPrefs.getBool(EntryPrefKey.keepDescription, fallback: false);
    _keepUnitPrice = AppServices.entryPrefs.getBool(EntryPrefKey.keepUnitPrice, fallback: false);
    _keepBarcode = AppServices.entryPrefs.getBool(EntryPrefKey.keepBarcodeText, fallback: false);

    _showQuickAddSettings = AppServices.entryPrefs.getBool(EntryPrefKey.quickAddExpanded, fallback: false);
  }

  Future<void> _setPref(EntryPrefKey key, bool value) async {
    // Update UI immediately
    setState(() {
      switch (key) {
        case EntryPrefKey.keepDate:
          _keepDate = value;
          break;
        case EntryPrefKey.keepSource:
          _keepSource = value;
          break;
        case EntryPrefKey.keepCategory:
          _keepCategory = value;
          break;
        case EntryPrefKey.keepQuantity:
          _keepQuantity = value;
          break;
        case EntryPrefKey.keepDescription:
          _keepDescription = value;
          break;
        case EntryPrefKey.keepUnitPrice:
          _keepUnitPrice = value;
          break;
        case EntryPrefKey.keepBarcodeText:
          _keepBarcode = value;
          break;
        case EntryPrefKey.quickAddExpanded:
          _showQuickAddSettings = value;
          break;
      }
    });

    // Persist (ignore failures quietly for now)
    await AppServices.entryPrefs.setBool(key, value);
  }

  int? _parseQty(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    final v = int.tryParse(t);
    if (v == null) return null;
    return v;
  }

  double? _parseMoney(String s) {
    // Accept: "$4.99", "4.99", "4,99"
    final t = s.trim().replaceAll('\$', '').replaceAll(',', '.');
    if (t.isEmpty) return null;
    final v = double.tryParse(t);
    if (v == null) return null;
    return v;
  }

  double _computeTotal() {
    final qty = _parseQty(_qtyCtrl.text) ?? 0;
    final unit = _parseMoney(_unitCtrl.text) ?? 0.0;
    return qty * unit;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked != null) {
      setState(() {
        _date = picked;
        _dirty = true;
      });
    }
  }

  Future<bool> _confirmDiscardIfNeeded() async {
    if (!_dirty) return true;
    if (_descCtrl.text.trim().isEmpty &&
        _unitCtrl.text.trim().isEmpty &&
        _sourceCtrl.text.trim().isEmpty &&
        _catCtrl.text.trim().isEmpty &&
        (_barcodeCtrl.text.trim().isEmpty)) {
      return true;
    }

    final scheme = Theme.of(context).colorScheme;
    final discard = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: scheme.surfaceContainerHighest,
        title: const Text('Discard entry?'),
        content: const Text('You have unsaved changes. Do you want to discard them?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep editing')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Discard')),
        ],
      ),
    );
    return discard ?? false;
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _goPreview() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final qty = _parseQty(_qtyCtrl.text)!;
    final unit = _parseMoney(_unitCtrl.text)!;

    final entry = TransactionEntry(
      date: _date,
      description: _descCtrl.text.trim(),
      quantity: qty,
      unitPrice: unit,
      source: _sourceCtrl.text.trim(),
      category: _catCtrl.text.trim(),
      barcodeText: _showBarcode ? _barcodeCtrl.text.trim() : null,
    );

    final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => ManualPreviewScreen(entry: entry)));

    if (!mounted) return;

    if (saved == true) {
      _resetFormAfterSave(saved: entry);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved. Ready for next entry.')));
    }
  }

  void _resetFormAfterSave({TransactionEntry? saved}) {
    setState(() {
      // Store last saved entry for optional "Copy last" action
      if (saved != null) _lastSavedEntry = saved;

      if (!_keepDate) _date = DateTime.now();

      if (!_keepDescription) _descCtrl.clear();
      if (!_keepQuantity) {
        _qtyCtrl.text = '1';
      } else {
        // If empty (edge case), restore to 1
        if (_qtyCtrl.text.trim().isEmpty) _qtyCtrl.text = '1';
      }
      if (!_keepUnitPrice) _unitCtrl.clear();

      if (!_keepSource) _sourceCtrl.clear();
      if (!_keepCategory) _catCtrl.clear();

      // Barcode section behavior
      if (_keepBarcode) {
        // keep section open if it had content or user wants it kept
        _showBarcode = _showBarcode || _barcodeCtrl.text.trim().isNotEmpty;
      } else {
        _showBarcode = false;
        _barcodeCtrl.clear();
      }

      _dirty = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = _computeTotal();

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final ok = await _confirmDiscardIfNeeded();
        if (ok && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manual entry'),
          actions: [
            IconButton(
              tooltip: 'Copy last entry',
              onPressed: _lastSavedEntry == null
                  ? null
                  : () {
                      final e = _lastSavedEntry!;
                      setState(() {
                        _date = e.date;
                        _descCtrl.text = e.description;
                        _qtyCtrl.text = e.quantity.toString();
                        _unitCtrl.text = e.unitPrice.toStringAsFixed(2);
                        _sourceCtrl.text = e.source;
                        _catCtrl.text = e.category;

                        final bt = (e.barcodeText ?? '').trim();
                        if (bt.isNotEmpty) {
                          _showBarcode = true;
                          _barcodeCtrl.text = bt;
                        } else {
                          _showBarcode = false;
                          _barcodeCtrl.clear();
                        }

                        _dirty = true;
                      });

                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Last entry copied')));
                    },
              icon: const Icon(Icons.copy),
            ),
          ],
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            onChanged: _markDirty,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
              children: [
                // Date picker row
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                      border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${_date.month}/${_date.day}/${_date.year}',
                            style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w800),
                          ),
                        ),
                        Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Description (history + free text)
                HistoryAutocompleteField(
                  repo: AppServices.history,
                  field: HistoryField.description,
                  label: 'Description',
                  hintText: 'Merchant / note (e.g., Grocery Store)',
                  controller: _descCtrl,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'Description is required';
                    if (t.length < 2) return 'Too short';
                    if (t.length > 80) return 'Keep under 80 characters';
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _qtyCtrl,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Quantity', hintText: '1'),
                        validator: (v) {
                          final qty = _parseQty(v ?? '');
                          if (qty == null) return 'Enter a whole number';
                          if (qty <= 0) return 'Must be ≥ 1';
                          if (qty > 9999) return 'Too large';
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _unitCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Unit Price', hintText: '\$4.99'),
                        validator: (v) {
                          final price = _parseMoney(v ?? '');
                          if (price == null) return 'Enter a price';
                          if (price < 0) return 'Must be ≥ 0';
                          if (price > 100000) return 'Too large';
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Source (history + free text)
                HistoryAutocompleteField(
                  repo: AppServices.history,
                  field: HistoryField.source,
                  label: 'Source',
                  hintText: 'Checking / Credit Card / Cash…',
                  controller: _sourceCtrl,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'Source is required';
                    if (t.length > 40) return 'Keep under 40 characters';
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                // Category (history + free text)
                HistoryAutocompleteField(
                  repo: AppServices.history,
                  field: HistoryField.category,
                  label: 'Category',
                  hintText: 'Grocery / Gas / Utilities…',
                  controller: _catCtrl,
                  textInputAction: TextInputAction.done,
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'Category is required';
                    if (t.length > 40) return 'Keep under 40 characters';
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                // Optional barcode/scanned text (collapsible)
                InkWell(
                  onTap: () => setState(() => _showBarcode = !_showBarcode),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.18),
                      border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.28)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.qr_code_2, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 10),
                        const Expanded(child: Text('Optional: barcode / scanned text')),
                        Icon(_showBarcode ? Icons.expand_less : Icons.expand_more, color: scheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
                if (_showBarcode) ...[
                  const SizedBox(height: 10),
                  HistoryAutocompleteField(
                    repo: AppServices.history,
                    field: HistoryField.barcodeText,
                    label: 'Barcode text (optional)',
                    hintText: 'Paste or type scanned value',
                    controller: _barcodeCtrl,
                    textInputAction: TextInputAction.done,
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return null;
                      if (t.length > 512) return 'Keep under 512 characters';
                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 12),

                InkWell(
                  onTap: () => _setPref(EntryPrefKey.quickAddExpanded, !_showQuickAddSettings),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.18),
                      border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.28)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.tune, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 10),
                        const Expanded(child: Text('Quick add settings')),
                        Icon(_showQuickAddSettings ? Icons.expand_less : Icons.expand_more, color: scheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),

                if (_showQuickAddSettings) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.22),
                      border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.28)),
                    ),
                    child: Column(
                      children: [
                        _ToggleRow(label: 'Keep date', value: _keepDate, onChanged: (v) => _setPref(EntryPrefKey.keepDate, v)),
                        _ToggleRow(label: 'Keep source', value: _keepSource, onChanged: (v) => _setPref(EntryPrefKey.keepSource, v)),
                        _ToggleRow(label: 'Keep category', value: _keepCategory, onChanged: (v) => _setPref(EntryPrefKey.keepCategory, v)),
                        _ToggleRow(label: 'Keep quantity', value: _keepQuantity, onChanged: (v) => _setPref(EntryPrefKey.keepQuantity, v)),
                        const Divider(height: 18),
                        _ToggleRow(label: 'Keep description', value: _keepDescription, onChanged: (v) => _setPref(EntryPrefKey.keepDescription, v)),
                        _ToggleRow(label: 'Keep unit price', value: _keepUnitPrice, onChanged: (v) => _setPref(EntryPrefKey.keepUnitPrice, v)),
                        _ToggleRow(label: 'Keep barcode text', value: _keepBarcode, onChanged: (v) => _setPref(EntryPrefKey.keepBarcodeText, v)),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                // Total (computed)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.22),
                    border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.28)),
                  ),
                  child: Row(
                    children: [
                      Text('Total', style: TextStyle(color: scheme.onSurfaceVariant)),
                      const Spacer(),
                      Text(
                        '\$${total.toStringAsFixed(2)}',
                        style: TextStyle(color: scheme.onSurface, fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                FilledButton.icon(onPressed: _goPreview, icon: const Icon(Icons.visibility), label: const Text('Review transaction')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(label), value: value, onChanged: onChanged);
  }
}
