import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanCaptureScreen extends StatefulWidget {
  const ScanCaptureScreen({super.key});

  @override
  State<ScanCaptureScreen> createState() => _ScanCaptureScreenState();
}

class _ScanCaptureScreenState extends State<ScanCaptureScreen> {
  final MobileScannerController _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  final TextEditingController _extractedCtrl = TextEditingController();
  final FocusNode _fieldFocus = FocusNode();

  bool _isBusy = false;
  bool _scannerPaused = false; // pause after first successful scan
  String _mode = 'Barcode/QR'; // or 'Photo (OCR)'

  // Debounce duplicates
  DateTime? _lastScanAt;
  String? _lastValue;

  @override
  void initState() {
    super.initState();
    _fieldFocus.addListener(() {
      // triggers rebuild so we can show subtle “editing” states if desired
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _scanner.dispose();
    _extractedCtrl.dispose();
    _fieldFocus.dispose();
    super.dispose();
  }

  bool get _userIsEditing => _fieldFocus.hasFocus;

  bool _acceptScan(String v) {
    final now = DateTime.now();
    if (_lastValue == v && _lastScanAt != null) {
      if (now.difference(_lastScanAt!).inMilliseconds < 900) return false;
    }
    _lastValue = v;
    _lastScanAt = now;
    return true;
  }

  void _setExtracted(String value) {
    final trimmed = value.trim();
    _extractedCtrl.text = trimmed;
    _extractedCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: trimmed.length),
    );
    setState(() {});
  }

  Future<void> _pauseScanner() async {
    if (_scannerPaused) return;
    _scannerPaused = true;
    try {
      await _scanner.stop();
    } catch (_) {
      // ignore
    }
    if (mounted) setState(() {});
  }

