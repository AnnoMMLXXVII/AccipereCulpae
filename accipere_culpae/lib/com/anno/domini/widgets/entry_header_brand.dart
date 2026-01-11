import 'package:flutter/material.dart';

class EntryHeaderBrand extends StatelessWidget {
  const EntryHeaderBrand({super.key});

  @override
  Widget build(BuildContext context) {
    // Clamp width so it looks good on web AND phones
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Image.asset(
          'assets/branding/wordmark_dark.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
