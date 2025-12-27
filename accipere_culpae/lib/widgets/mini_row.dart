import 'package:flutter/material.dart';

class MiniRow extends StatelessWidget {
  const MiniRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: children
          .map(
            (w) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: w,
              ),
            ),
          )
          .toList(),
    );
  }
}
