//created oct 9. 2025 Favorite button section. 
//things to be add: allow user to unfav things without going back to products list
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../products.dart';
import '../providers/fav_product_provider.dart';

class Screen3 extends ConsumerWidget {
  final List<Product>? favoriteProducts;
  const Screen3({Key? key, this.favoriteProducts}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = favoriteProducts ?? ref.watch(productProvider).where((p) => p.isFavorite).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: favorites.isEmpty
          ? const Center(child: Text('No favorites yet!'))
          : ListView.builder(
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final product = favorites[index];
                return ListTile(
                  title: Text(product.name),
                  trailing: const Icon(Icons.favorite, color: Colors.red),
                );
              },
            ),
    );
  }
}