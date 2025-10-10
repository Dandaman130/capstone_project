//oct 9. store pruducts for fav. will be change and is just a test

import 'package:flutter_riverpod/flutter_riverpod.dart';
//import '../services/openfoodfacts_api.dart';
import '../products.dart';

class ProductNotifier extends StateNotifier<List<Product>> {
  ProductNotifier() : super([
    Product(id: 1, name: 'Laptop'),
    Product(id: 2, name: 'Mouse'),
    Product(id: 3, name: 'Keyboard'),
    Product(id: 4, name: 'Monitor'),
  ]);

  void toggleFavorite(int id) {
    state = [
      for (final product in state)
        if (product.id == id)
          Product(id: product.id, name: product.name, isFavorite: !product.isFavorite)
        else
          product
    ];
  }

  List<Product> get favorites =>
      state.where((product) => product.isFavorite).toList();
}

final productProvider =
    StateNotifierProvider<ProductNotifier, List<Product>>((ref) {
  return ProductNotifier();
});
