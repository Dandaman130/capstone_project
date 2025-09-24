/*
Current State 9/24/25 Last Modified v(beta 1.0)
this is the code for cerating Obj for Temp Cache this cache gets destroyed after
hotreload so this should be finalized for app deployment

Things to Consider
adding @hive package for persistant caching which can be used for favorites
and recent products sacnned/lookedup and some more im forgetting.
(this shoud be ad=n add on not replace this code)
*/
class ScannedProduct {
  final String barcode;
  final String name;
  final String brand;
  final String quantity;
  final String nutriScore;
  final String ingredients;

  ScannedProduct({
    required this.barcode,
    required this.name,
    required this.brand,
    required this.quantity,
    required this.nutriScore,
    required this.ingredients,
  });

  factory ScannedProduct.fromJson(String barcode, Map<String, dynamic> json) {
    return ScannedProduct(
      barcode: barcode,
      name: json['product_name'] ?? 'No name',
      brand: json['brands'] ?? 'Unknown',
      quantity: json['quantity'] ?? 'Unknown',
      nutriScore: (json['nutriscore_grade'] ?? 'N/A').toUpperCase(),
      ingredients: json['ingredients_text'] ?? 'Ingredients not listed',
    );
  }
}
