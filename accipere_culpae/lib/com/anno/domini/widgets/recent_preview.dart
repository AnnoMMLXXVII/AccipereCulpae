import 'package:flutter/material.dart';

class RecentItem {
  const RecentItem(this.vendor, this.source, this.amount);

  final String vendor;
  final String source;
  final double amount;
}

class RecentPreview extends StatelessWidget {
  const RecentPreview({
    super.key,
    required this.items,
    required this.onViewAll,
    required this.onTapItem,
  });

  final List<RecentItem> items;
  final VoidCallback onViewAll;
  final void Function(RecentItem item) onTapItem;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Recent', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton(
                  onPressed: onViewAll,
                  child: const Text('View all'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...items.map(
              (it) => InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onTapItem(it), // “Add again” hook
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${it.vendor} · ${it.source}',
                          style: TextStyle(color: scheme.onSurface),
                        ),
                      ),
                      Text(
                        '\$${it.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.add_circle_outline, color: scheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
