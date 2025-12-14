/*
Current State 9/24/25 Last Modified v(Alpha 1.0)
-This is the Sample Products API so when you need to reference it for testing
call this if you want all products: ScannedProductCache.all
or call this if you want a certain obj ScannedProductCache.getByBarcode('insert barcode here')

Things to Consider
-Add more products to the Sample Products (which can be found in assets/sample directory
since there is only 2 currently you will probably want more, Just use chatgpt/Copilot to add
more for you easily.
*/

import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/scanned_product.dart';

class LocalProductLoader {
  static Map<String, ScannedProduct> _productMap = {};

  static Future<void> load() async {
    final jsonString = await rootBundle.loadString('assets/sample/sample_products.json');
    final List<dynamic> jsonList = json.decode(jsonString);

    _productMap = {
      for (var item in jsonList)
        item['barcode']: ScannedProduct.fromJson(item['barcode'], item)
    };
  }

  static ScannedProduct? getByBarcode(String barcode) {
    return _productMap[barcode];
  }

  static List<ScannedProduct> get all => _productMap.values.toList();
}
