/*
Product model for products fetched from Railway database
Matches the schema: id, name, categories, ingredients, barcode, image_url
*/

class Product {
  final int id;
  final String name;
  final String categories;
  final String ingredients;
  final String barcode;
  final String? imageUrl;

  Product({
    required this.id,
    required this.name,
    required this.categories,
    required this.ingredients,
    required this.barcode,
    this.imageUrl,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['name'] ?? 'Unknown Product',
      categories: json['categories'] ?? '',
      ingredients: json['ingredients'] ?? 'No ingredients listed',
      barcode: json['barcode'] ?? '',
      imageUrl: json['image_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'categories': categories,
      'ingredients': ingredients,
      'barcode': barcode,
      'image_url': imageUrl,
    };
  }
}

