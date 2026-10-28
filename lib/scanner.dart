import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'config.dart';

/// Full-screen camera for the QR code on a gate pass. Pops with the QR text (or nothing on back).
class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final _camera = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _done = false;

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
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
        body: Stack(fit: StackFit.expand, children: [
          MobileScanner(
            controller: _camera,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Camera not available. Allow camera access for AV BOQ in phone Settings, or go back and type the issue note number.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
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
        ]),
      );
}
