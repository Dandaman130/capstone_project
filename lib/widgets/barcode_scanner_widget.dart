import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerWidget extends StatefulWidget {
  final Function(String) onBarcodeDetected;
  final MobileScannerController controller;

  const BarcodeScannerWidget({
    Key? key,
    required this.onBarcodeDetected,
    required this.controller,
  }) : super(key: key);

  @override
  State<BarcodeScannerWidget> createState() => _BarcodeScannerWidgetState();
}

class _BarcodeScannerWidgetState extends State<BarcodeScannerWidget> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Camera scanner
        MobileScanner(controller: widget.controller),

        // Scanning guide overlay
        const ScanningGuideOverlay(),

        // Instructions
        Positioned(
          top: 50,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: const Text(
              'Position the barcode within the frame',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    offset: Offset(1.0, 1.0),
                    blurRadius: 3.0,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ScanningGuideOverlay extends StatelessWidget {
  const ScanningGuideOverlay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 280,
        height: 180,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            // Corner brackets
            ...buildCornerBrackets(),
          ],
        ),
      ),
    );
  }

  List<Widget> buildCornerBrackets() {
    final bracketSize = 20.0;
    final bracketThickness = 3.0;
    final bracketColor = Colors.green;

    return [
      // Top-left corner
      Positioned(
        top: -bracketThickness,
        left: -bracketThickness,
        child: Container(
          width: bracketSize,
          height: bracketSize,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: bracketColor, width: bracketThickness),
              left: BorderSide(color: bracketColor, width: bracketThickness),
            ),
          ),
        ),
      ),
      // Top-right corner
      Positioned(
        top: -bracketThickness,
        right: -bracketThickness,
        child: Container(
          width: bracketSize,
          height: bracketSize,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: bracketColor, width: bracketThickness),
              right: BorderSide(color: bracketColor, width: bracketThickness),
            ),
          ),
        ),
      ),
      // Bottom-left corner
      Positioned(
        bottom: -bracketThickness,
        left: -bracketThickness,
        child: Container(
          width: bracketSize,
          height: bracketSize,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: bracketColor, width: bracketThickness),
              left: BorderSide(color: bracketColor, width: bracketThickness),
            ),
          ),
        ),
      ),
      // Bottom-right corner
      Positioned(
        bottom: -bracketThickness,
        right: -bracketThickness,
        child: Container(
          width: bracketSize,
          height: bracketSize,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: bracketColor, width: bracketThickness),
              right: BorderSide(color: bracketColor, width: bracketThickness),
            ),
          ),
        ),
      ),
    ];
  }
}
