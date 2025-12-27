import 'package:accipere_culpae/widgets/entry_header_brand.dart';
import 'package:flutter/material.dart';

import '../../widgets/action_card.dart';
import '../../widgets/bottom_hint_bar.dart';
import '../../widgets/header.dart';
import '../../widgets/mini_action.dart';
import '../../widgets/mini_row.dart';
import '../../widgets/recent_preview.dart';

class DarkActionLandingPage extends StatelessWidget {
  const DarkActionLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    // Mobile-first: single column
    // Tablet/Desktop: centered max width
    final maxContentWidth = width < 700 ? double.infinity : 640.0;

    return Scaffold(
      appBar: AppBar(
        title: const EntryHeaderBrand(),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () {
              // TODO: Navigator.pushNamed(context, '/settings');
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
            children: [
              const Header(
                title: 'Create an expense',
                subtitle: 'Fast capture with scan, type, or reuse.',
              ),
              const SizedBox(height: 14),

              ActionCard(
                icon: Icons.qr_code_scanner,
                title: 'Scan barcode',
                subtitle: 'Best for quick capture (UPC/EAN/QR).',
                emphasis: true,
                onTap: () async {
                  final result = await Navigator.pushNamed(context, '/scan');
                  if (result is String && result.trim().isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Submitted: ${result.trim()}')),
                    );
                  }
                },
              ),
              const SizedBox(height: 10),

              ActionCard(
                icon: Icons.edit_note,
                title: 'Manual entry',
                subtitle: 'Type vendor, amount, category.',
                onTap: () {
                  Navigator.pushNamed(context, '/manual');
                },
              ),
              const SizedBox(height: 10),

              ActionCard(
                icon: Icons.history,
                title: 'Pick from history',
                subtitle: 'Reuse a past expense in one tap.',
                onTap: () {
                  // TODO: Navigator.pushNamed(context, '/history');
                },
              ),
              const SizedBox(height: 10),

              ActionCard(
                icon: Icons.search,
                title: 'Search expenses',
                subtitle: 'Find and re-add/edit quickly.',
                onTap: () {
                  // TODO: Navigator.pushNamed(context, '/search');
                },
              ),

              const SizedBox(height: 18),

              MiniRow(
                children: [
                  MiniAction(
                    icon: Icons.receipt_long,
                    label: 'Receipts',
                    onTap: () {
                      // TODO: Navigator.pushNamed(context, '/receipts');
                    },
                  ),
                  MiniAction(
                    icon: Icons.category_outlined,
                    label: 'Categories',
                    onTap: () {
                      // TODO: Navigator.pushNamed(context, '/categories');
                    },
                  ),
                  MiniAction(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Sources',
                    onTap: () {
                      // TODO: Navigator.pushNamed(context, '/sources');
                    },
                  ),
                ],
              ),

              const SizedBox(height: 18),

              RecentPreview(
                onViewAll: () {
                  // TODO: Navigator.pushNamed(context, '/history');
                },
                items: const [
                  RecentItem('Gas', 'Chase', 42.18),
                  RecentItem('Grocery', 'Visa', 88.02),
                  RecentItem('Coffee', 'Cash', 4.50),
                ],
                onTapItem: (item) {
                  // TODO: “Add again” flow
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomHintBar(
        text: 'Tip: Keep this screen as your home. Scan stays one tap away.',
      ),
    );
  }
}
