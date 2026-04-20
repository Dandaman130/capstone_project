/*
Product model for products fetched from Railway database
Updated for normalized schema: barcode (PK), name, brand, image_url, categories (joined), dietary flags
*/

class Product {
  final String barcode;
  final String name;
  final String? brand;
  final String? imageUrl;
  final String categories; // Comma-separated category names from join
  final int? isVegan; // -1 = unknown, 0 = no, 1 = yes
  final int? isVegetarian;
  final int? isGlutenFree;
  final int? isDairyFree;

  Product({
    required this.barcode,
    required this.name,
    this.brand,
    this.imageUrl,
    this.categories = '',
    this.isVegan,
    this.isVegetarian,
    this.isGlutenFree,
    this.isDairyFree,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      barcode: json['barcode'] ?? '',
      name: json['name'] ?? 'Unknown Product',
      brand: json['brand'],
      imageUrl: json['image_url'],
      categories: json['categories'] ?? '',
      isVegan: json['is_vegan'],
      isVegetarian: json['is_vegetarian'],
      isGlutenFree: json['is_gluten_free'],
      isDairyFree: json['is_dairy_free'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'barcode': barcode,
      'name': name,
      'brand': brand,
      'image_url': imageUrl,
      'categories': categories,
      'is_vegan': isVegan,
      'is_vegetarian': isVegetarian,
      'is_gluten_free': isGlutenFree,
      'is_dairy_free': isDairyFree,
    };
  }

  // Helper getters for dietary info
  bool get isDefinitelyVegan => isVegan == 1;
  bool get isDefinitelyVegetarian => isVegetarian == 1;
  bool get isDefinitelyGlutenFree => isGlutenFree == 1;
  bool get isDefinitelyDairyFree => isDairyFree == 1;

  bool get hasUnknownVeganStatus => isVegan == null || isVegan == -1;
  bool get hasUnknownVegetarianStatus => isVegetarian == null || isVegetarian == -1;
  bool get hasUnknownGlutenFreeStatus => isGlutenFree == null || isGlutenFree == -1;
  bool get hasUnknownDairyFreeStatus => isDairyFree == null || isDairyFree == -1;
}



