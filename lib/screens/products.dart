/*
Changes Made: Sept 29, 2025
Implemented search bar
- Realtime search that filters products by name or brand
- Products are stored in ScannedProductCache.all; screen filters list to display
items that match the search query
-Shows name, brand, quantity, and nutriscore (Can update this if needed)
- "No products found" if an item is searched and hasn't been scanned

TODO:
-Implementation of hive package for caching
-Design
 */


import 'package:flutter/material.dart';
import '../services/scanned_product_cache.dart';
import '../models/scanned_product.dart';

class Products extends StatefulWidget {
  const Products({Key? key}) : super(key: key);

  @override
  State<Products> createState() => _Screen2State();
}

class _Screen2State extends State<Products> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    //Filter scanned products by search query
    final List<ScannedProduct> filteredProducts = ScannedProductCache.all
        .where((product) =>
    product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        product.brand.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
      ),
      body: Column(
        children: [
          //Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search scanned products...',
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

          //Show filtered list
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
                  child: ListTile(
                    title: Text(product.name),
                    subtitle: Text('Brand: ${product.brand}\n'
                        'Nutri-Score: ${product.nutriScore}'),
                    trailing: Text(product.quantity),
                    isThreeLine: true,
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
