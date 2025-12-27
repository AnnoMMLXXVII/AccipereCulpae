import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../data/history_fields.dart';
import '../../models/transaction_entry.dart';

class ManualPreviewScreen extends StatefulWidget {
  const ManualPreviewScreen({super.key, required this.entry});

  final TransactionEntry entry;

  @override
  State<ManualPreviewScreen> createState() => _ManualPreviewScreenState();
}

class _ManualPreviewScreenState extends State<ManualPreviewScreen> {
  bool _submitting = false;

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      // 1) Send to backend (stub for now)
      await AppServices.api.createTransaction(widget.entry.toJson());

      // 2) Update per-device history (MRU)
      await AppServices.history.upsert(
        HistoryField.description,
        widget.entry.description,
      );
      await AppServices.history.upsert(
        HistoryField.source,
        widget.entry.source,
      );
      await AppServices.history.upsert(
        HistoryField.category,
        widget.entry.category,
      );

      final bt = (widget.entry.barcodeText ?? '').trim();
      if (bt.isNotEmpty) {
        await AppServices.history.upsert(HistoryField.barcodeText, bt);
      }

      if (!mounted) return;

      // 3) Return to previous screen and show success
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Transaction saved'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              // TODO: implement undo when you have backend IDs / delete endpoint
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Submit failed: $e')));
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final e = widget.entry;

    return Scaffold(
      appBar: AppBar(title: const Text('Preview')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
          children: [
            Text(
              'Review transaction',
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),

            _Card(
              title: 'Details',
              children: [
                _Row('Date', '${e.date.month}/${e.date.day}/${e.date.year}'),
                _Row('Description', e.description),
                _Row('Quantity', '${e.quantity}'),
                _Row('Unit Price', '\$${e.unitPrice.toStringAsFixed(2)}'),
                _Row('Source', e.source),
                _Row('Category', e.category),
                if ((e.barcodeText ?? '').trim().isNotEmpty)
                  _Row('Barcode text', e.barcodeText!.trim()),
              ],
            ),

            const SizedBox(height: 12),

            // Emphasized total
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: scheme.primary.withValues(alpha: 0.12),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Total',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '\$${e.total.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.pop(context),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle),
                    label: Text(_submitting ? 'Submitting…' : 'Submit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.22),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.k, this.v);
  final String k;
  final String v;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(k, style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(v, style: TextStyle(color: scheme.onSurface)),
          ),
        ],
      ),
    );
  }
}
