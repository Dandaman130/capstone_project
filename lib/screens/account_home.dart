/*
  AccountHomePage - v(Alpha 2.5)
  Post-login home screen featuring a personalized botanical theme,
  dietary filter chips, and a filtered product list from Railway.
*/

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Models
import '../models/account_login.dart';
import '../models/account_gate.dart';
import '../models/session_manager.dart';
import '../models/product.dart';
import '../services/user_preferences_service.dart'; // Ensure this matches your model file name

// State & Services
import '../providers/preferences_provider.dart';
import '../screens/preferences_screen.dart';

// Theme
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class AccountHomePage extends ConsumerStatefulWidget {
  final AccountLogin user;

  const AccountHomePage({Key? key, required this.user}) : super(key: key);

  @override
  ConsumerState<AccountHomePage> createState() => _AccountHomePageState();
}

class _AccountHomePageState extends ConsumerState<AccountHomePage> {
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

  void _logout() {
    SessionManager.logout();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AccountGate()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watching the providers
    final filteredAsync = ref.watch(filteredProductsProvider);
    final restAsync     = ref.watch(restrictionsProvider);
    final activeLabels  = restAsync.valueOrNull?.activeLabels ?? [];

    return Scaffold(
      backgroundColor: AppColors.forestDeep,
      appBar: AppBar(
        backgroundColor: AppColors.forestDeep,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'My Account',
          style: TextStyle(
            color: AppColors.parchment,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.parchment),
        actions: [
          _buildPreferencesButton(activeLabels),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: Container(
        decoration: AppTheme.vineBackground,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGreetingSection(activeLabels),
            _buildSearchBar(),
            const SizedBox(height: 12),
            _buildFilterChips(activeLabels),
            const SizedBox(height: 8),

            // ── Main Content Area ───────────────────────────────────────────
            Expanded(
              child: filteredAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.agedGold),
                ),
                error: (e, stack) => _ErrorView(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(allProductsProvider),
                ),
                data: (List<Product> products) {
                  if (products.isEmpty) {
                    return _EmptyView(
                      hasFilters: activeLabels.isNotEmpty,
                      onClearFilters: () => ref
                          .read(restrictionsProvider.notifier)
                          .save(const DietaryRestrictions()),
                    );
                  }
                  return _ProductList(products: products);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== UI COMPONENTS ====================

  Widget _buildPreferencesButton(List<String> activeLabels) {
    return Stack(
      alignment: Alignment.topRight,
      children: [
        IconButton(
          icon: const Icon(Icons.tune_rounded),
          tooltip: 'Dietary Preferences',
          onPressed: _openPreferences,
        ),
        if (activeLabels.isNotEmpty)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: AppColors.agedGold,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
              child: Text(
                '${activeLabels.length}',
                style: const TextStyle(
                  color: AppColors.forestDeep,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGreetingSection(List<String> activeLabels) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, ${widget.user.username}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.parchment,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            activeLabels.isEmpty
                ? 'Showing all items'
                : 'Filters active: ${activeLabels.join(", ")}',
            style: const TextStyle(fontSize: 13, color: AppColors.mistGreen),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: AppColors.parchment),
        onChanged: (v) => ref.read(searchQueryProvider.notifier).state = v,
        decoration: InputDecoration(
          hintText: 'Search your safe products...',
          hintStyle: TextStyle(color: AppColors.fernGreen.withOpacity(0.6)),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.mossGreen),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.mossGreen),
            onPressed: () {
              _searchController.clear();
              ref.read(searchQueryProvider.notifier).state = '';
            },
          )
              : null,
          filled: true,
          fillColor: AppColors.forestMid.withOpacity(0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.mossGreen.withOpacity(0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.agedGold, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(List<String> activeLabels) {
    if (activeLabels.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: activeLabels.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              label: Text(
                activeLabels[index],
                style: const TextStyle(color: AppColors.parchment, fontSize: 12),
              ),
              backgroundColor: AppColors.mossGreen.withOpacity(0.3),
              side: BorderSide(color: AppColors.mossGreen.withOpacity(0.5)),
              deleteIcon: const Icon(Icons.cancel_rounded, size: 16, color: AppColors.agedGold),
              onDeleted: () {
                // Clear all for now, or implement specific toggle logic
                ref.read(restrictionsProvider.notifier).save(const DietaryRestrictions());
              },
            ),
          );
        },
      ),
    );
  }
}

// ── PRODUCT LIST WIDGETS ──────────────────────────────────────────────────────

class _ProductList extends StatelessWidget {
  final List<Product> products;
  const _ProductList({Key? key, required this.products}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            '${products.length} Items Found',
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.mistGreen,
                fontWeight: FontWeight.w600
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            // FIX: This is likely where 'bottom' was incorrectly placed.
            // Use padding: EdgeInsets.only(bottom: 24) instead of bottom: 24.
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
            itemCount: products.length,
            itemBuilder: (_, i) => _ProductCard(product: products[i]),
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final Product product;
  const _ProductCard({Key? key, required this.product}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDisliked = ref.watch(dislikedBarcodesProvider).valueOrNull?.contains(product.barcode) ?? false;

    return Card(
      // Ensure there is only ONE closing parenthesis after 12.0
      margin: EdgeInsets.only(bottom: 12.0),
      color: AppColors.forestMid.withOpacity(0.4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.mossGreen.withOpacity(0.2)),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(12),
        leading: _ProductImage(imageUrl: product.imageUrl),
        title: Text(
          product.name,
          style: TextStyle(
            color: AppColors.parchment,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: EdgeInsets.only(top: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product.brand != null)
                Text(
                  product.brand!,
                  style: TextStyle(color: AppColors.fernGreen, fontSize: 12),
                ),
              const SizedBox(height: 6),
              _DietaryBadgeRow(product: product),
            ],
          ),
        ),
        trailing: IconButton(
          icon: Icon(
            isDisliked ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: isDisliked ? AppColors.agedGold : AppColors.fernGreen.withOpacity(0.5),
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

class _DietaryBadgeRow extends StatelessWidget {
  final Product product;
  const _DietaryBadgeRow({required this.product});

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[];
    if (product.isDefinitelyVegan) badges.add(_badge('Vegan'));
    if (product.isDefinitelyGlutenFree) badges.add(_badge('GF'));
    if (product.isDefinitelyDairyFree) badges.add(_badge('DF'));

    return Wrap(spacing: 4, runSpacing: 4, children: badges);
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.mossGreen.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.mossGreen.withOpacity(0.4)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.mistGreen, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String? imageUrl;
  const _ProductImage({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.forestDeep,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.mossGreen.withOpacity(0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: (imageUrl != null && imageUrl!.isNotEmpty)
            ? Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.eco_rounded, color: AppColors.mossGreen),
        )
            : const Icon(Icons.bakery_dining_rounded, color: AppColors.mossGreen),
      ),
    );
  }
}

// ── EMPTY & ERROR STATES ──────────────────────────────────────────────────────

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
          Icon(Icons.search_off_rounded, size: 64, color: AppColors.mossGreen.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text(
            'No matching products found.',
            style: TextStyle(color: AppColors.parchment, fontSize: 16),
          ),
          if (hasFilters)
            TextButton(
              onPressed: onClearFilters,
              child: const Text('Clear all filters', style: TextStyle(color: AppColors.agedGold)),
            ),
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
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              'Connection Error',
              style: TextStyle(color: AppColors.parchment, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mistGreen),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.agedGold),
              child: const Text('Try Again', style: TextStyle(color: AppColors.forestDeep)),
            ),
          ],
        ),
      ),
    );
  }
}