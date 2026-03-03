/*
  FilteredProductsScreen
  Account home screen: displays Railway DB products filtered by the user's
  dietary restrictions and personal preferences. Tapping the filter icon
  opens PreferencesScreen.
*/

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../providers/preferences_provider.dart';
import '../screens/preferences_screen.dart';
import '../services/dietary_filter_service.dart';
import '../services/user_preferences_service.dart';
import '../theme/app_colors.dart';

class FilteredProductsScreen extends ConsumerStatefulWidget {
  const FilteredProductsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<FilteredProductsScreen> createState() =>
      _FilteredProductsScreenState();
}

class _FilteredProductsScreenState
    extends ConsumerState<FilteredProductsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openPreferences() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PreferencesScreen()),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filteredAsync  = ref.watch(filteredProductsProvider);
    final restAsync      = ref.watch(restrictionsProvider);
    final activeLabels   = restAsync.valueOrNull?.activeLabels ?? [];

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: const Text('My Products',
            style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.sageGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Filter badge: shows count of active dietary restrictions
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: const Icon(Icons.tune, color: Colors.white),
                tooltip: 'Dietary Preferences',
                onPressed: _openPreferences,
              ),
              if (activeLabels.isNotEmpty)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${activeLabels.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search bar ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) =>
              ref.read(searchQueryProvider.notifier).state = v,
              decoration: InputDecoration(
                hintText: 'Search products…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(searchQueryProvider.notifier).state = '';
                  },
                )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
              ),
            ),
          ),

          // ── Active filter chips ───────────────────────────────────────────
          if (activeLabels.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: activeLabels.map((label) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      label: Text(label,
                          style: const TextStyle(fontSize: 12)),
                      backgroundColor: AppColors.softMint,
                      side: BorderSide(color: AppColors.sageGreen),
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 4),

          // ── Product list ─────────────────────────────────────────────────
          Expanded(
            child: filteredAsync.when(
              loading: () =>
              const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(allProductsProvider),
              ),
              data: (products) => products.isEmpty
                  ? _EmptyView(
                hasFilters: activeLabels.isNotEmpty,
                onClearFilters: () => ref
                    .read(restrictionsProvider.notifier)
                    .save(const DietaryRestrictions()),
              )
                  : _ProductList(products: products),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Product List ───────────────────────────────────────────────────────────────

class _ProductList extends ConsumerWidget {
  final List<Product> products;
  const _ProductList({required this.products});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            '${products.length} product${products.length == 1 ? '' : 's'}',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: products.length,
            itemBuilder: (_, i) => _ProductCard(product: products[i]),
          ),
        ),
      ],
    );
  }
}

// ── Product Card ──────────────────────────────────────────────────────────────

class _ProductCard extends ConsumerWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDisliked = ref
        .watch(dislikedBarcodesProvider)
        .valueOrNull
        ?.contains(product.barcode) ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _ProductImage(imageUrl: product.imageUrl),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.brand != null && product.brand!.isNotEmpty)
              Text(product.brand!,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 4),
            _DietaryBadgeRow(product: product),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            isDisliked ? Icons.visibility_off : Icons.visibility_off_outlined,
            color: isDisliked ? Colors.red[300] : Colors.grey[400],
            size: 20,
          ),
          tooltip: isDisliked ? 'Unhide product' : 'Hide product',
          onPressed: () {
            if (isDisliked) {
              ref.read(dislikedBarcodesProvider.notifier).undislike(product.barcode);
            } else {
              ref.read(dislikedBarcodesProvider.notifier).dislike(product.barcode);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${product.name} hidden'),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () => ref
                        .read(dislikedBarcodesProvider.notifier)
                        .undislike(product.barcode),
                  ),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          },
        ),
        isThreeLine: true,
      ),
    );
  }
}

// ── Dietary badge row ─────────────────────────────────────────────────────────

class _DietaryBadgeRow extends StatelessWidget {
  final Product product;
  const _DietaryBadgeRow({required this.product});

  @override
  Widget build(BuildContext context) {
    final badges = <_Badge>[];

    if (product.isDefinitelyVegan)
      badges.add(const _Badge('🌱 Vegan', Colors.green));
    else if (product.isDefinitelyVegetarian)
      badges.add(const _Badge('🥦 Vegetarian', Colors.lightGreen));

    if (product.isDefinitelyGlutenFree)
      badges.add(const _Badge('🌾 GF', Colors.amber));

    if (product.isDefinitelyDairyFree)
      badges.add(const _Badge('🥛 DF', Colors.purple));

    // Unknown status indicator
    if (product.hasUnknownVeganStatus &&
        product.hasUnknownVegetarianStatus &&
        product.hasUnknownGlutenFreeStatus &&
        product.hasUnknownDairyFreeStatus) {
      badges.add(const _Badge('❓ Info limited', Colors.grey));
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 4,
      children: badges.map((b) => _buildChip(b)).toList(),
    );
  }

  Widget _buildChip(_Badge b) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: b.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: b.color.withOpacity(0.4)),
      ),
      child: Text(b.label,
          style: TextStyle(fontSize: 10, color: b.color.withOpacity(0.9))),
    );
  }
}

class _Badge {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);
}

// ── Product image ─────────────────────────────────────────────────────────────

class _ProductImage extends StatelessWidget {
  final String? imageUrl;
  const _ProductImage({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.inventory_2_outlined,
            color: Colors.grey[400], size: 28),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        imageUrl!,
        width: 52, height: 52, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 52, height: 52,
          color: Colors.grey[100],
          child: Icon(Icons.broken_image_outlined,
              color: Colors.grey[400], size: 28),
        ),
      ),
    );
  }
}

// ── Empty / Error views ───────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onClearFilters;
  const _EmptyView({required this.hasFilters, required this.onClearFilters});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_list_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              hasFilters
                  ? 'No products match your current filters.'
                  : 'No products found.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear Filters'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sageGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}