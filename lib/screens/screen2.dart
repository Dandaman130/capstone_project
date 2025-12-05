/*
Current State 12/3/25 Last Modified v(Alpha 2.0)
Changes Made: Dec 1, 2025
- Integrated Railway API to fetch products by categories
- Added category sections for "plant based" and "snacks" below search bar
- Horizontal scrolling product cards for each category
- Search bar now searches both cached scanned products and Railway database

Previous Changes (9/29/25):
Implemented search bar
- Realtime search that filters products by name or brand
- Products are stored in ScannedProductCache.all; screen filters list to display
items that match the search query
-Shows name, brand, quantity, and nutriscore (Can update this if needed)
- "No products found" if an item is searched and hasn't been scanned

TODO:
-Display image thumbnails for products
-Design improvements
-Refactor screen title to something other than "Screen 2"
 */

import 'package:flutter/material.dart';
import '../services/scanned_product_cache.dart';
import '../services/railway_api_service.dart';
import '../models/scanned_product.dart';
import '../models/product.dart';
import 'product_detail_screen.dart';

class Screen2 extends StatefulWidget {
  const Screen2({Key? key}) : super(key: key);

  @override
  State<Screen2> createState() => _Screen2State();
}

class _Screen2State extends State<Screen2> {
  String _searchQuery = '';
  Map<String, List<Product>> _categoryProducts = {};
  bool _isLoading = true;

  // Database search results
  List<Product> _searchResults = [];
  bool _isSearching = false;

  // Updated to use actual categories from the database
  final List<String> _categories = ['Snacks', 'Beverages'];

  // ========================================================================
  // PRIORITY PRODUCT BARCODES - For testing
  // ========================================================================
  final List<String> _prioritySnacksBarcodes = [
    '0000209024937',
    '0000141013129',
  ];
  // ========================================================================

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

    // Fetch priority products for Snacks category
    if (_prioritySnacksBarcodes.isNotEmpty) {
      final priorityProducts = await RailwayApiService.getProductsByBarcodes(
        _prioritySnacksBarcodes,
      );

      if (priorityProducts.isNotEmpty && products.containsKey('Snacks')) {
        // Remove priority products from the regular list if they exist
        final regularSnacks = products['Snacks']!.where((product) {
          return !_prioritySnacksBarcodes.contains(product.barcode);
        }).toList();

        // Combine: priority products first, then regular products
        products['Snacks'] = [...priorityProducts, ...regularSnacks];
        print('✓ Added ${priorityProducts.length} priority products to Snacks');
      }
    }

    setState(() {
      _categoryProducts = products;
      _isLoading = false;
    });
  }

  // Search Railway database for products
  Future<void> _searchDatabase(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await RailwayApiService.searchProducts(query);

      // Only update if the search query hasn't changed
      if (query == _searchQuery) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      print('Search error: $e');
      setState(() {
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    //Filter scanned products by search query
    final List<ScannedProduct> filteredProducts = ScannedProductCache.all
        .where(
          (product) =>
              product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              product.brand.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      body: Column(
        children: [
          //Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                // Search database after user stops typing for 500ms
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (value == _searchQuery) {
                    _searchDatabase(value);
                  }
                });
              },
            ),
          ),

          // If searching, show search results; otherwise show categories
          Expanded(
            child: Stack(
              children: [
                // Always show category view in background
                _buildCategoryView(),

                // Show search overlay when typing
                if (_searchQuery.isNotEmpty)
                  _buildSearchOverlay(filteredProducts),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build search overlay - shows as a card on top of category view
  Widget _buildSearchOverlay(List<ScannedProduct> filteredCachedProducts) {
    final bool hasLocalResults = filteredCachedProducts.isNotEmpty;
    final bool hasDbResults = _searchResults.isNotEmpty;
    final bool noResults = !hasLocalResults && !hasDbResults && !_isSearching;

    return Container(
      color: Colors.black.withValues(alpha: 0.3), // Semi-transparent background
      child: Column(
        children: [
          // Search results card
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight:
                      MediaQuery.of(context).size.height *
                      0.6, // Max 60% of screen height
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: noResults
                    ? Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Center(
                          child: Text(
                            _isSearching ? 'Searching...' : 'No products found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(8),
                        children: [
                          // Show cached/scanned products first
                          if (hasLocalResults) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              child: Text(
                                'Recently Scanned',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            ...filteredCachedProducts.map(
                              (product) => ListTile(
                                dense: true,
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child:
                                      product.nutriScore.isNotEmpty &&
                                          product.nutriScore != 'N/A'
                                      ? Center(
                                          child: Text(
                                            product.nutriScore,
                                            style: TextStyle(
                                              color: _getNutriScoreColor(
                                                product.nutriScore,
                                              ),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        )
                                      : Icon(
                                          Icons.shopping_bag,
                                          size: 20,
                                          color: Colors.grey[400],
                                        ),
                                ),
                                title: Text(
                                  product.name,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                subtitle: Text(
                                  '${product.brand} • ${product.quantity}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProductDetailScreen(
                                        scannedProduct: product,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],

                          // Show database search results
                          if (hasDbResults) ...[
                            if (hasLocalResults) const Divider(),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              child: Text(
                                'Database Results',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            ..._searchResults.map(
                              (product) => ListTile(
                                dense: true,
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child:
                                      product.imageUrl != null &&
                                          product.imageUrl!.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          child: Image.network(
                                            product.imageUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                                  return Icon(
                                                    Icons.image,
                                                    size: 20,
                                                    color: Colors.grey[400],
                                                  );
                                                },
                                          ),
                                        )
                                      : Icon(
                                          Icons.image,
                                          size: 20,
                                          color: Colors.grey[400],
                                        ),
                                ),
                                title: Text(
                                  product.name,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                subtitle: Text(
                                  product.categories.isNotEmpty
                                      ? product.categories.split(',').first
                                      : 'No category',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProductDetailScreen(
                                        railwayProduct: product,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],

                          // Show loading indicator while searching
                          if (_isSearching)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build category view with horizontal scrolling products
  Widget _buildCategoryView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
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
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ProductDetailScreen(railwayProduct: product),
            ),
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
                            return Icon(
                              Icons.image,
                              size: 50,
                              color: Colors.grey[400],
                            );
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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ProductDetailScreen(scannedProduct: product),
            ),
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
                    child: Icon(
                      Icons.shopping_bag,
                      size: 50,
                      color: Colors.grey[400],
                    ),
                  ),
                  if (product.nutriScore.isNotEmpty &&
                      product.nutriScore != 'N/A')
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
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
