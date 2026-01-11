import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  PackageInfo? _packageInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // App Logo/Icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [BoxShadow(color: scheme.shadow.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Icon(Icons.qr_code_scanner, size: 64, color: scheme.onPrimaryContainer),
                  ),

                  const SizedBox(height: 24),

                  // App Name
                  Text(
                    _packageInfo?.appName ?? 'Scanner App',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: scheme.onSurface),
                  ),

                  const SizedBox(height: 8),

                  // Version
                  Text(
                    'Version ${_packageInfo?.version ?? '1.0.0'} (${_packageInfo?.buildNumber ?? '1'})',
                    style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant, fontFamily: 'monospace'),
                  ),

                  const SizedBox(height: 40),

                  // Creator Info Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.person_outline, size: 40, color: scheme.primary),
                        const SizedBox(height: 12),
                        Text(
                          'Created by',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant, letterSpacing: 1.2),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'AnnoMMLXXVII',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: scheme.onSurface),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Description
                  Text(
                    'A powerful scanning application supporting RFID, QR codes, barcodes, and OCR text extraction.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant, height: 1.5),
                  ),

                  const SizedBox(height: 32),

                  // Features List
                  _FeatureItem(icon: Icons.qr_code_scanner, title: 'QR & Barcode Scanning', description: 'Fast and accurate code detection'),
                  const SizedBox(height: 12),
                  _FeatureItem(icon: Icons.nfc, title: 'RFID Support', description: 'Compatible with RFID scanners'),
                  const SizedBox(height: 12),
                  _FeatureItem(icon: Icons.document_scanner, title: 'OCR Text Extraction', description: 'Extract text from images'),
                  const SizedBox(height: 12),
                  _FeatureItem(icon: Icons.history, title: 'Scan History', description: 'Keep track of all your scans'),

                  const SizedBox(height: 40),

                  // Build Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        _InfoRow('Package Name', _packageInfo?.packageName ?? 'N/A'),
                        const SizedBox(height: 8),
                        _InfoRow('Version', _packageInfo?.version ?? '1.0.0'),
                        const SizedBox(height: 8),
                        _InfoRow('Build Number', _packageInfo?.buildNumber ?? '1'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({required this.icon, required this.title, required this.description});

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: scheme.primaryContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 24, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: scheme.onSurface),
                ),
                const SizedBox(height: 2),
                Text(description, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        Text(
          value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurface, fontFamily: 'monospace'),
        ),
      ],
    );
  }
}
