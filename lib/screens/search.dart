/*
Current State - v(Alpha 2.4) - UI Refresh
- Search Screen - Product search and browsing
- Botanical theme applied: deep forest greens, aged gold, warm parchment
- Refined cards, search bar, and category sections
- Rate limiting maintained
*/

import 'package:flutter/material.dart';
import '../services/scanned_product_cache.dart';
import '../services/railway_api_service.dart';
import '../services/rate_limiter_service.dart';
import '../models/scanned_product.dart';
import '../models/product.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'product_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // ==================== STATE VARIABLES ====================
  String _searchQuery = '';
  Map<String, List<Product>> _categoryProducts = {};
  bool _isLoading = true;
  List<Product> _searchResults = [];
  bool _isSearching = false;

  // ==================== CONFIGURATION ====================
  final List<String> _categories = ['Snacks', 'Beverages'];
  final List<String> _prioritySnacksBarcodes = [
    '0000209024937',
    '0000141013129',
  ];

  // ==================== INITIALIZATION ====================
  @override
  void initState() {
    super.initState();
    _loadCategoryProducts();
  }

  // ==================== DATA LOADING METHODS ====================
  Future<void> _loadCategoryProducts() async {
    if (_isLoading && _categoryProducts.isNotEmpty) return;

    if (!RateLimiterService.canMakeCall(RateLimitType.batchSearch)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Rate limit exceeded. Please wait.'),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        setState(() { _isLoading = false; });
      }
      return;
    }

    if (mounted) setState(() { _isLoading = true; });

    RateLimiterService.recordCall(RateLimitType.batchSearch);

    final products = await RailwayApiService.getProductsByCategories(
      _categories,
      limit: 20,
    );

    if (_prioritySnacksBarcodes.isNotEmpty) {
      final priorityProducts = await RailwayApiService.getProductsByBarcodes(
        _prioritySnacksBarcodes,
      );
      if (priorityProducts.isNotEmpty && products.containsKey('Snacks')) {
        final regularSnacks = products['Snacks']!.where((p) {
          return !_prioritySnacksBarcodes.contains(p.barcode);
        }).toList();
        products['Snacks'] = [...priorityProducts, ...regularSnacks];
        print('✓ Added ${priorityProducts.length} priority products to Snacks');
      }
    }

    if (mounted) {
      setState(() {
        _categoryProducts = products;
        _isLoading = false;
      });
    }
  }

  Future<void> _searchDatabase(String query) async {
    if (query.isEmpty) {
      if (mounted) setState(() { _searchResults = []; _isSearching = false; });
      return;
    }
    if (mounted) setState(() { _isSearching = true; });
    try {
      final results = await RailwayApiService.searchProducts(query);
      if (query == _searchQuery && mounted) {
        setState(() { _searchResults = results; _isSearching = false; });
      }
    } catch (e) {
      print('Search error: $e');
      if (mounted) setState(() { _isSearching = false; });
    }
  }

  // ==================== UI BUILD METHODS ====================
  @override
  Widget build(BuildContext context) {
    final List<ScannedProduct> filteredProducts = ScannedProductCache.all
        .where((p) =>
    p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        p.brand.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    final remaining = RateLimiterService.getRemainingCalls(RateLimitType.batchSearch);

    return Scaffold(
      backgroundColor: AppColors.forestDeep,
      appBar: _buildAppBar(remaining),
      body: Container(
        decoration: BoxDecoration(
          color: AppColors.forestDeep,
          image: DecorationImage(
            image: const AssetImage('lib/theme/vinebg.png'),
            fit: BoxFit.none,
            scale: 1.8,
            opacity: 0.18,
          ),
        ),
        child: Column(
          children: [
            _buildSearchBar(),
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
      ),
    );
  }

  // ==================== APP BAR ====================
  PreferredSizeWidget _buildAppBar(int remaining) {
    return AppBar(
      backgroundColor: AppColors.forestDeep,
      elevation: 0,
      centerTitle: true,
      title: const Text(
        'Products',
        style: TextStyle(
          color: AppColors.parchment,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.transparent,
              AppColors.mossGreen.withOpacity(0.5),
              Colors.transparent,
            ]),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: remaining <= 3
                  ? Colors.red.shade800.withOpacity(0.85)
                  : AppColors.mossGreen.withOpacity(0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: remaining <= 3
                    ? Colors.red.shade400
                    : AppColors.fernGreen.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: Text(
              '$remaining/15',
              style: TextStyle(
                color: remaining <= 3 ? Colors.white : AppColors.mistGreen,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== SEARCH BAR ====================
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepShadow.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          style: const TextStyle(color: AppColors.parchment, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'What are you looking for?',
            hintStyle: TextStyle(color: AppColors.fernGreen.withOpacity(0.6)),
            prefixIcon: Icon(Icons.search_rounded, color: AppColors.fernGreen.withOpacity(0.8)),
            suffixIcon: _isSearching
                ? Padding(
              padding: const EdgeInsets.all(12.0),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.agedGold,
                ),
              ),
            )
                : _searchQuery.isNotEmpty
                ? IconButton(
              icon: Icon(Icons.close_rounded,
                  color: AppColors.fernGreen.withOpacity(0.7)),
              onPressed: () => setState(() {
                _searchQuery = '';
                _searchResults = [];
              }),
            )
                : null,
            filled: true,
            fillColor: AppColors.forestMid,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: AppColors.mossGreen.withOpacity(0.3),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.agedGold, width: 1.5),
            ),
          ),
          onChanged: (value) {
            setState(() { _searchQuery = value; });
            Future.delayed(const Duration(milliseconds: 500), () {
              if (value == _searchQuery) _searchDatabase(value);
            });
          },
        ),
      ),
    );
  }

  // ==================== SEARCH OVERLAY ====================
  Widget _buildSearchOverlay(List<ScannedProduct> filteredCachedProducts) {
    final bool hasLocal = filteredCachedProducts.isNotEmpty;
    final bool hasDb = _searchResults.isNotEmpty;
    final bool noResults = !hasLocal && !hasDb && !_isSearching;

    return Container(
      color: AppColors.deepShadow.withOpacity(0.6),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.62,
              ),
              decoration: BoxDecoration(
                color: AppColors.forestMid,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.mossGreen.withOpacity(0.35),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.deepShadow.withOpacity(0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: noResults
                  ? Padding(
                padding: const EdgeInsets.all(28.0),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off_rounded,
                          size: 36, color: AppColors.fernGreen.withOpacity(0.5)),
                      const SizedBox(height: 12),
                      Text(
                        _isSearching ? 'Searching...' : 'No products found',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.mistGreen.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  : ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(8),
                children: [
                  // ── Recently Scanned ──
                  if (hasLocal) ...[
                    _buildOverlaySectionHeader('Recently Scanned',
                        Icons.history_rounded),
                    ...filteredCachedProducts.map((p) =>
                        _buildCachedProductTile(p)),
                  ],
                  // ── Database Results ──
                  if (hasDb) ...[
                    if (hasLocal)
                      Divider(color: AppColors.mossGreen.withOpacity(0.3),
                          height: 16),
                    _buildOverlaySectionHeader('Database Results',
                        Icons.storage_rounded),
                    ..._searchResults.map((p) =>
                        _buildDbProductTile(p)),
                  ],
                  if (_isSearching)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.agedGold, strokeWidth: 2),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlaySectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.agedGold.withOpacity(0.8)),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.agedGold.withOpacity(0.9),
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCachedProductTile(ScannedProduct product) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.mossGreen.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.mossGreen.withOpacity(0.3)),
        ),
        child: product.nutriScore.isNotEmpty && product.nutriScore != 'N/A'
            ? Center(
          child: Text(
            product.nutriScore,
            style: TextStyle(
              color: _getNutriScoreColor(product.nutriScore),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        )
            : Icon(Icons.shopping_bag_outlined, size: 20,
            color: AppColors.fernGreen.withOpacity(0.7)),
      ),
      title: Text(product.name,
          style: const TextStyle(fontSize: 14, color: AppColors.parchment)),
      subtitle: Text('${product.brand} • ${product.quantity}',
          style: TextStyle(fontSize: 12, color: AppColors.mistGreen.withOpacity(0.8))),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) =>
              ProductDetailScreen(scannedProduct: product))),
    );
  }

  Widget _buildDbProductTile(Product product) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.mossGreen.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.mossGreen.withOpacity(0.3)),
        ),
        child: product.imageUrl != null && product.imageUrl!.isNotEmpty
            ? ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(product.imageUrl!, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(Icons.image_outlined,
                  size: 20, color: AppColors.fernGreen.withOpacity(0.7))),
        )
            : Icon(Icons.image_outlined, size: 20,
            color: AppColors.fernGreen.withOpacity(0.7)),
      ),
      title: Text(product.name,
          style: const TextStyle(fontSize: 14, color: AppColors.parchment)),
      subtitle: Text(
        product.categories.isNotEmpty
            ? product.categories.split(',').first
            : 'No category',
        style: TextStyle(fontSize: 12, color: AppColors.mistGreen.withOpacity(0.8)),
      ),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) =>
              ProductDetailScreen(railwayProduct: product))),
    );
  }

  // ==================== CATEGORY VIEW ====================
  Widget _buildCategoryView() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.agedGold, strokeWidth: 2),
            const SizedBox(height: 16),
            Text('Loading products...',
                style: TextStyle(color: AppColors.mistGreen.withOpacity(0.7),
                    fontSize: 14)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.agedGold,
      backgroundColor: AppColors.forestMid,
      onRefresh: _loadCategoryProducts,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          if (ScannedProductCache.all.isNotEmpty)
            _buildScannedProductsSection(),
          ..._categories.map((c) => _buildCategorySection(c)),
        ],
      ),
    );
  }

  // ==================== RECENTLY SCANNED ====================
  Widget _buildScannedProductsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Recently Scanned', Icons.history_rounded),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: ScannedProductCache.all.length,
            itemBuilder: (context, index) =>
                _buildScannedProductCard(ScannedProductCache.all[index]),
          ),
        ),
        _buildSectionDivider(),
      ],
    );
  }

  // ==================== CATEGORY SECTION ====================
  Widget _buildCategorySection(String category) {
    final products = _categoryProducts[category] ?? [];
    if (products.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.agedGold,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _formatCategoryName(category),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.parchment,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('View all $category products'),
                    backgroundColor: AppColors.forestMid,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ));
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.agedGold,
                  textStyle: const TextStyle(fontSize: 13),
                ),
                child: const Text('View All →'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: products.length,
            itemBuilder: (context, index) => _buildProductCard(products[index]),
          ),
        ),
        _buildSectionDivider(),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.agedGold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.parchment,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Colors.transparent,
            AppColors.mossGreen.withOpacity(0.4),
            Colors.transparent,
          ]),
        ),
      ),
    );
  }

  // ==================== PRODUCT CARDS ====================
  Widget _buildProductCard(Product product) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) =>
              ProductDetailScreen(railwayProduct: product))),
      child: Container(
        width: 130,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.forestMid,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.mossGreen.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepShadow.withOpacity(0.4),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: Container(
                height: 100,
                width: double.infinity,
                color: AppColors.mossGreen.withOpacity(0.2),
                child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                    ? Image.network(product.imageUrl!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(Icons.image_outlined,
                        size: 40, color: AppColors.fernGreen.withOpacity(0.5)))
                    : Icon(Icons.image_outlined, size: 40,
                    color: AppColors.fernGreen.withOpacity(0.5)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Text(
                product.name,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.parchment,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannedProductCard(ScannedProduct product) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) =>
              ProductDetailScreen(scannedProduct: product))),
      child: Container(
        width: 130,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.forestMid,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.mossGreen.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepShadow.withOpacity(0.4),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
                  child: Container(
                    height: 100,
                    width: double.infinity,
                    color: AppColors.mossGreen.withOpacity(0.2),
                    child: product.imageUrl != null &&
                        product.imageUrl!.isNotEmpty
                        ? Image.network(product.imageUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                            Icons.shopping_bag_outlined,
                            size: 40,
                            color: AppColors.fernGreen.withOpacity(0.5)))
                        : Icon(Icons.shopping_bag_outlined,
                        size: 40,
                        color: AppColors.fernGreen.withOpacity(0.5)),
                  ),
                ),
                if (product.nutriScore.isNotEmpty &&
                    product.nutriScore != 'N/A')
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: _getNutriScoreColor(product.nutriScore),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4)
                        ],
                      ),
                      child: Text(
                        product.nutriScore,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Text(
                product.name,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.parchment,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== HELPERS ====================
  String _formatCategoryName(String category) {
    return category
        .split(' ')
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  Color _getNutriScoreColor(String score) {
    switch (score.toUpperCase()) {
      case 'A': return Colors.green[700]!;
      case 'B': return Colors.lightGreen;
      case 'C': return Colors.yellow[700]!;
      case 'D': return Colors.orange;
      case 'E': return Colors.red;
      default:  return Colors.grey;
    }
  }
}