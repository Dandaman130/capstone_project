import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../models/product.dart';
import '../models/scanned_product.dart';
import '../services/openfoodfacts_api.dart';
import '../services/railway_api_service.dart';
import '../services/scanned_product_cache.dart';
import 'product_detail_screen.dart';

final List<String> globalFavorites = [];

class _FavoriteDetails {
  final String barcode;
  final String name;
  final String subtitle;
  final String? imageUrl;
  final Product? railwayProduct;
  final ScannedProduct? scannedProduct;

  const _FavoriteDetails({
    required this.barcode,
    required this.name,
    required this.subtitle,
    this.imageUrl,
    this.railwayProduct,
    this.scannedProduct,
  });
}

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final Map<String, Future<_FavoriteDetails>> _favoriteDetailsCache = {};

  // ==================== DATA RESOLUTION ====================

  Future<_FavoriteDetails> _resolveFavoriteDetails(String barcode) async {
    // 1. Try Railway DB first
    final railwayProduct = await RailwayApiService.getProductByBarcode(barcode);
    if (railwayProduct != null) {
      return _FavoriteDetails(
        barcode: barcode,
        name: railwayProduct.name,
        subtitle: railwayProduct.brand?.isNotEmpty == true
            ? '${railwayProduct.brand} • $barcode'
            : barcode,
        imageUrl: railwayProduct.imageUrl,
        railwayProduct: railwayProduct,
      );
    }

    // 2. Try local scan cache
    final cachedProduct = ScannedProductCache.getByBarcode(barcode);
    if (cachedProduct != null) {
      return _FavoriteDetails(
        barcode: barcode,
        name: cachedProduct.name,
        subtitle: cachedProduct.brand.isNotEmpty
            ? '${cachedProduct.brand} • $barcode'
            : barcode,
        imageUrl: cachedProduct.imageUrl,
        scannedProduct: cachedProduct,
      );
    }

    // 3. Fall back to OpenFoodFacts API
    try {
      final productData = await OpenFoodFactsApi().fetchProduct(barcode);
      final scannedProduct = ScannedProduct.fromJson(barcode, productData);
      ScannedProductCache.addProduct(scannedProduct);

      return _FavoriteDetails(
        barcode: barcode,
        name: scannedProduct.name,
        subtitle: scannedProduct.brand.isNotEmpty
            ? '${scannedProduct.brand} • $barcode'
            : barcode,
        imageUrl: scannedProduct.imageUrl,
        scannedProduct: scannedProduct,
      );
    } catch (_) {
      return _FavoriteDetails(
        barcode: barcode,
        name: barcode,
        subtitle: 'Product details unavailable',
      );
    }
  }

  Future<_FavoriteDetails> _getFavoriteDetails(String barcode) {
    return _favoriteDetailsCache.putIfAbsent(
      barcode,
          () => _resolveFavoriteDetails(barcode),
    );
  }

  Future<void> _openFavorite(String barcode) async {
    final details = await _getFavoriteDetails(barcode);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          railwayProduct: details.railwayProduct,
          scannedProduct: details.scannedProduct,
        ),
      ),
    );
  }

  void _removeFavorite(int index, String barcode) {
    setState(() {
      globalFavorites.removeAt(index);
      _favoriteDetailsCache.remove(barcode);
    });
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Favorites',
          style: TextStyle(
            color: AppColors.parchment,
            fontWeight: FontWeight.w600,
            fontSize: 20,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: AppColors.forestDeep.withOpacity(0.85),
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.parchment),
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
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.forestDeep,
          image: DecorationImage(
            image: AssetImage('lib/theme/vinebg.png'),
            repeat: ImageRepeat.repeat,
            scale: 1.8,
            opacity: 0.18,
          ),
        ),
        child: SafeArea(
          child: globalFavorites.isEmpty
              ? _buildEmptyState()
              : _buildFavoritesList(),
        ),
      ),
    );
  }

  // ==================== EMPTY STATE ====================

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.favorite_border_rounded,
            size: 56,
            color: AppColors.mossGreen.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your favorites will bloom here.',
            style: TextStyle(
              color: AppColors.mistGreen,
              fontStyle: FontStyle.italic,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan or search for products to save them.',
            style: TextStyle(
              color: AppColors.fernGreen.withOpacity(0.6),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== FAVORITES LIST ====================

  Widget _buildFavoritesList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: globalFavorites.length,
      itemBuilder: (context, index) {
        final barcode = globalFavorites[index];
        return FutureBuilder<_FavoriteDetails>(
          future: _getFavoriteDetails(barcode),
          builder: (context, snapshot) {
            final details = snapshot.data;
            final isLoading = snapshot.connectionState == ConnectionState.waiting;

            return _buildFavoriteCard(
              index: index,
              barcode: barcode,
              details: details,
              isLoading: isLoading,
            );
          },
        );
      },
    );
  }

  Widget _buildFavoriteCard({
    required int index,
    required String barcode,
    required _FavoriteDetails? details,
    required bool isLoading,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.forestMid,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.mossGreen.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepShadow.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: details != null ? () => _openFavorite(barcode) : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // ── Product image ──
              _buildProductImage(details),
              const SizedBox(width: 14),

              // ── Product info ──
              Expanded(
                child: isLoading
                    ? _buildLoadingShimmer()
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      details?.name ?? barcode,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.parchment,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      details?.subtitle ?? 'Loading details...',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mistGreen.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Actions ──
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.agedGold.withOpacity(0.7),
                      size: 20,
                    ),
                    onPressed: () => _removeFavorite(index, barcode),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(height: 8),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppColors.fernGreen.withOpacity(0.5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductImage(_FavoriteDetails? details) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.mossGreen.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.mossGreen.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: details?.imageUrl != null && details!.imageUrl!.isNotEmpty
          ? ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          details.imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(
            Icons.inventory_2_outlined,
            color: AppColors.fernGreen.withOpacity(0.6),
            size: 28,
          ),
        ),
      )
          : Icon(
        Icons.inventory_2_outlined,
        color: AppColors.fernGreen.withOpacity(0.6),
        size: 28,
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 14,
          width: 120,
          decoration: BoxDecoration(
            color: AppColors.mossGreen.withOpacity(0.25),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 11,
          width: 80,
          decoration: BoxDecoration(
            color: AppColors.mossGreen.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}