/*
  DietaryFilterService
  Pure, stateless filter logic.

  Works with both:
    • Product          – Railway DB model (has is_vegan / is_vegetarian etc. int flags)
    • ScannedProduct   – OpenFoodFacts model (has raw ingredients string)

  Nut-free detection uses keyword matching against the ingredients string because
  neither the Railway schema nor OpenFoodFacts provides a dedicated nut flag.
*/

import '../models/product.dart';
import '../models/scanned_product.dart';
import 'user_preferences_service.dart';

// Common nut-related terms for keyword matching
const List<String> _nutKeywords = [
  'almond', 'almonds',
  'cashew', 'cashews',
  'walnut', 'walnuts',
  'pecan', 'pecans',
  'pistachio', 'pistachios',
  'hazelnut', 'hazelnuts',
  'macadamia',
  'brazil nut', 'brazil nuts',
  'pine nut', 'pine nuts',
  'peanut', 'peanuts',   // technically legume but commonly grouped
  'tree nut', 'tree nuts',
  'nut',                 // catch-all — intentionally broad
];

class FilterResult {
  /// The product passed all active filters.
  final bool passes;

  /// Human-readable reasons the product was excluded (empty when passes == true).
  final List<String> failReasons;

  const FilterResult({required this.passes, this.failReasons = const []});
}

class DietaryFilterService {
  // ── Railway Product filtering ──────────────────────────────────────────────

