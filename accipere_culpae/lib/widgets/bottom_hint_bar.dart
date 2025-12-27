import 'package:flutter/material.dart';

class BottomHintBar extends StatelessWidget {
  const BottomHintBar({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.22),
          border: Border(
            top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.25)),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(color: scheme.onSurfaceVariant),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
