/*
Current State 10/20/25 Last Modified v(beta 1.2)
This is the Scanner Page - now with Hive layered caching
- Uses ProductCacheService for Memory → Hive → API lookup
- Camera automatically activates when screen loads
- Scanning guide overlay helps user position barcodes
*/

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:async';
import '../models/scanned_product.dart';
import '../services/product_cache_service.dart';
import '../widgets/barcode_scanner_widget.dart';
import '../widgets/product_details_widget.dart';

class Screen1 extends StatefulWidget {
  const Screen1({Key? key}) : super(key: key);

  @override
  State<Screen1> createState() => _Screen1State();
}

class _Screen1State extends State<Screen1> {
  final MobileScannerController _controller = MobileScannerController();
  StreamSubscription<BarcodeCapture>? _barcodeSubscription;
  String? _barcode;
  bool _hasScanned = false;
  bool _isLoading = false;
  ScannedProduct? _currentProduct;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeScanner();
  }

  void _initializeScanner() {
    // Initialize scanner and start listening for barcodes
    _barcodeSubscription = _controller.barcodes.listen((barcodeCapture) {
      if (_hasScanned || _isLoading) return;

      for (final barcode in barcodeCapture.barcodes) {
        final String? code = barcode.rawValue;
        if (code != null) {
          debugPrint('Barcode found: $code');
          _onBarcodeDetected(code);
          break;
        }
      }
    });
  }

  void _onBarcodeDetected(String barcode) async {
    setState(() {
      _barcode = barcode;
      _hasScanned = true;
      _isLoading = true;
      _errorMessage = null;
    });
    _controller.stop();

    try {
      // Use layered caching: Memory → Hive → API
      final product = await ProductCacheService.getProduct(barcode);

      if (mounted) {
        setState(() {
          _currentProduct = product;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching product: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _resetScanner() {
    setState(() {
      _barcode = null;
      _hasScanned = false;
      _isLoading = false;
      _currentProduct = null;
      _errorMessage = null;
    });
    _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Barcode Scanner'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_hasScanned)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetScanner,
              tooltip: 'Scan Again',
            ),
        ],
      ),
      body: Column(
        children: [
          // Scanner section
          if (!_hasScanned)
            Expanded(
              child: BarcodeScannerWidget(
                controller: _controller,
                onBarcodeDetected: _onBarcodeDetected,
              ),
            ),

          // Product details or loading/error section
          if (_hasScanned)
            Expanded(
              child: _buildContentSection(),
            ),
        ],
      ),
    );
  }

  Widget _buildContentSection() {
    // Show loading indicator
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Fetching product information...',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      );
    }

    // Show error message
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Error: $_errorMessage',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _resetScanner,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    // Show product details
    if (_currentProduct != null) {
      return ProductDetailsWidget(
        product: _currentProduct!,
        onScanAgain: _resetScanner,
      );
    }

    return const SizedBox.shrink();
  }

  @override
  void dispose() {
    // Cancel the barcode subscription first
    _barcodeSubscription?.cancel();
    // Stop the camera controller
    _controller.stop();
    // Dispose the controller
    _controller.dispose();
    super.dispose();
  }
}