  Future<void> _resumeScanner({bool clearField = false}) async {
    _scannerPaused = false;
    if (clearField) _extractedCtrl.clear();
    try {
      await _scanner.start();
    } catch (_) {
      // ignore
    }
    if (mounted) setState(() {});
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------- OCR (mobile only via ML Kit) ----------
  Future<void> _pickPhotoAndRunOcr({required ImageSource source}) async {
    if (_isBusy) return;

    setState(() => _isBusy = true);
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: source);

      if (file == null) return;

      if (kIsWeb) {
        // ML Kit OCR not supported on web in this package
        _showSnack(
          'OCR on Web isn’t supported yet. Use Barcode/QR mode or add server OCR.',
        );
        return;
      }

      final inputImage = InputImage.fromFilePath(file.path);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

      final RecognizedText result = await recognizer.processImage(inputImage);
      await recognizer.close();

      final text = result.text.trim();

      if (text.isEmpty) {
        _showSnack(
          'No text detected. Try better lighting and a clearer photo.',
        );
      } else {
        _setExtracted(text);
        _showSnack('Text extracted. Review and submit.');
      }
    } catch (e) {
      _showSnack('OCR failed: $e');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // ---------- Barcode/QR detection ----------
  Future<void> _handleDetectedValue(String value) async {
    final v = value.trim();
    if (v.isEmpty) return;

    // If user is editing, do not overwrite.
    if (_userIsEditing) {
      _showSnack(
        'Detected a code, but you’re editing. Tap Rescan to try again.',
      );
      await _pauseScanner();
      return;
    }

    if (!_acceptScan(v)) return;

    _setExtracted(v);
    _showSnack('Scanned. Review and submit.');
    await _pauseScanner();
  }

  Future<void> _showMultiSelectSheet(List<String> values) async {
    final scheme = Theme.of(context).colorScheme;

    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Multiple codes found',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...values.map((v) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      v,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.onSurface),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: scheme.onSurfaceVariant,
                    ),
                    onTap: () => Navigator.pop(context, v),
                  );
                }),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );

    if (chosen != null) {
      await _handleDetectedValue(chosen);
    } else {
      // User dismissed chooser; keep scanner paused to avoid chaos, user can rescan.
      _showSnack('No selection made. Tap Rescan to continue.');
    }
  }

  void _onBarcodeDetected(BarcodeCapture capture) async {
    if (_mode != 'Barcode/QR') return;
    if (_isBusy) return;
    if (_scannerPaused) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final values = <String>[];
    for (final b in barcodes) {
      final raw = b.rawValue?.trim();
      if (raw != null && raw.isNotEmpty) values.add(raw);
    }

    if (values.isEmpty) return;

    // Pause immediately so we don't keep firing while showing chooser.
    await _pauseScanner();

    // If multiple, ask user which one
    final unique = values.toSet().toList();
    if (unique.length > 1) {
      await _showMultiSelectSheet(unique);
      return;
    }

    await _handleDetectedValue(unique.first);
  }

  void _submit() {
    final value = _extractedCtrl.text.trim();
    if (value.isEmpty) {
      _showSnack('Nothing to submit yet.');
      return;
    }

    // Return the submitted text back to landing page.
    Navigator.pop(context, value);
  }

  void _clear() {
    _extractedCtrl.clear();
    setState(() {});
  }

  Future<bool> _confirmDiscardIfNeeded() async {
    if (_extractedCtrl.text.trim().isEmpty) return true;

    final scheme = Theme.of(context).colorScheme;

    final discard = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: scheme.surfaceContainerHighest,
          title: const Text('Discard scanned text?'),
          content: const Text(
            'You have extracted text/value. Do you want to discard it and go back?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        );
      },
    );

    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final showWebOcrBanner = kIsWeb && _mode == 'Photo (OCR)';

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final ok = await _confirmDiscardIfNeeded();
        if (ok && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Scan'),
          actions: [
            IconButton(
              tooltip: 'Torch',
              onPressed: _isBusy || _mode != 'Barcode/QR'
                  ? null
                  : () => _scanner.toggleTorch(),
              icon: const Icon(Icons.flash_on),
            ),
            IconButton(
              tooltip: 'Switch camera',
              onPressed: _isBusy || _mode != 'Barcode/QR'
                  ? null
                  : () => _scanner.switchCamera(),
              icon: const Icon(Icons.cameraswitch),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Mode selector
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: _ModeChip(
                        label: 'Barcode/QR',
                        selected: _mode == 'Barcode/QR',
                        onTap: _isBusy
                            ? null
                            : () async {
                                setState(() => _mode = 'Barcode/QR');
                                // Resume camera scanning if switching back
                                await _resumeScanner();
                              },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ModeChip(
                        label: 'Photo (OCR)',
                        selected: _mode == 'Photo (OCR)',
                        onTap: _isBusy
                            ? null
                            : () async {
                                setState(() => _mode = 'Photo (OCR)');
                                // Stop scanner to avoid running camera unnecessarily in OCR mode
                                await _pauseScanner();
                              },
                      ),
                    ),
                  ],
                ),
              ),

              if (showWebOcrBanner)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: _InlineBanner(
                    icon: Icons.info_outline,
                    title: 'OCR not available on Web yet',
                    body:
                        'Use Barcode/QR mode, or route photo uploads to a server OCR service.',
                  ),
                ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.35),
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Stack(
                        children: [
                          if (_mode == 'Barcode/QR')
                            MobileScanner(
                              controller: _scanner,
                              onDetect: _onBarcodeDetected,
                              errorBuilder: (context, error, child) {
                                return _ScannerErrorSurface(
                                  error: error,
                                  onManual: () {
                                    _mode = 'Photo (OCR)';
                                    setState(() {});
                                    _pauseScanner();
                                  },
                                  onRetry: () {
                                    _resumeScanner();
                                  },
                                );
                              },
                            )
                          else
                            Container(
                              color: scheme.surfaceContainerHighest.withValues(
                                alpha: 0.35,
                              ),
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.document_scanner_outlined,
                                        size: 48,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Capture a photo to extract text',
                                        style: TextStyle(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        alignment: WrapAlignment.center,
                                        children: [
                                          FilledButton.icon(
                                            onPressed: _isBusy || kIsWeb
                                                ? null
                                                : () => _pickPhotoAndRunOcr(
                                                    source: ImageSource.camera,
                                                  ),
                                            icon: const Icon(Icons.camera_alt),
                                            label: const Text('Camera'),
                                          ),
                                          OutlinedButton.icon(
                                            onPressed: _isBusy || kIsWeb
                                                ? null
                                                : () => _pickPhotoAndRunOcr(
                                                    source: ImageSource.gallery,
                                                  ),
                                            icon: const Icon(
                                              Icons.photo_library_outlined,
                                            ),
                                            label: const Text('Gallery'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                          // Scan frame overlay (subtle)
                          IgnorePointer(
                            child: Center(
                              child: Container(
                                width: 260,
                                height: 160,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: scheme.primary.withValues(
                                      alpha: 0.45,
                                    ),
                                    width: 1.3,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Paused overlay
                          if (_mode == 'Barcode/QR' &&
                              _scannerPaused &&
                              !_isBusy)
                            Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: _Pill(
                                  icon: Icons.pause_circle_outline,
                                  text: _userIsEditing
                                      ? 'Paused (editing)'
                                      : 'Paused (review)',
                                ),
                              ),
                            ),

                          if (_isBusy)
                            Container(
                              color: Colors.black.withValues(alpha: 0.35),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Review + submit zone
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Extracted value',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _extractedCtrl,
                      focusNode: _fieldFocus,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: _mode == 'Barcode/QR'
                            ? 'Scan a barcode/QR to fill this'
                            : (kIsWeb
                                  ? 'OCR not available on web (type here)'
                                  : 'Take a photo to extract text here'),
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.35,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: scheme.outlineVariant.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: scheme.outlineVariant.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: scheme.primary.withValues(alpha: 0.55),
                            width: 1.3,
                          ),
                        ),
                        suffixIcon: IconButton(
                          tooltip: 'Clear',
                          onPressed: _extractedCtrl.text.isEmpty
                              ? null
                              : _clear,
                          icon: const Icon(Icons.clear),
                        ),
                      ),
                      onChanged: (_) {
                        // If user types, keep scanner paused to avoid overwrites.
                        if (_mode == 'Barcode/QR' && !_scannerPaused) {
                          _pauseScanner();
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isBusy
                                ? null
                                : () async {
                                    if (_mode == 'Barcode/QR') {
                                      // Explicit rescan: resume and optionally clear field
                                      await _resumeScanner(clearField: false);
                                      _showSnack('Ready. Scan again.');
                                    } else {
                                      if (kIsWeb) {
                                        _showSnack(
                                          'OCR on Web isn’t supported yet.',
                                        );
                                      } else {
                                        await _pickPhotoAndRunOcr(
                                          source: ImageSource.camera,
                                        );
                                      }
                                    }
                                  },
                            icon: const Icon(Icons.refresh),
                            label: Text(
                              _mode == 'Barcode/QR' ? 'Rescan' : 'Retake',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _isBusy ? null : _submit,
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Submit'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected
              ? scheme.primary.withValues(alpha: 0.16)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.25),
          border: Border.all(
            color: selected
                ? scheme.primary.withValues(alpha: 0.55)
                : scheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineBanner extends StatelessWidget {
  const _InlineBanner({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.28),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(body, style: TextStyle(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerErrorSurface extends StatelessWidget {
  const _ScannerErrorSurface({
    required this.error,
    required this.onManual,
    required this.onRetry,
  });

  final MobileScannerException error;
  final VoidCallback onManual;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    String title = 'Camera unavailable';
    String body =
        'We couldn’t access the camera. Try again, or use another input method.';

    // Common error codes:
    // - permissionDenied
    // - controllerUninitialized
    // - unknown
    // - unsupported
    final code = error.errorCode;

    if (code == MobileScannerErrorCode.permissionDenied) {
      title = 'Camera permission denied';
      body =
          'Enable camera permission in settings, or use Photo/OCR or manual entry.';
    } else if (code == MobileScannerErrorCode.unsupported) {
      title = 'Camera not supported';
      body = 'This device/browser does not support camera scanning.';
    }

    return Container(
      color: scheme.surface,
      padding: const EdgeInsets.all(18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.30),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.videocam_off_outlined,
                  size: 44,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => AppSettings.openAppSettings(),
                        icon: const Icon(Icons.settings),
                        label: const Text('Open settings'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Error: ${error.errorCode.name}',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
