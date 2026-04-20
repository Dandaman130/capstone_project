/*
Current State 12/15/25 Last Modified v(Alpha 2.4)
-Search Screen - Product search and browsing
-Renamed from Screen2
-Added rate limiting (10 batch searches per minute)
-Added personalized "Recommended For You" section based on dietary preferences
-Added View All functionality and ViewAllProductsScreen for full grid browsing
*/

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session_manager.dart';
import '../services/scanned_product_cache.dart';
import '../services/railway_api_service.dart';
import '../services/rate_limiter_service.dart';
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
  // ==================== STATE VARIABLES ====================

  // Search query from text field
  String _searchQuery = '';

  // Products organized by category (loaded from Railway DB)
  Map<String, List<Product>> _categoryProducts = {};

  // Loading state for initial category products load
  bool _isLoading = true;

  // Database search results from Railway API
  List<Product> _searchResults = [];

  // Loading state for search operation
  bool _isSearching = false;

  // User's saved dietary preferences
  List<String> _userDietaryPrefs = [];

  // ==================== CONFIGURATION ====================

  // Categories to display in the main view
  final List<String> _categories = ['Snacks', 'Beverages'];

  // Priority products to show first in Snacks category
  final List<String> _prioritySnacksBarcodes = [
    '0000209024937', // Product 1
    '0000141013129', // Product 2
  ];

  // ==================== INITIALIZATION ====================

  @override
  void initState() {
    super.initState();
    // Load preferences first, then load the products from database
    _loadUserPreferences();
    _loadCategoryProducts();
  }

  // ==================== DATA LOADING METHODS ====================

  Future<void> _loadUserPreferences() async {
    // Safety check: make sure someone is logged in
    if (!SessionManager.isLoggedIn || SessionManager.currentUser == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final userId = SessionManager.currentUser!.userId;
    
    // Get the saved string from local storage
    final savedPrefsString = prefs.getString('dietary_prefs_$userId') ?? '';
    
    setState(() {
      if (savedPrefsString.isNotEmpty && savedPrefsString != 'None') {
        _userDietaryPrefs = savedPrefsString.split(', ');
      } else {
        _userDietaryPrefs = [];
      }
    });
  }

  /// Load products from Railway database organized by categories
  /// Uses rate limiting to prevent excessive API calls (15 batch searches per minute)
  Future<void> _loadCategoryProducts() async {
    // Check rate limit before making batch API call
    if (!RateLimiterService.canMakeCall(RateLimitType.batchSearch)) {
      // Show error message if rate limit exceeded
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rate limit exceeded. Please wait before loading more products.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Record the API call for rate limiting tracking
    RateLimiterService.recordCall(RateLimitType.batchSearch);

    // Fetch products by category from Railway API
    final products = await RailwayApiService.getProductsByCategories(
      _categories,
      limit: 20,
    );

    // Add priority products to the top of Snacks category
    if (_prioritySnacksBarcodes.isNotEmpty) {
      final priorityProducts = await RailwayApiService.getProductsByBarcodes(
        _prioritySnacksBarcodes,
      );

      if (priorityProducts.isNotEmpty && products.containsKey('Snacks')) {
        // Remove priority products from regular list to avoid duplicates
        final regularSnacks = products['Snacks']!.where((product) {
          return !_prioritySnacksBarcodes.contains(product.barcode);
        }).toList();

        // Put priority products first, then regular products
        products['Snacks'] = [...priorityProducts, ...regularSnacks];
        print('✓ Added ${priorityProducts.length} priority products to Snacks');
      }
    }

    setState(() {
      _categoryProducts = products;
      _isLoading = false;
    });
  }

  /// Search Railway database for products matching the query
  Future<void> _searchDatabase(String query) async {
    // Clear results if search query is empty
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
      // Query Railway database for matching products
      final results = await RailwayApiService.searchProducts(query);

      // Only update if the query hasn't changed (prevents race conditions)
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

  // ==================== UI BUILD METHODS ====================

  @override
  Widget build(BuildContext context) {
    // Filter scanned products from cache based on search query
    final List<ScannedProduct> filteredProducts = ScannedProductCache.all
        .where(
          (product) =>
              product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              product.brand.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();

    // Get remaining batch search API calls for rate limiter display
    final remainingBatchSearches = RateLimiterService.getRemainingCalls(RateLimitType.batchSearch);

    return Scaffold(
      backgroundColor: AppColors.sageGreen,
      appBar: AppBar(
        title: const Text('Products', style: TextStyle(color: AppColors.offWhite)),
        backgroundColor: AppColors.sageGreen,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.offWhite),
        actions: [
          // Rate limiter counter badge in app bar
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  // Show red warning when 3 or fewer calls remain
                  color: remainingBatchSearches <= 3 ? Colors.red.shade700 : Colors.white24,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$remainingBatchSearches/15',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        // Background with sage green color and vine pattern image overlay
        decoration: const BoxDecoration(
          color: AppColors.sageGreen,
          image: DecorationImage(
            image: AssetImage('lib/theme/vinebg.png'),
            fit: BoxFit.none,
            scale: 1.8,
            opacity: 1.0, 
          ),
        ),
        child: Column(
          children: [
            // ==================== SEARCH BAR ====================
            Container(
              color: Colors.transparent,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'What are you looking for?',
                hintStyle: const TextStyle(color: AppColors.mutedGreen),
                prefixIcon: const Icon(Icons.search, color: AppColors.sageGreen),
                // Show loading spinner while searching
                suffixIcon: _isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.sageGreen,
                          ),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: AppColors.offWhite,
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
                  borderSide: const BorderSide(color: AppColors.lightTan, width: 2),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                // Debounce search by 500ms to prevent excessive API calls
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (value == _searchQuery) {
                    _searchDatabase(value);
                  }
                });
              },
            ),
          ),

          // ==================== MAIN CONTENT AREA ====================
          Expanded(
            child: Stack(
              children: [
                // Background: Category view with products
                _buildCategoryView(),
                // Overlay: Search results (shown when search query is active)
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

  // ==================== SEARCH OVERLAY ====================

  Widget _buildSearchOverlay(List<ScannedProduct> filteredCachedProducts) {
    final bool hasLocalResults = filteredCachedProducts.isNotEmpty;
    final bool hasDbResults = _searchResults.isNotEmpty;
    final bool noResults = !hasLocalResults && !hasDbResults && !_isSearching;

    return Container(
      // Semi-transparent backdrop to dim the background content
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
                  color: AppColors.offWhite,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: noResults
                    ? // Show "No products found" message when search returns empty
                    Padding(
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
                          // -------- RECENTLY SCANNED SECTION --------
                          // Show products from local cache that match search
                          if (hasLocalResults) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              child: Text(
                                'Recently Scanned',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.offWhite,
                                ),
                              ),
                            ),
                            // Build list items for cached products
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
                                  // Show Nutri-Score badge or shopping bag icon
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
                                  // Navigate to product detail screen
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

                          // -------- DATABASE RESULTS SECTION --------
                          // Show products from Railway DB that match search
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
                            // Build list items for database products
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
                                  // Show product image or placeholder
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
                                  // Navigate to product detail screen
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

  // ==================== CATEGORY VIEW (Main Screen) ====================

  /// Build the main category view showing products organized by category
  Widget _buildCategoryView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.offWhite));
    }

    return RefreshIndicator(
      onRefresh: _loadCategoryProducts,
      color: AppColors.sageGreen,
      child: ListView(
        children: [
          // Show Recently Scanned section if there are cached products
          if (ScannedProductCache.all.isNotEmpty)
            _buildScannedProductsSection(),
            
          // Show Recommended Section based on dietary preferences
          _buildRecommendedSection(),
          
          // Build sections for each category (Snacks, Beverages, etc.)
          ..._categories.map((category) => _buildCategorySection(category)),
        ],
      ),
    );
  }

  /// Build the "Recommended For You" section based on saved tags
  Widget _buildRecommendedSection() {
    if (_userDietaryPrefs.isEmpty || _categoryProducts.isEmpty) {
      return const SizedBox.shrink();
    }

    List<Product> allLoadedProducts = [];
    for (var productList in _categoryProducts.values) {
      allLoadedProducts.addAll(productList);
    }

    final recommendedProducts = allLoadedProducts.where((product) {
      return _userDietaryPrefs.every((pref) {
        switch (pref.toLowerCase()) {
          case 'vegan':
            return product.isDefinitelyVegan;
          case 'vegetarian':
            return product.isDefinitelyVegetarian;
          case 'gluten-free':
            return product.isDefinitelyGlutenFree;
          case 'dairy-free':
            return product.isDefinitelyDairyFree;
          default:
            return false;
        }
      });
    }).toList();

    if (recommendedProducts.isEmpty) {
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
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.star, color: AppColors.lightTan, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Recommended For You',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.offWhite,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // View All Button for Recommendations
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ViewAllProductsScreen(
                        title: 'Recommended For You',
                        products: recommendedProducts,
                      ),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.offWhite,
                ),
                child: const Text('View All'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: recommendedProducts.length,
            itemBuilder: (context, index) {
              return _buildProductCard(recommendedProducts[index]);
            },
          ),
        ),
        const Divider(height: 32, color: Colors.black12),
      ],
    );
  }

  /// Build the "Recently Scanned" section showing products from local cache
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
            ).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.offWhite,
            ),
          ),
        ),
        // Horizontal scrolling list of scanned products
        SizedBox(
          height: 150,
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
        const Divider(height: 32, color: Colors.black12),
      ],
    );
  }

  /// Build a category section (e.g., "Snacks", "Beverages")
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
                  color: AppColors.offWhite,
                ),
              ),
              // View All Button for Category
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ViewAllProductsScreen(
                        title: _formatCategoryName(category),
                        products: products,
                      ),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.offWhite,
                ),
                child: const Text('View All'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: products.length,
            itemBuilder: (context, index) {
              return _buildProductCard(products[index]);
            },
          ),
        ),
        const Divider(height: 32, color: Colors.black12),
      ],
    );
  }

  Widget _buildProductCard(Product product) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: AppColors.mutedGreen,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 120,
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 100,
                width: 100,
                decoration: BoxDecoration(
                  color: AppColors.softMint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.image,
                              size: 50,
                              color: AppColors.mutedGreen,
                            );
                          },
                        ),
                      )
                    : const Icon(Icons.image, size: 50, color: AppColors.sageGreen),
              ),
              const SizedBox(height: 8),
              Text(
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScannedProductCard(ScannedProduct product) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: AppColors.mutedGreen,
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
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      color: AppColors.softMint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              product.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.shopping_bag,
                                  size: 50,
                                  color: AppColors.sageGreen,
                                );
                              },
                            ),
                          )
                        : const Icon(
                            Icons.shopping_bag,
                            size: 50,
                            color: AppColors.sageGreen,
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
              Text(
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

// ============================================================================
// Dedicated Grid View Screen for "View All" Functionality
// ============================================================================

class ViewAllProductsScreen extends StatelessWidget {
  final String title;
  final List<Product> products;

  const ViewAllProductsScreen({
    Key? key,
    required this.title,
    required this.products,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sageGreen,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: AppColors.offWhite)),
        backgroundColor: AppColors.sageGreen,
        iconTheme: const IconThemeData(color: AppColors.offWhite),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: AppColors.sageGreen,
          image: DecorationImage(
            image: AssetImage('lib/theme/vinebg.png'),
            fit: BoxFit.none,
            scale: 1.8,
            opacity: 1.0,
          ),
        ),
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // 2 items per row
            childAspectRatio: 0.75, // Adjust this ratio to make cards taller or wider
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return _buildGridProductCard(context, product);
          },
        ),
      ),
    );
  }

  Widget _buildGridProductCard(BuildContext context, Product product) {
    return Card(
      color: AppColors.mutedGreen,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // Navigate to the same detail screen when tapped
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailScreen(railwayProduct: product),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // The image takes up the available vertical space
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.softMint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            product.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.image, size: 50, color: AppColors.mutedGreen);
                            },
                          ),
                        )
                      : const Icon(Icons.image, size: 50, color: AppColors.sageGreen),
                ),
              ),
              const SizedBox(height: 12),
              // The product title
              Text(
                product.name,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}