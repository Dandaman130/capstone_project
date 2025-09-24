/*
Current State 9/24/25 Last Modified v(beta 1.0)
This is the Scanner Page this currently is setup to scan a barcode once, then
reference the scanned_product_cache and if item is found there it returns it
if not then make API call to openfoodfacts_api,
there are also various debug statements throughout so makesure the products are
being logged

Things to Consider
breaking down alot of these components into modules so that there isnt as much
clutter in this screen
Also redesign the interface
*/

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers/product_provider.dart';
import '../models/scanned_product.dart';
import '../services/scanned_product_cache.dart';

class Screen1 extends ConsumerStatefulWidget {
  const Screen1({Key? key}) : super(key: key);

  @override
  ConsumerState<Screen1> createState() => _Screen1State();
}

class _Screen1State extends ConsumerState<Screen1> {
  final MobileScannerController _controller = MobileScannerController();
  String? _barcode;
  bool _hasScanned = false;

  @override
  void initState() {//Initialize Scanner & Log results then stop scanning
    super.initState();

    _controller.barcodes.listen((barcodeCapture) {//Using Camera to scan
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
  Widget build(BuildContext context) {//Page Layout while scanning
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
      appBar: AppBar(title: const Text('Scan Barcode')),
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
                  ScannedProductCache.addProduct(scanned); // Logs addition
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

  Widget buildProductDetails(ScannedProduct scanned) {//Page Layout once item is found
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(scanned.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Brand: ${scanned.brand}'),
        Text('Quantity: ${scanned.quantity}'),
        Text('Nutri-Score: ${scanned.nutriScore}'),
        Text('Ingredients: ${scanned.ingredients}'),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _barcode = null;
              _hasScanned = false;
              _controller.start();
            });
          },
          child: const Text('Scan Again'),
        ),
        const SizedBox(height: 24),
        const Text('Scanned Products:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...ScannedProductCache.all.map((p) => Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            title: Text(p.name),
            subtitle: Text('Brand: ${p.brand}\nNutri-Score: ${p.nutriScore}'),
            trailing: Text(p.quantity),
            isThreeLine: true,
          ),
        )),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}




