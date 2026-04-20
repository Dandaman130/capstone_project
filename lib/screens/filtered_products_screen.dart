/*
  FilteredProductsScreen - Botanical Refactor
  Displays Railway DB products filtered by dietary restrictions.
  Integrated with central AppColors and vine background.
*/

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../providers/preferences_provider.dart';
import '../screens/preferences_screen.dart';
import '../services/user_preferences_service.dart'; // Direct access to DietaryRestrictions
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

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

  @override
  Widget build(BuildContext context) {
    final filteredAsync = ref.watch(filteredProductsProvider);
    final restAsync     = ref.watch(restrictionsProvider);
    final activeLabels  = restAsync.valueOrNull?.activeLabels ?? [];

    return Scaffold(
      backgroundColor: AppColors.forestDeep,
      appBar: AppBar(
        title: const Text('My Products', style: TextStyle(color: AppColors.parchment)),
        backgroundColor: AppColors.forestDeep,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.parchment),
        actions: [
          _buildFilterBadge(activeLabels),
        ],
      ),
      body: Container(
        decoration: AppTheme.vineBackground,
        child: Column(
          children: [
            // ── Search bar ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: AppColors.parchment),
                onChanged: (v) => ref.read(searchQueryProvider.notifier).state = v,
                decoration: InputDecoration(
                  hintText: 'Search products…',
                  hintStyle: TextStyle(color: AppColors.mossGreen.withOpacity(0.7)),
                  prefixIcon: const Icon(Icons.search, color: AppColors.mossGreen),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear, color: AppColors.mossGreen),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(searchQueryProvider.notifier).state = '';
                    },
                  )
                      : null,
                  filled: true,
                  fillColor: AppColors.forestMid.withOpacity(0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.mossGreen.withOpacity(0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.agedGold),
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
                        label: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.parchment)),
                        backgroundColor: AppColors.mossGreen.withOpacity(0.3),
                        side: BorderSide(color: AppColors.mossGreen.withOpacity(0.5)),
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
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.agedGold)),
                error: (e, _) => _ErrorView(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(allProductsProvider),
                ),
                data: (List<Product> products) => products.isEmpty
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
      ),
    );
  }

  Widget _buildFilterBadge(List<String> activeLabels) {
    return Stack(
      alignment: Alignment.topRight,
      children: [
        IconButton(
          icon: const Icon(Icons.tune, color: AppColors.parchment),
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
                color: AppColors.agedGold,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${activeLabels.length}',
                  style: const TextStyle(
                      color: AppColors.forestDeep,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Product List ───────────────────────────────────────────────────────────────

class _ProductList extends StatelessWidget {
  final List<Product> products;
  const _ProductList({Key? key, required this.products}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            '${products.length} product${products.length == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 13, color: AppColors.mistGreen),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
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
  const _ProductCard({Key? key, required this.product}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDisliked = ref.watch(dislikedBarcodesProvider).valueOrNull?.contains(product.barcode) ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: AppColors.forestMid.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.mossGreen.withOpacity(0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: _ProductImage(imageUrl: product.imageUrl),
        title: Text(
          product.name,
          style: const TextStyle(color: AppColors.parchment, fontWeight: FontWeight.w600, fontSize: 15),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.brand != null && product.brand!.isNotEmpty)
              Text(product.brand!, style: const TextStyle(fontSize: 12, color: AppColors.fernGreen)),
            const SizedBox(height: 6),
            _DietaryBadgeRow(product: product),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            isDisliked ? Icons.visibility_off : Icons.visibility_outlined,
            color: isDisliked ? AppColors.agedGold : AppColors.mossGreen.withOpacity(0.6),
            size: 20,
          ),
          onPressed: () {
            if (isDisliked) {
              ref.read(dislikedBarcodesProvider.notifier).undislike(product.barcode);
            } else {
              ref.read(dislikedBarcodesProvider.notifier).dislike(product.barcode);
            }
          },
        ),
      ),
    );
  }
}

// ── Helper Widgets (Badges, Images, Error, Empty) ──────────────────────────

class _DietaryBadgeRow extends StatelessWidget {
  final Product product;
  const _DietaryBadgeRow({required this.product});

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[];
    if (product.isDefinitelyVegan) badges.add(_buildBadge('Vegan'));
    if (product.isDefinitelyGlutenFree) badges.add(_buildBadge('GF'));
    if (product.isDefinitelyDairyFree) badges.add(_buildBadge('DF'));

    if (badges.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 4, children: badges);
  }

  Widget _buildBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.mossGreen.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.mossGreen.withOpacity(0.4)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 9, color: AppColors.mistGreen, fontWeight: FontWeight.bold)),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String? imageUrl;
  const _ProductImage({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
        color: AppColors.forestDeep,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.mossGreen.withOpacity(0.2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: (imageUrl != null && imageUrl!.isNotEmpty)
            ? Image.network(imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.eco, color: AppColors.mossGreen))
            : const Icon(Icons.bakery_dining, color: AppColors.mossGreen),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onClearFilters;
  const _EmptyView({required this.hasFilters, required this.onClearFilters});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.filter_list_off, size: 64, color: AppColors.mossGreen),
          const SizedBox(height: 16),
          const Text('No matches found.', style: TextStyle(color: AppColors.parchment, fontSize: 16)),
          if (hasFilters)
            TextButton(onPressed: onClearFilters, child: const Text('Clear Filters', style: TextStyle(color: AppColors.agedGold))),
        ],
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
          const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: AppColors.parchment)),
          TextButton(onPressed: onRetry, child: const Text('Retry', style: TextStyle(color: AppColors.agedGold))),
        ],
      ),
    );
  }
}