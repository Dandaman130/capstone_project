import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';

/*
Railway API Service
Handles all API calls to the Railway backend server
*/

class RailwayApiService {
  // TODO: Replace this with your actual Railway deployment URL
  // You can find this in Railway → Deployments → Your deployment → Domain
  // It should look like: https://your-app-name.up.railway.app
  static const String baseUrl = 'capstoneproject-production-acf9.up.railway.app';

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
      final response = await http.get(
        Uri.parse('$baseUrl/api/categories-batch?categories=$categoriesParam&limit=$limit'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final Map<String, List<Product>> results = {};

        data.forEach((category, products) {
          results[category] = (products as List)
              .map((item) => Product.fromJson(item))
              .toList();
        });

        return results;
      } else {
        throw Exception('Failed to load products for categories');
      }
    } catch (e) {
      print('Error fetching products by categories: $e');
      return {};
    }
  }
}

