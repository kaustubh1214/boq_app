import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import 'config.dart';

/// Camera permission before the scanner (and "Take a photo"): the phone's own "Allow camera?" question the first time;
/// if it was refused for good, a short explanation with a button to the app's page in phone Settings.
Future<bool> ensureCameraPermission(BuildContext context) async {
  var status = await Permission.camera.status;
  if (status.isGranted) return true;
  if (!status.isPermanentlyDenied && !status.isRestricted) {
    status = await Permission.camera.request();
    if (status.isGranted) return true;
  }
  if (!context.mounted) return false;
  final open = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Allow the camera'),
      content: Text(status.isPermanentlyDenied || status.isRestricted
          ? 'AV BOQ needs the camera to scan gate passes and take photos. '
              'Open Settings → Permissions → Camera → Allow, then come back.'
          : 'AV BOQ needs the camera to scan gate passes and take photos. Tap Allow when the phone asks.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Not now')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(status.isPermanentlyDenied || status.isRestricted ? 'Open Settings' : 'Ask again')),
      ],
    ),
  );
  if (open != true) return false;
  if (status.isPermanentlyDenied || status.isRestricted) {
    await openAppSettings();
    return false; // they come back and tap scan again
  }
  return (await Permission.camera.request()).isGranted;
}

/// Full-screen camera for the QR code on a gate pass. Pops with the QR text (or nothing on back).
class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> with WidgetsBindingObserver {
  final _camera = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera.dispose();
    super.dispose();
  }

  // Back from phone Settings (or another app): start the camera again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_camera.value.isRunning) {
      unawaited(_restart());
    }
  }

  Future<void> _restart() async {
    try {
      await _camera.stop();
      await _camera.start();
    } catch (_) {
      // the error is shown by errorBuilder
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final v = b.rawValue;
      if (v != null && v.isNotEmpty) {
        _done = true;
        Navigator.of(context).pop(v);
        return;
      }
    }
  }

  Widget _problem(MobileScannerException error) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.no_photography_outlined, color: Colors.white70, size: 40),
          const SizedBox(height: 12),
          Text(
            denied
                ? 'The camera is not allowed for AV BOQ.\nOpen Settings → Permissions → Camera → Allow.'
                : 'The camera could not start (${error.errorCode.name}). Close other camera apps and try again.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 20),
          if (denied)
            FilledButton.icon(onPressed: openAppSettings, icon: const Icon(Icons.settings_outlined), label: const Text('Open Settings')),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
            onPressed: _restart,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Scan gate pass'),
          actions: [
            IconButton(tooltip: 'Torch', icon: const Icon(Icons.flashlight_on_outlined), onPressed: () => _camera.toggleTorch()),
          ],
        ),
        body: ValueListenableBuilder<MobileScannerState>(
          valueListenable: _camera,
          builder: (context, state, _) => Stack(fit: StackFit.expand, children: [
            MobileScanner(controller: _camera, onDetect: _onDetect, errorBuilder: (context, error, child) => _problem(error)),
            if (state.error == null) ...[
              Center(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(border: Border.all(color: gold, width: 3), borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const Positioned(
                left: 24,
                right: 24,
                bottom: 48,
                child: Text(
                  'Point the camera at the QR code on the gate pass',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ]),
        ),
      );
}
