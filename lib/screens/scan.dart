/*
Current State 12/13/25 Last Modified v(Alpha 2.2)
-Scan Screen - Barcode scanning functionality
-Renamed from Screen1
*/

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers/product_provider.dart';
import '../models/scanned_product.dart';
import '../services/scanned_product_cache.dart';
import '../theme/app_colors.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  String? _barcode;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();

    _controller.barcodes.listen((barcodeCapture) {
      if (_hasScanned) return;

      for (final barcode in barcodeCapture.barcodes) {
        final String? code = barcode.rawValue;
        if (code != null) {
          debugPrint('Barcode found: $code');
          setState(() {
            _barcode = code;
            _hasScanned = true;
            _controller.stop();
          });
          break;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ScannedProduct? cachedProduct;
    if (_barcode != null) {
      cachedProduct = ScannedProductCache.getByBarcode(_barcode!);
      if (cachedProduct != null) {
        debugPrint('Retrieved from cache: ${cachedProduct.name} (${cachedProduct.barcode})');
      } else {
        debugPrint('Fetching from API: $_barcode');
      }
    }

    final productAsync = (_barcode != null && cachedProduct == null)
        ? ref.watch(productProvider(_barcode!))
        : null;

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: const Text('Scan Barcode', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.sageGreen,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          if (!_hasScanned)
            Expanded(child: MobileScanner(controller: _controller)),
          if (_barcode != null && (cachedProduct != null || productAsync != null))
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: cachedProduct != null
                  ? buildProductDetails(cachedProduct)
                  : productAsync!.when(
                data: (product) {
                  final scanned = ScannedProduct.fromJson(_barcode!, product);
                  ScannedProductCache.addProduct(scanned);
                  return buildProductDetails(scanned);
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
              ),
            ),
        ],
      ),
    );
  }

  Widget buildProductDetails(ScannedProduct scanned) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          scanned.name,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Brand: ${scanned.brand}',
          style: const TextStyle(color: Colors.black87),
        ),
        Text(
          'Quantity: ${scanned.quantity}',
          style: const TextStyle(color: Colors.black87),
        ),
        Text(
          'Nutri-Score: ${scanned.nutriScore}',
          style: const TextStyle(color: Colors.black87),
        ),
        Text(
          'Ingredients: ${scanned.ingredients}',
          style: const TextStyle(color: Colors.black87),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _barcode = null;
              _hasScanned = false;
              _controller.start();
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.sageGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Scan Again'),
        ),
        const SizedBox(height: 24),
        const Text(
          'Scanned Products:',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        ...ScannedProductCache.all.map(
          (p) => Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            color: AppColors.softMint,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              title: Text(
                p.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              subtitle: Text(
                'Brand: ${p.brand}\nNutri-Score: ${p.nutriScore}',
                style: const TextStyle(color: Colors.black87),
              ),
              trailing: Text(
                p.quantity,
                style: const TextStyle(color: Colors.black87),
              ),
              isThreeLine: true,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
