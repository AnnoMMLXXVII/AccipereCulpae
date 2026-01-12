import 'dart:convert';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/product_entry.dart';
import '../../services/barcode_cache.dart';
import '../../shared/constants.dart';

class ScanCaptureScreen extends StatefulWidget {
  const ScanCaptureScreen({super.key});

  @override
  State<ScanCaptureScreen> createState() => _ScanCaptureScreenState();
}

class _ScanCaptureScreenState extends State<ScanCaptureScreen> {
  final logger = Logger(
    printer: PrettyPrinter(methodCount: 0, errorMethodCount: 5, lineLength: 120, colors: true, printEmojis: true, printTime: true),
    level: kReleaseMode ? Level.warning : Level.verbose,
  );

  final MobileScannerController _scanner = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates, facing: CameraFacing.back);

  final List<String> _scannedValues = [];
  final Set<String> _scannedSet = {};
  final ScrollController _scanListScroll = ScrollController();

  final TextEditingController _extractedCtrl = TextEditingController();
  final TextEditingController _scannerCtrl = TextEditingController();

  final FocusNode _fieldFocus = FocusNode();
  bool _isOrientationLocked = false;
  bool _isBusy = false;
  bool _scannerPaused = false; // pause after first successful scan
  bool _cameraScanning = false;
  bool _cameraInitialized = false;
  String _mode = SCAN_RFID_MODE; // or SCAN_OCR_MODE

  // Debounce duplicates
  DateTime? _lastScanAt;
  String? _lastValue;

  @override
  void initState() {
    super.initState();

    // Set all orientations by default
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _fieldFocus.addListener(() {
      // triggers rebuild so we can show subtle “editing” states if desired
      if (mounted) setState(() {});
    });
    // _scannedValues.insert(0, (DateTime.now().millisecond * DateTime.now().microsecond).toString());
    _scannerCtrl.addListener(_onScannerDetected);
  }

  @override
  void dispose() {
    _scanner.dispose();
    _scanListScroll.dispose();
    _extractedCtrl.dispose();
    _fieldFocus.dispose();
    _scannerCtrl.removeListener(_onScannerDetected);
    _scannerCtrl.dispose();
    super.dispose();
  }

  void _toggleOrientationLock() {
    setState(() {
      _isOrientationLocked = !_isOrientationLocked;
    });

    if (_isOrientationLocked) {
      // Lock to the actual current device orientation
      final orientation = View.of(context).physicalSize.aspectRatio > 1 ? Orientation.landscape : Orientation.portrait;

      // For more precise detection, we need to check the actual rotation
      // This will lock to whatever orientation the device is currently in
      if (orientation == Orientation.portrait) {
        // Could be portrait up or portrait upside down
        // Lock to both portrait modes to maintain current position
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
      } else {
        // Could be landscape left or landscape right
        // Lock to both landscape modes to maintain current position
        SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      }
    } else {
      // Unlock all orientations
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
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
    _extractedCtrl.selection = TextSelection.fromPosition(TextPosition(offset: trimmed.length));
    setState(() {});
  }

  Future<void> _pauseScanner() async {
    if (_scannerPaused) return;
    _scannerPaused = true;
    try {
      await _scanner.stop();
      if (mounted) {
        setState(() {
          _cameraInitialized = false;
        });
      }
    } catch (e) {
      logger.w('Pause scanner failed: $e');
    }
    if (mounted) setState(() {});
  }

  Future<void> _resumeScanner({bool clearField = false}) async {
    if (_mode != SCAN_CAMERA_MODE) return;

    _scannerPaused = false;
    if (clearField) _extractedCtrl.clear();

    try {
      await _scanner.start();
      if (mounted) {
        setState(() {
          _cameraInitialized = true;
        });
      }
    } catch (e) {
      logger.e('Resume scanner failed, retrying: $e');
      await _startCameraWithRetry();
    }
  }

  // ---------- Barcode/QR detection ----------
  Future<void> _handleDetectedValue(String value) async {
    final v = value.trim();
    if (v.isEmpty) return;

    if (!_acceptScan(v)) return;

    _setExtracted(v);
    // _showSnack('Scanned. Review and submit.');
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
                      style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const Spacer(),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), color: scheme.onSurfaceVariant),
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
                    trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
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

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating));
  }

  void _onBarcodeDetected(BarcodeCapture capture) async {
    if (_mode != SCAN_CAMERA_MODE) return;
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

    // Process each unique barcode
    final unique = values.toSet().toList();

    // If multiple, ask user which one (pause scanning temporarily)
    if (unique.length > 1 && !_cameraScanning) {
      await _pauseScanner();
      await _showMultiSelectSheet(unique);
      await _resumeScanner();
      return;
    }

    // In continuous mode, process all unique codes
    for (final code in unique) {
      if (!_acceptScan(code)) continue;

      // Do network call without blocking
      lookupBarcode(code)
          .then((product) {
            if (product != null) {
              _appendScan(product.id, product);
            } else {
              logger.w('No product info found for: $code');
            }
          })
          .catchError((e) {
            logger.e('Barcode lookup failed: $e');
          });
    }
  }

  void _onScannerDetected() async {
    logger.i('Mode: $_mode');
    if (_mode != SCAN_RFID_MODE) return;

    logger.i('_isBusy: $_isBusy');
    if (_isBusy) return;

    final value = _scannerCtrl.text;

    if (value.endsWith('\n') || value.endsWith('\r')) {
      await _pauseScanner();
      _scannerCtrl.clear();
      _fieldFocus.requestFocus();
      // Do network call without blocking UI
      lookupBarcode(value.trim())
          .then((product) {
            if (product != null) {
              _appendScan(product.id, product);
              // _showSnack('Product found: ${product.name}');
            } else {
              _showSnack('No product info found for scanned code.');
            }
          })
          .catchError((e) {
            logger.e('Barcode lookup failed: $e');
            _showSnack('Lookup failed. Check connection.');
          });
    }
  }

  Future<Product?> lookupBarcode(String barcode) async {
    // Replace the lookupBarcode method
    // Try cache first
    final cached = await BarcodeCache.get(barcode);
    if (cached != null) {
      logger.i('Cache hit for barcode: $barcode');
      return cached;
    }
    logger.i('Cache miss - fetching from API: $barcode');
    final url = Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json');
    final res = await http.get(url);
    if (res.statusCode != 200) return null;
    final json = jsonDecode(res.body);
    if (json['status'] != 1) return null;
    final p = json['product'];
    logger.i('Product data: $p');
    final product = Product(id: p['_id'], name: p['product_name'] ?? '', brand: p['brands'] ?? '', category: p['categories'] ?? '');
    // Cache the result
    await BarcodeCache.set(barcode, product);
    return product;
  }

  Future<void> _saveToHistory(String value) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('scanned_values') ?? [];

    final timestamp = DateTime.now().microsecondsSinceEpoch.toString();
    final entry = '$timestamp|$value';
    // Add to history (avoid exact duplicates at the end)
    if (history.isEmpty || history.last != value) {
      history.add(entry);
      // Optional: limit history size (e.g., keep last 100)
      if (history.length > 100) {
        history.removeAt(0);
      }
      await prefs.setStringList('scanned_values', history);
    }
  }

  void _useScannedValue(String value) {
    setState(() {
      _extractedCtrl.text = value.split("\|")[0].trim();
      _extractedCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _extractedCtrl.text.length));
    });
  }

  String _normalizeScan(String raw) => raw.replaceAll('\n', '').replaceAll('\r', '').replaceAll('\t', '').trim();

  void _appendScan(String raw, Product product) async {
    final value = _normalizeScan(raw);
    if (_scannedSet.add(value)) {
      setState(() {
        _scannedValues.insert(0, product.toString());
      });
      // Await the save to catch errors
      try {
        await _saveToHistory(value);
      } catch (e) {
        logger.e('Failed to save to history: $e');
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scanListScroll.hasClients) return;
        // Scroll to top (position 0) to show newest item
        _scanListScroll.animateTo(0, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      });
    }
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

  void _clearExtractedCtrl() {
    _extractedCtrl.clear();
    setState(() {});
  }

  void _clearCurrentValueCtrl() {
    _scannerCtrl.clear();
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
          content: const Text('You have extracted text/value. Do you want to discard it and go back?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep editing')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Discard')),
          ],
        );
      },
    );
    return discard ?? false;
  }

  Future<void> _startCameraWithRetry({int maxRetries = 3}) async {
    _scannerPaused = false;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        logger.i('Starting camera, attempt $attempt/$maxRetries');

        // Force stop first to reset state
        try {
          await _scanner.stop();
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (_) {}

        // Start camera
        await _scanner.start();

        // Verify it started
        await Future.delayed(const Duration(milliseconds: 200));

        if (mounted) {
          setState(() {
            _cameraInitialized = true;
          });
        }

        logger.i('Camera started successfully');
        return;
      } catch (e) {
        logger.e('Camera start attempt $attempt failed: $e');

        if (attempt == maxRetries) {
          if (mounted) {
            _showSnack('Camera failed to start. Try reopening the screen.');
            setState(() {
              _cameraInitialized = false;
              _mode = SCAN_RFID_MODE; // Fallback to Scanner Mode
            });
          }
        } else {
          await Future.delayed(Duration(milliseconds: 300 * attempt));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
              tooltip: _isOrientationLocked ? 'Unlock rotation' : 'Lock rotation',
              onPressed: _toggleOrientationLock,
              icon: Icon(
                _isOrientationLocked ? Icons.screen_lock_rotation : Icons.screen_rotation,
                color: _isOrientationLocked ? scheme.error : scheme.primary.withValues(alpha: 0.7),
              ),
            ),
            IconButton(
              tooltip: 'Torch',
              onPressed: _isBusy || _mode != SCAN_CAMERA_MODE ? null : () => _scanner.toggleTorch(),
              icon: const Icon(Icons.flash_on),
            ),
            // IconButton(
            //   tooltip: 'Switch camera',
            //   onPressed: _isBusy || _mode != SCAN_CAMERA_MODE ? null : () => _scanner.switchCamera(),
            //   icon: const Icon(Icons.cameraswitch),
            // ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Mode selector
              // Mode selector
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: _ModeChip(
                        label: SCAN_RFID_MODE,
                        selected: _mode == SCAN_RFID_MODE,
                        onTap: _isBusy
                            ? null
                            : () async {
                                try {
                                  await _scanner.stop();
                                } catch (_) {}

                                setState(() {
                                  _mode = SCAN_RFID_MODE;
                                  _cameraScanning = false;
                                  _cameraInitialized = false;
                                });
                                await _pauseScanner();
                              },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ModeChip(
                        label: SCAN_CAMERA_MODE,
                        selected: _mode == SCAN_CAMERA_MODE,
                        onTap: _isBusy
                            ? null
                            : () async {
                                setState(() {
                                  _mode = SCAN_CAMERA_MODE;
                                  _cameraScanning = true;
                                });
                                await _startCameraWithRetry();
                              },
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Stack(
                        children: [
                          if (_mode != SCAN_RFID_MODE) ...[
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 350, maxWidth: double.infinity),
                              child: Stack(
                                children: [
                                  if (_cameraInitialized)
                                    MobileScanner(
                                      controller: _scanner,
                                      onDetect: _onBarcodeDetected,
                                      errorBuilder: (context, error, child) {
                                        return _ScannerErrorSurface(
                                          error: error,
                                          onManual: () {
                                            setState(() {
                                              _mode = SCAN_RFID_MODE;
                                              _cameraScanning = false;
                                            });
                                            _pauseScanner();
                                          },
                                          onRetry: () {
                                            _startCameraWithRetry();
                                          },
                                        );
                                      },
                                    )
                                  else
                                    Container(
                                      color: Colors.black,
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const CircularProgressIndicator(),
                                            const SizedBox(height: 16),
                                            Text('Initializing camera...', style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.8))),
                                          ],
                                        ),
                                      ),
                                    ),
                                  // Scan frame overlay
                                  IgnorePointer(
                                    child: Center(
                                      child: Container(
                                        width: 360,
                                        height: 75,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: _cameraScanning ? scheme.primary.withValues(alpha: 0.65) : scheme.primary.withValues(alpha: 0.45),
                                            width: _cameraScanning ? 2.0 : 1.3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Scanning indicator
                                  if (_cameraScanning)
                                    Align(
                                      alignment: Alignment.topCenter,
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: _Pill(icon: Icons.qr_code_scanner, text: 'Scanning...'),
                                      ),
                                    ),

                                  // Paused overlay
                                  if (_scannerPaused && !_isBusy)
                                    Align(
                                      alignment: Alignment.topCenter,
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: _Pill(icon: Icons.pause_circle_outline, text: _userIsEditing ? 'Paused (editing)' : 'Paused (review)'),
                                      ),
                                    ),

                                  // Busy overlay
                                  if (_isBusy)
                                    Container(
                                      color: Colors.black.withValues(alpha: 0.35),
                                      child: const Center(child: CircularProgressIndicator()),
                                    ),
                                ],
                              ),
                            ),

                            // Scanned items list
                            if (_mode == SCAN_CAMERA_MODE && _scannedValues.isNotEmpty)
                              Container(
                                constraints: const BoxConstraints(maxHeight: 200),
                                margin: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
                                  border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                                      child: Text(
                                        'Scanned Items (${_scannedValues.length})',
                                        style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    Expanded(
                                      child: ListView.builder(
                                        controller: _scanListScroll,
                                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                                        itemCount: _scannedValues.length,
                                        itemBuilder: (context, index) {
                                          final v = _scannedValues[index];
                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(12),
                                              color: scheme.surfaceContainerHighest.withValues(alpha: 0.66),
                                              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.95)),
                                            ),
                                            child: ListTile(
                                              dense: true,
                                              title: Text(
                                                v.toString(),
                                                style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600, fontSize: 14),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              trailing: const Icon(Icons.check_circle_outline, size: 20),
                                              onTap: () => _useScannedValue(v.toString()),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ] else ...[
                            ListView(
                              controller: _scanListScroll,
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
                              children: [
                                // Title
                                Text(
                                  'Scanner Mode (RFID)',
                                  style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w900, fontSize: 18),
                                ),
                                // Actions
                                // Scanned values list
                                Text(
                                  'Current value',
                                  style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                TextField(
                                  controller: _scannerCtrl,
                                  focusNode: _fieldFocus,
                                  minLines: 1,
                                  maxLines: 2,
                                  autofocus: true,
                                  readOnly: false,
                                  showCursor: true,
                                  enableInteractiveSelection: false,
                                  decoration: InputDecoration(
                                    hintText: "Scanned barcode",
                                    filled: true,
                                    fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.55), width: 1.3),
                                    ),
                                    suffixIcon: IconButton(
                                      tooltip: 'Clear',
                                      onPressed: _scannerCtrl.text.isEmpty ? null : _clearCurrentValueCtrl,
                                      icon: const Icon(Icons.clear),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                // Scanned values list
                                Text(
                                  'Scanned values (${_scannedValues.length})',
                                  style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                if (_scannedValues.isEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.16),
                                      border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.25)),
                                    ),
                                    child: Text(
                                      'No scans yet. Scan with your RFID gun or barcode scanner.',
                                      style: TextStyle(color: scheme.onSurfaceVariant),
                                    ),
                                  ),
                                ] else ...[
                                  ..._scannedValues.map((v) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        color: scheme.surfaceContainerHighest.withValues(alpha: 0.66),
                                        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.95)),
                                      ),
                                      child: ListTile(
                                        title: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Text(
                                            v.toString(),
                                            style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w800),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        // subtitle: Text('Tap to use', style: TextStyle(color: scheme.onSurfaceVariant)),
                                        trailing: const Icon(Icons.north_east_outlined),
                                        onTap: () => _useScannedValue(v.toString()),
                                      ),
                                    );
                                  }),
                                ],
                              ],
                            ),
                          ],
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
                      'ID for submission',
                      style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _extractedCtrl,
                      focusNode: _fieldFocus,
                      minLines: 1,
                      maxLines: 4,
                      autofocus: false,
                      readOnly: _mode == SCAN_RFID_MODE,
                      decoration: InputDecoration(
                        hintText: 'Select a scanned value or enter manually',
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.55), width: 1.3),
                        ),
                        suffixIcon: IconButton(
                          tooltip: 'Clear',
                          onPressed: _extractedCtrl.text.isEmpty ? null : _clearExtractedCtrl,
                          icon: const Icon(Icons.clear),
                        ),
                      ),
                      onChanged: (_) {
                        // If user types, keep scanner paused to avoid overwrites.
                        if (!_scannerPaused) {
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
                                    if (_mode == SCAN_CAMERA_MODE) {
                                      // Explicit rescan: resume and optionally clear field
                                      await _resumeScanner(clearField: false);
                                      _showSnack('Ready. Scan again.');
                                    } else {
                                      // For Scanner Mode, just clear and refocus
                                      _scannerCtrl.clear();
                                      _fieldFocus.requestFocus();
                                    }
                                  },
                            icon: const Icon(Icons.refresh),
                            label: Text(_mode == SCAN_CAMERA_MODE ? 'Rescan' : 'Retake'),
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
  const _ModeChip({required this.label, required this.selected, required this.onTap});

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
          color: selected ? scheme.primary.withValues(alpha: 0.16) : scheme.surfaceContainerHighest.withValues(alpha: 0.25),
          border: Border.all(color: selected ? scheme.primary.withValues(alpha: 0.55) : scheme.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w700, color: selected ? scheme.onSurface : scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

class _InlineBanner extends StatelessWidget {
  const _InlineBanner({required this.icon, required this.title, required this.body});

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
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
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
                  style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w800),
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
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ScannerErrorSurface extends StatelessWidget {
  const _ScannerErrorSurface({required this.error, required this.onManual, required this.onRetry});

  final MobileScannerException error;
  final VoidCallback onManual;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    String title = 'Camera unavailable';
    String body = 'We couldn’t access the camera. Try again, or use another input method.';

    // Common error codes:
    // - permissionDenied
    // - controllerUninitialized
    // - unknown
    // - unsupported
    final code = error.errorCode;

    if (code == MobileScannerErrorCode.permissionDenied) {
      title = 'Camera permission denied';
      body = 'Enable camera permission in settings, or use Photo/OCR or manual entry.';
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
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam_off_outlined, size: 44, color: scheme.onSurfaceVariant),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w900, fontSize: 16),
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
                      child: OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
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
                Text('Error: ${error.errorCode.name}', style: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.85), fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
