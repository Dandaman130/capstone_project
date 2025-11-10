/*
Current State 10/20/25 Last Modified v(beta 1.1)
Updated with Hive annotations for persistent caching
This model now supports both in-memory and disk-based storage
*/

import 'package:hive/hive.dart';

part 'scanned_product.g.dart';

@HiveType(typeId: 0)
class ScannedProduct {
  @HiveField(0)
  final String barcode;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String brand;

  @HiveField(3)
  final String quantity;

  @HiveField(4)
  final String nutriScore;

  @HiveField(5)
  final String ingredients;

  @HiveField(6)
  final DateTime cachedAt;

  ScannedProduct({
    required this.barcode,
    required this.name,
    required this.brand,
    required this.quantity,
    required this.nutriScore,
    required this.ingredients,
    DateTime? cachedAt,
  }) : cachedAt = cachedAt ?? DateTime.now();

  factory ScannedProduct.fromJson(String barcode, Map<String, dynamic> json) {
    return ScannedProduct(
      barcode: barcode,
      name: json['product_name'] ?? 'No name',
      brand: json['brands'] ?? 'Unknown',
      quantity: json['quantity'] ?? 'Unknown',
      nutriScore: (json['nutriscore_grade'] ?? 'N/A').toUpperCase(),
      ingredients: json['ingredients_text'] ?? 'Ingredients not listed',
      cachedAt: DateTime.now(),
    );
  }
}
