/*
Current State 9/24/25 Last Modified v(beta 1.0)
This runs all the cache comoponets for local hotreloading cache system

Things to Consider
implenting functionality with @Hive package for longeterm storage
*/

import 'package:flutter/cupertino.dart';
import '../models/scanned_product.dart';

class ScannedProductCache {
  static final List<ScannedProduct> _products = [];

  static void addProduct(ScannedProduct product) {
    if (!_products.any((p) => p.barcode == product.barcode)) {
      _products.add(product);
      debugPrint('Added to cache: ${product.name} (${product.barcode})');
    } else {
      debugPrint('Already in cache: ${product.name} (${product.barcode})');
    }
  }

  static List<ScannedProduct> get all => List.unmodifiable(_products);

  static bool contains(String barcode) {
    return _products.any((p) => p.barcode == barcode);
  }

  static ScannedProduct? getByBarcode(String barcode) {
    final match = _products.where((p) => p.barcode == barcode);
    if (match.isNotEmpty) {
      debugPrint('Retrieved from cache: ${match.first.name} ($barcode)');
      return match.first;
    } else {
      debugPrint('Not found in cache: $barcode');
      return null;
    }
  }

}
