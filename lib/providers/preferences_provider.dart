/*
  preferences_provider.dart
  Riverpod providers that expose user preferences and filtered product lists
  to the rest of the app.

  Providers:
    restrictionsProvider        – AsyncNotifier<DietaryRestrictions>
    avoidedKeywordsProvider     – AsyncNotifier<List<String>>
    dislikedBarcodesProvider    – AsyncNotifier<Set<String>>
    filteredProductsProvider    – derived; filters Railway products
    filteredScannedProvider     – derived; filters ScannedProductCache
*/

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../models/scanned_product.dart';
import '../services/dietary_filter_service.dart';
import '../services/railway_api_service.dart';
import '../services/scanned_product_cache.dart';
import '../services/user_preferences_service.dart';

// ── Search query ──────────────────────────────────────────────────────────────
final searchQueryProvider = StateProvider<String>((ref) => '');

// ── Dietary restrictions ──────────────────────────────────────────────────────
class RestrictionsNotifier extends AsyncNotifier<DietaryRestrictions> {
  @override
  Future<DietaryRestrictions> build() async {
    return UserPreferencesService.loadRestrictions();
  }

  Future<void> save(DietaryRestrictions updated) async {
    await UserPreferencesService.saveRestrictions(updated);
    state = AsyncData(updated);
  }

  Future<void> toggle({
    bool? vegan,
    bool? vegetarian,
    bool? glutenFree,
    bool? dairyFree,
    bool? nutFree,
    bool? pescatarian,
    bool? showUnknown,
  }) async {
    final current = state.valueOrNull ?? const DietaryRestrictions();
    await save(current.copyWith(
      vegan: vegan,
      vegetarian: vegetarian,
      glutenFree: glutenFree,
      dairyFree: dairyFree,
      nutFree: nutFree,
      pescatarian: pescatarian,
      showUnknownProducts: showUnknown,
    ));
  }
}

final restrictionsProvider =
AsyncNotifierProvider<RestrictionsNotifier, DietaryRestrictions>(
  RestrictionsNotifier.new,
);

// ── Avoided keywords ──────────────────────────────────────────────────────────
class AvoidedKeywordsNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    return UserPreferencesService.loadAvoidedKeywords();
  }

  Future<void> add(String keyword) async {
    await UserPreferencesService.addAvoidedKeyword(keyword);
    state = AsyncData([...?state.valueOrNull, keyword.trim().toLowerCase()]);
  }

  Future<void> remove(String keyword) async {
    await UserPreferencesService.removeAvoidedKeyword(keyword);
    state = AsyncData(
      (state.valueOrNull ?? [])
          .where((k) => k != keyword.trim().toLowerCase())
          .toList(),
    );
  }
}

final avoidedKeywordsProvider =
AsyncNotifierProvider<AvoidedKeywordsNotifier, List<String>>(
  AvoidedKeywordsNotifier.new,
);

// ── Disliked barcodes ─────────────────────────────────────────────────────────
class DislikedBarcodesNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    return UserPreferencesService.loadDislikedBarcodes();
  }

  Future<void> dislike(String barcode) async {
    await UserPreferencesService.dislikeProduct(barcode);
    state = AsyncData({...?state.valueOrNull, barcode});
  }

  Future<void> undislike(String barcode) async {
    await UserPreferencesService.undislikeProduct(barcode);
    state = AsyncData(
      (state.valueOrNull ?? {}).where((b) => b != barcode).toSet(),
    );
  }

  bool isDisliked(String barcode) {
    return state.valueOrNull?.contains(barcode) ?? false;
  }
}

final dislikedBarcodesProvider =
AsyncNotifierProvider<DislikedBarcodesNotifier, Set<String>>(
  DislikedBarcodesNotifier.new,
);

// ── Raw Railway products ──────────────────────────────────────────────────────
final allProductsProvider = FutureProvider<List<Product>>((ref) async {
  return RailwayApiService.getAllProducts();
});

// ── Filtered Railway products ─────────────────────────────────────────────────
// ── Filtered Railway products ─────────────────────────────────────────────────
// Changed to FutureProvider for better AsyncValue handling
final filteredProductsProvider = FutureProvider<List<Product>>((ref) async {
  // We use .future or .value to ensure we aren't nesting AsyncValues
  final allProducts = await ref.watch(allProductsProvider.future);
  final rest        = await ref.watch(restrictionsProvider.future);
  final keywords    = await ref.watch(avoidedKeywordsProvider.future);
  final disliked    = await ref.watch(dislikedBarcodesProvider.future);
  final query       = ref.watch(searchQueryProvider);

  // The logic remains the same, but the return is a clean List<Product>
  return DietaryFilterService.filterProducts(
    products: allProducts,
    restrictions: rest,
    avoidedKeywords: keywords,
    dislikedBarcodes: disliked,
    searchQuery: query,
  );
});

// ── Filtered ScannedProduct list ──────────────────────────────────────────────
final filteredScannedProvider = Provider<List<ScannedProduct>>((ref) {
  final restAsync     = ref.watch(restrictionsProvider);
  final keywordsAsync = ref.watch(avoidedKeywordsProvider);
  final dislikedAsync = ref.watch(dislikedBarcodesProvider);
  final query         = ref.watch(searchQueryProvider);

  final rest      = restAsync.valueOrNull ?? const DietaryRestrictions();
  final keywords  = keywordsAsync.valueOrNull ?? [];
  final disliked  = dislikedAsync.valueOrNull ?? {};

  return DietaryFilterService.filterScannedProducts(
    products: ScannedProductCache.all,
    restrictions: rest,
    avoidedKeywords: keywords,
    dislikedBarcodes: disliked,
    searchQuery: query,
  );
});