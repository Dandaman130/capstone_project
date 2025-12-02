import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';

/*
Railway API Service
Handles all API calls to the Railway backend server
*/

class RailwayApiService {
  // Railway deployment URL
  // Updated: December 2, 2025 - New domain after regeneration
  static const String baseUrl = 'https://capstoneproject-production-fb1c.up.railway.app';

  // Get all products (with optional limit)
  static Future<List<Product>> getAllProducts({int limit = 100}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/products?limit=$limit'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => Product.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load products');
      }
    } catch (e) {
      print('Error fetching products: $e');
      return [];
    }
  }

  // Get product by barcode
  static Future<Product?> getProductByBarcode(String barcode) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/products/$barcode'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Product.fromJson(data);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to load product');
      }
    } catch (e) {
      print('Error fetching product by barcode: $e');
      return null;
    }
  }

  // Search products by name
  static Future<List<Product>> searchProducts(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/search?q=${Uri.encodeComponent(query)}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => Product.fromJson(item)).toList();
      } else {
        throw Exception('Failed to search products');
      }
    } catch (e) {
      print('Error searching products: $e');
      return [];
    }
  }

  // Get products by category
  static Future<List<Product>> getProductsByCategory(
    String category, {
    int limit = 20,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/categories/$category?limit=$limit'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => Product.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load products for category: $category');
      }
    } catch (e) {
      print('Error fetching products by category: $e');
      return [];
    }
  }

  // Get products from multiple categories at once
  static Future<Map<String, List<Product>>> getProductsByCategories(
    List<String> categories, {
    int limit = 20,
  }) async {
    try {
      final categoriesParam = categories.join(',');
      final url = '$baseUrl/api/categories-batch?categories=$categoriesParam&limit=$limit';

      print('Fetching from URL: $url');
      print('Categories requested: $categories');

      final response = await http.get(
        Uri.parse(url),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('Request timed out after 30 seconds');
          throw Exception('Request timeout');
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body length: ${response.body.length}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final Map<String, List<Product>> results = {};

        print('Categories in response: ${data.keys.toList()}');

        data.forEach((category, products) {
          final productList = (products as List)
              .map((item) => Product.fromJson(item))
              .toList();
          results[category] = productList;
          print('Category "$category": ${productList.length} products');
        });

        return results;
      } else {
        print('Server returned error: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Failed to load products for categories: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching products by categories: $e');
      print('Error type: ${e.runtimeType}');
      return {};
    }
  }
}

