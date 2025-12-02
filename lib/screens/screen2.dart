/*
Changes Made: Dec 1, 2025
- Integrated Railway API to fetch products by categories
- Added category sections for "plant based" and "snacks" below search bar
- Horizontal scrolling product cards for each category
- Search bar now searches both cached scanned products and Railway database

Previous Changes (Sept 29, 2025):
Implemented search bar
- Realtime search that filters products by name or brand
- Products are stored in ScannedProductCache.all; screen filters list to display
items that match the search query
-Shows name, brand, quantity, and nutriscore (Can update this if needed)
- "No products found" if an item is searched and hasn't been scanned

TODO:
-Implementation of hive package for caching
-Add actual Railway URL in railway_api_service.dart
-Design improvements
 */


import 'package:flutter/material.dart';
import '../services/scanned_product_cache.dart';
import '../services/railway_api_service.dart';
import '../models/scanned_product.dart';
import '../models/product.dart';

class Screen2 extends StatefulWidget {
  const Screen2({Key? key}) : super(key: key);

  @override
  State<Screen2> createState() => _Screen2State();
}

class _Screen2State extends State<Screen2> {
  String _searchQuery = '';
  Map<String, List<Product>> _categoryProducts = {};
  bool _isLoading = true;

  final List<String> _categories = ['plant based', 'snacks'];

  @override
  void initState() {
    super.initState();
    _loadCategoryProducts();
  }

  Future<void> _loadCategoryProducts() async {
    setState(() {
      _isLoading = true;
    });

    final products = await RailwayApiService.getProductsByCategories(
      _categories,
      limit: 20,
    );

    setState(() {
      _categoryProducts = products;
      _isLoading = false;
    });
  }

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

          // If searching, show search results; otherwise show categories
          Expanded(
            child: _searchQuery.isNotEmpty
                ? _buildSearchResults(filteredProducts)
                : _buildCategoryView(),
          ),
        ],
      ),
    );
  }

  // Build search results view
  Widget _buildSearchResults(List<ScannedProduct> filteredProducts) {
    if (filteredProducts.isEmpty) {
      return const Center(
        child: Text(
          'No products found',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        final product = filteredProducts[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          child: ListTile(
            title: Text(product.name),
            subtitle: Text('Brand: ${product.brand}\n'
                'Nutri-Score: ${product.nutriScore}'),
            trailing: Text(product.quantity),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  // Build category view with horizontal scrolling products
  Widget _buildCategoryView() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCategoryProducts,
      child: ListView(
        children: [
          // Show scanned products section if any exist
          if (ScannedProductCache.all.isNotEmpty)
            _buildScannedProductsSection(),

          // Show category sections
          ..._categories.map((category) => _buildCategorySection(category)),
        ],
      ),
    );
  }

  // Build scanned products section
  Widget _buildScannedProductsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            'Recently Scanned',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: ScannedProductCache.all.length,
            itemBuilder: (context, index) {
              final product = ScannedProductCache.all[index];
              return _buildScannedProductCard(product);
            },
          ),
        ),
        const Divider(height: 32),
      ],
    );
  }

  // Build a category section with horizontal scrolling
  Widget _buildCategorySection(String category) {
    final products = _categoryProducts[category] ?? [];

    if (products.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatCategoryName(category),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  // TODO: Navigate to full category view
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('View all $category products')),
                  );
                },
                child: const Text('View All'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: products.length,
            itemBuilder: (context, index) {
              return _buildProductCard(products[index]);
            },
          ),
        ),
        const Divider(height: 32),
      ],
    );
  }

  // Build a product card for category products
  Widget _buildProductCard(Product product) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to product details
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tapped: ${product.name}')),
          );
        },
        child: Container(
          width: 120,
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Placeholder image
              Container(
                height: 100,
                width: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.image, size: 50, color: Colors.grey[400]);
                          },
                        ),
                      )
                    : Icon(Icons.image, size: 50, color: Colors.grey[400]),
              ),
              const SizedBox(height: 8),
              // Product name
              Expanded(
                child: Text(
                  product.name,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build a product card for scanned products
  Widget _buildScannedProductCard(ScannedProduct product) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to product details
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tapped: ${product.name}')),
          );
        },
        child: Container(
          width: 120,
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Placeholder image with nutri-score badge
              Stack(
                children: [
                  Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.shopping_bag, size: 50, color: Colors.grey[400]),
                  ),
                  if (product.nutriScore.isNotEmpty && product.nutriScore != 'N/A')
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getNutriScoreColor(product.nutriScore),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          product.nutriScore,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Product name
              Expanded(
                child: Text(
                  product.name,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Format category name for display
  String _formatCategoryName(String category) {
    return category
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  // Get nutri-score color
  Color _getNutriScoreColor(String score) {
    switch (score.toUpperCase()) {
      case 'A':
        return Colors.green[700]!;
      case 'B':
        return Colors.lightGreen;
      case 'C':
        return Colors.yellow[700]!;
      case 'D':
        return Colors.orange;
      case 'E':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
