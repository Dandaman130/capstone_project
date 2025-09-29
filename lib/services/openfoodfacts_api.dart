/*
Current State 9/24/25 Last Modified v(beta 1.0)
This is the actual call to API and feching requests
aswell as version Control

Things to Consider
UPDATE VERSION while iterating.
*/

import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenFoodFactsApi {
  static const String baseUrl = 'https://world.openfoodfacts.org/api/v0/product';

  Future<Map<String, dynamic>> fetchProduct(String barcode) async {
    final url = Uri.parse('$baseUrl/$barcode.json');

    //UPADTE THIS when iterating versions so OFF.com knows who/version we are.
    final response = await http.get(url, headers: {
      'User-Agent': 'Unnamed Capstone Project v(beta 1.0) - Dart/Flutter - dandun914@gmail.com'
    });

    if (response.statusCode == 200) {
      final jsonBody = json.decode(response.body);
      if (jsonBody['status'] == 1) {
        return jsonBody['product'];
      } else {
        throw Exception('Product not found');
      }
    } else {
      throw Exception('Failed to fetch product: ${response.statusCode}');
    }
  }
}