  /// Filters a list of [Product] objects from the Railway database.
  static List<Product> filterProducts({
    required List<Product> products,
    required DietaryRestrictions restrictions,
    required List<String> avoidedKeywords,
    required Set<String> dislikedBarcodes,
    String searchQuery = '',
  }) {
    return products.where((p) {
      final result = evaluateProduct(
        product: p,
        restrictions: restrictions,
        avoidedKeywords: avoidedKeywords,
        dislikedBarcodes: dislikedBarcodes,
      );
      if (!result.passes) return false;
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        return (p.name.toLowerCase().contains(q)) ||
            (p.brand?.toLowerCase().contains(q) ?? false) ||
            (p.categories.toLowerCase().contains(q));
      }
      return true;
    }).toList();
  }

  /// Evaluates a single [Product] against all active filters.
  static FilterResult evaluateProduct({
    required Product product,
    required DietaryRestrictions restrictions,
    required List<String> avoidedKeywords,
    required Set<String> dislikedBarcodes,
  }) {
    final reasons = <String>[];

    // ── Disliked / hidden by user ──────────────────────────────────────────
    if (dislikedBarcodes.contains(product.barcode)) {
      return const FilterResult(passes: false, failReasons: ['Hidden by user']);
    }

    // ── Dietary restriction flags ──────────────────────────────────────────
    if (restrictions.vegan) {
      if (product.isVegan == 0) {
        reasons.add('Not vegan');
      } else if (product.isVegan == -1 || product.isVegan == null) {
        if (!restrictions.showUnknownProducts) reasons.add('Vegan status unknown');
      }
    }

    if (restrictions.vegetarian) {
      if (product.isVegetarian == 0) {
        reasons.add('Not vegetarian');
      } else if (product.isVegetarian == -1 || product.isVegetarian == null) {
        if (!restrictions.showUnknownProducts) reasons.add('Vegetarian status unknown');
      }
    }

    if (restrictions.glutenFree) {
      if (product.isGlutenFree == 0) {
        reasons.add('Contains gluten');
      } else if (product.isGlutenFree == -1 || product.isGlutenFree == null) {
        if (!restrictions.showUnknownProducts) reasons.add('Gluten-free status unknown');
      }
    }

    if (restrictions.dairyFree) {
      if (product.isDairyFree == 0) {
        reasons.add('Contains dairy');
      } else if (product.isDairyFree == -1 || product.isDairyFree == null) {
        if (!restrictions.showUnknownProducts) reasons.add('Dairy-free status unknown');
      }
    }

    // Nut-free uses category string since there's no DB flag
    if (restrictions.nutFree) {
      final cats = product.categories.toLowerCase();
      final nutFound = _nutKeywords.any((n) => cats.contains(n));
      if (nutFound) reasons.add('May contain nuts');
    }

    // Pescatarian: product passes if vegan OR vegetarian OR contains fish/seafood.
    // We approximate by checking category names.
    if (restrictions.pescatarian && !restrictions.vegan && !restrictions.vegetarian) {
      final cats = product.categories.toLowerCase();
      final isPlantBased = product.isVegetarian == 1 || product.isVegan == 1;
      final isSeafood = cats.contains('fish') ||
          cats.contains('seafood') ||
          cats.contains('shellfish');
      if (!isPlantBased && !isSeafood) {
        reasons.add('Not pescatarian-friendly');
      }
    }

    // ── Custom avoided keywords (matched against category string) ──────────
    for (final keyword in avoidedKeywords) {
      if (product.categories.toLowerCase().contains(keyword)) {
        reasons.add('Contains avoided ingredient: $keyword');
        break;
      }
    }

    return FilterResult(passes: reasons.isEmpty, failReasons: reasons);
  }

  // ── ScannedProduct filtering ───────────────────────────────────────────────

  /// Filters a list of [ScannedProduct] objects (OpenFoodFacts).
  static List<ScannedProduct> filterScannedProducts({
    required List<ScannedProduct> products,
    required DietaryRestrictions restrictions,
    required List<String> avoidedKeywords,
    required Set<String> dislikedBarcodes,
    String searchQuery = '',
  }) {
    return products.where((p) {
      final result = evaluateScannedProduct(
        product: p,
        restrictions: restrictions,
        avoidedKeywords: avoidedKeywords,
        dislikedBarcodes: dislikedBarcodes,
      );
      if (!result.passes) return false;
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        return p.name.toLowerCase().contains(q) ||
            p.brand.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  /// Evaluates a single [ScannedProduct] against all active filters.
  /// Falls back to ingredient-string keyword matching since OpenFoodFacts
  /// does not always expose structured dietary flags.
  static FilterResult evaluateScannedProduct({
    required ScannedProduct product,
    required DietaryRestrictions restrictions,
    required List<String> avoidedKeywords,
    required Set<String> dislikedBarcodes,
  }) {
    final reasons = <String>[];
    final ingredientsLower = product.ingredients.toLowerCase();

    if (dislikedBarcodes.contains(product.barcode)) {
      return const FilterResult(passes: false, failReasons: ['Hidden by user']);
    }

    // Meat / animal product indicators for vegan/vegetarian checks
    const meatTerms   = ['chicken', 'beef', 'pork', 'lamb', 'turkey', 'bacon',
      'ham', 'gelatin', 'lard', 'tallow', 'anchovies'];
    const dairyTerms  = ['milk', 'cream', 'butter', 'cheese', 'whey', 'casein',
      'lactose', 'yogurt', 'ghee'];
    const glutenTerms = ['wheat', 'barley', 'rye', 'spelt', 'kamut', 'semolina',
      'flour', 'gluten', 'malt'];

    if (restrictions.vegan) {
      final hasMeat  = meatTerms.any((t) => ingredientsLower.contains(t));
      final hasDairy = dairyTerms.any((t) => ingredientsLower.contains(t));
      final hasEgg   = ingredientsLower.contains('egg');
      final hasHoney = ingredientsLower.contains('honey');
      if (hasMeat || hasDairy || hasEgg || hasHoney) {
        reasons.add('Not vegan (animal products detected in ingredients)');
      }
    }

    if (restrictions.vegetarian && !restrictions.vegan) {
      final hasMeat = meatTerms.any((t) => ingredientsLower.contains(t));
      if (hasMeat) reasons.add('Not vegetarian (meat detected in ingredients)');
    }

    if (restrictions.glutenFree) {
      final hasGluten = glutenTerms.any((t) => ingredientsLower.contains(t));
      if (hasGluten) reasons.add('Contains gluten');
    }

    if (restrictions.dairyFree) {
      final hasDairy = dairyTerms.any((t) => ingredientsLower.contains(t));
      if (hasDairy) reasons.add('Contains dairy');
    }

    if (restrictions.nutFree) {
      final hasNuts = _nutKeywords.any((n) => ingredientsLower.contains(n));
      if (hasNuts) reasons.add('May contain nuts');
    }

    // Custom avoided keywords
    for (final keyword in avoidedKeywords) {
      if (ingredientsLower.contains(keyword)) {
        reasons.add('Contains avoided ingredient: $keyword');
        break;
      }
    }

    return FilterResult(passes: reasons.isEmpty, failReasons: reasons);
  }
}