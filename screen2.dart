import 'package:flutter/material.dart';
import 'package:capstone_project_app/screens/screen3.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/fav_product_provider.dart';

class Screen2 extends ConsumerStatefulWidget {
  const Screen2({Key? key}) : super(key: key);

  @override
  ConsumerState<Screen2> createState() => _Screen2State();
}

class _Screen2State extends ConsumerState<Screen2> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productProvider);

    // Apply search filtering
    final filteredProducts = products.where((product) {
      final query = _searchQuery.toLowerCase();
      return product.name.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite),
            onPressed: () {
              // Navigate to Screen3 (Favorites)
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Screen3(
                    favoriteProducts: ref.read(productProvider.notifier).favorites,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 🔍 Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // 🧾 Product List
          Expanded(
            child: filteredProducts.isEmpty
                ? const Center(
                    child: Text(
                      'No products found',
                      style: TextStyle(fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 16),
                      //Favorite button
                        child: ListTile(
                          title: Text(product.name),
                          trailing: IconButton(
                            icon: Icon(
                              product.isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color:
                                  product.isFavorite ? Colors.red : Colors.grey,
                            ),
                            onPressed: () {
                              ref
                                  .read(productProvider.notifier)
                                  .toggleFavorite(product.id);
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
