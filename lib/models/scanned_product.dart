/*
Current State 1/6/26 Last Modified v(A 1.2)
this is the code for cerating Obj for Temp Cache this cache gets destroyed after
hotreload so this should be finalized for app deployment

Added Fields:
-Countries Available In

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
  final String? imageUrl;
  final String? countries;

  // Dietary Fields
  final int? isVegan;       // -1 = unknown, 0 = no, 1 = yes
  final int? isVegetarian;
  final int? isGlutenFree;
  final int? isDairyFree;

  ScannedProduct({
    required this.barcode,
    required this.name,
    required this.brand,
    required this.quantity,
    required this.nutriScore,
    required this.ingredients,
    this.imageUrl,
    this.countries,
    this.isVegan,
    this.isVegetarian,
    this.isGlutenFree,
    this.isDairyFree,
  });

  // Getter to automatically translate integers to UI tags
  List<String> get dietaryTags {
    List<String> tags = [];
    if (isVegan == 1) tags.add('Vegan');
    if (isVegetarian == 1) tags.add('Vegetarian');
    if (isGlutenFree == 1) tags.add('Gluten-Free');
    if (isDairyFree == 1) tags.add('Dairy-Free');
    return tags;
  }

  factory ScannedProduct.fromJson(String barcode, Map<String, dynamic> json) {
    //Helper function to search Open Food Facts tag lists
    bool hasTag(String listKey, String tagToFind) {
      if (json[listKey] != null && json[listKey] is List) {
        return (json[listKey] as List).contains(tagToFind);
      }
      return false;
    }

    // 1. Check Vegan Status
    int? veganStatus;
    if (hasTag('ingredients_analysis_tags', 'en:vegan')) veganStatus = 1;
    if (hasTag('ingredients_analysis_tags', 'en:non-vegan')) veganStatus = 0;

    // 2. Check Vegetarian Status
    int? vegetarianStatus;
    if (hasTag('ingredients_analysis_tags', 'en:vegetarian')) vegetarianStatus = 1;
    if (hasTag('ingredients_analysis_tags', 'en:non-vegetarian')) vegetarianStatus = 0;

    // 3. Check Gluten-Free Status
    int? glutenFreeStatus;
    if (hasTag('labels_tags', 'en:no-gluten') || hasTag('labels_tags', 'en:gluten-free')) {
      glutenFreeStatus = 1;
    } else if (hasTag('allergens_tags', 'en:gluten')) {
      glutenFreeStatus = 0;
    }

    // 4. Check Dairy-Free Status
    int? dairyFreeStatus;
    if (hasTag('allergens_tags', 'en:milk') || hasTag('allergens_tags', 'en:dairy')) {
      dairyFreeStatus = 0;
    } else if (veganStatus == 1) {
      dairyFreeStatus = 1; // If it's explicitly vegan, it's dairy-free
    }

    return ScannedProduct(
      barcode: barcode,
      name: json['product_name'] ?? json['name'] ?? 'No name',
      brand: json['brands'] ?? json['brand'] ?? 'Unknown',
      quantity: json['quantity'] ?? 'Unknown',
      nutriScore: (json['nutriscore_grade'] ?? 'N/A').toUpperCase(),
      ingredients: json['ingredients_text'] ?? 'Ingredients not listed',
      imageUrl: json['image_url'] ?? json['image_front_url'] ?? json['image_front_small_url'],
      countries: json['countries'] ?? 'Unknown',
      
      // Assign our newly calculated statuses
      isVegan: veganStatus,
      isVegetarian: vegetarianStatus,
      isGlutenFree: glutenFreeStatus,
      isDairyFree: dairyFreeStatus,
    );
  }
}
