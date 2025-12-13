/*
Current State 12/13/25 Last Modified v(Alpha 2.2)
-Search Screen - Product search and browsing
-Renamed from Screen2
*/

import 'package:flutter/material.dart';
import '../services/scanned_product_cache.dart';
import '../services/railway_api_service.dart';
import '../models/scanned_product.dart';
import '../models/product.dart';
import '../theme/app_colors.dart';
import 'product_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _searchQuery = '';
  Map<String, List<Product>> _categoryProducts = {};
  bool _isLoading = true;

  List<Product> _searchResults = [];
  bool _isSearching = false;

  final List<String> _categories = ['Snacks', 'Beverages'];

  final List<String> _prioritySnacksBarcodes = [
    '0000209024937',
    '0000141013129',
  ];

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

    if (_prioritySnacksBarcodes.isNotEmpty) {
      final priorityProducts = await RailwayApiService.getProductsByBarcodes(
        _prioritySnacksBarcodes,
      );

      if (priorityProducts.isNotEmpty && products.containsKey('Snacks')) {
        final regularSnacks = products['Snacks']!.where((product) {
          return !_prioritySnacksBarcodes.contains(product.barcode);
        }).toList();

        products['Snacks'] = [...priorityProducts, ...regularSnacks];
        print('✓ Added ${priorityProducts.length} priority products to Snacks');
      }
    }

    setState(() {
      _categoryProducts = products;
      _isLoading = false;
    });
  }

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
    final List<ScannedProduct> filteredProducts = ScannedProductCache.all
        .where(
          (product) =>
              product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              product.brand.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: const Text('Products', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.sageGreen,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.sageGreen,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search products...',
                hintStyle: TextStyle(color: AppColors.mutedGreen),
                prefixIcon: Icon(Icons.search, color: AppColors.sageGreen),
                suffixIcon: _isSearching
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.sageGreen,
                          ),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.lightTan, width: 2),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (value == _searchQuery) {
                    _searchDatabase(value);
                  }
                });
              },
            ),
          ),

          Expanded(
            child: Stack(
              children: [
                _buildCategoryView(),
                if (_searchQuery.isNotEmpty)
                  _buildSearchOverlay(filteredProducts),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchOverlay(List<ScannedProduct> filteredCachedProducts) {
    final bool hasLocalResults = filteredCachedProducts.isNotEmpty;
    final bool hasDbResults = _searchResults.isNotEmpty;
    final bool noResults = !hasLocalResults && !hasDbResults && !_isSearching;

    return Container(
      color: Colors.black.withValues(alpha: 0.3),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
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

  Widget _buildCategoryView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadCategoryProducts,
      child: ListView(
        children: [
          if (ScannedProductCache.all.isNotEmpty)
            _buildScannedProductsSection(),
          ..._categories.map((category) => _buildCategorySection(category)),
        ],
      ),
    );
  }

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
                  color: AppColors.sageGreen,
                ),
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('View all $category products'),
                      backgroundColor: AppColors.sageGreen,
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.sageGreen,
                ),
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

  Widget _buildProductCard(Product product) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: AppColors.softMint,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 120,
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                height: 100,
                width: 100,
                decoration: BoxDecoration(
                  color: AppColors.lightTan,
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
                              color: AppColors.mutedGreen,
                            );
                          },
                        ),
                      )
                    : Icon(Icons.image, size: 50, color: AppColors.mutedGreen),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
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

  Widget _buildScannedProductCard(ScannedProduct product) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: AppColors.softMint,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 120,
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                children: [
                  Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      color: AppColors.lightTan,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.shopping_bag,
                      size: 50,
                      color: AppColors.mutedGreen,
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
              Expanded(
                child: Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
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

  String _formatCategoryName(String category) {
    return category
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

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
