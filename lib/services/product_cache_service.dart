/*
Current State 10/20/25 Last Modified v(beta 1.0)
Layered caching service: Memory Cache → Hive Cache → API
This service provides persistent caching with Hive and fast in-memory access
*/

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/scanned_product.dart';
import 'openfoodfacts_api.dart';

class ProductCacheService {
  // Layer 1: In-memory cache for ultra-fast lookups during app session
  static final Map<String, ScannedProduct> _memoryCache = {};

  // Hive box name for persistent storage
  static const String _boxName = 'products';

  // Cache expiration duration (set to null for no expiration)
  static const Duration? cacheExpiration = Duration(days: 30);

  /// Initialize Hive and register adapter - MUST be called before app runs
  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(ScannedProductAdapter());
    await Hive.openBox<ScannedProduct>(_boxName);
    debugPrint('✓ Hive initialized and products box opened');
  }

  /// Get product with layered caching: Memory → Hive → API
  static Future<ScannedProduct> getProduct(String barcode) async {
    // Layer 1: Check in-memory cache first (fastest)
    if (_memoryCache.containsKey(barcode)) {
      debugPrint('✓ [MEMORY CACHE] Found: $barcode');
      return _memoryCache[barcode]!;
    }

    // Layer 2: Check Hive persistent cache
    final box = Hive.box<ScannedProduct>(_boxName);
    final hiveCached = box.get(barcode);

    if (hiveCached != null) {
      // Check if cache is expired (optional)
      if (cacheExpiration != null) {
        final age = DateTime.now().difference(hiveCached.cachedAt);
        if (age > cacheExpiration!) {
          debugPrint('⚠ [HIVE CACHE] Expired (${age.inDays} days old): $barcode');
          await box.delete(barcode); // Remove stale data
        } else {
          debugPrint('✓ [HIVE CACHE] Found: $barcode (${age.inDays} days old)');
          _memoryCache[barcode] = hiveCached; // Promote to memory cache
          return hiveCached;
        }
      } else {
        debugPrint('✓ [HIVE CACHE] Found: $barcode');
        _memoryCache[barcode] = hiveCached; // Promote to memory cache
        return hiveCached;
      }
    }

    // Layer 3: Fetch from OpenFoodFacts API (slowest)
    debugPrint('⟳ [API CALL] Fetching from OpenFoodFacts: $barcode');
    final api = OpenFoodFactsApi();
    final productData = await api.fetchProduct(barcode);
    final product = ScannedProduct.fromJson(barcode, productData);

    // Store in both caches for future use
    await _saveToCache(product);

    return product;
  }

  /// Save product to both memory and Hive cache
  static Future<void> _saveToCache(ScannedProduct product) async {
    // Save to memory cache
    _memoryCache[product.barcode] = product;

    // Save to Hive persistent cache
    final box = Hive.box<ScannedProduct>(_boxName);
    await box.put(product.barcode, product);

    debugPrint('✓ [CACHE SAVED] ${product.name} (${product.barcode}) → Memory + Hive');
  }

  /// Get all cached products from Hive (for viewing history)
  static List<ScannedProduct> getAllCached() {
    final box = Hive.box<ScannedProduct>(_boxName);
    return box.values.toList();
  }

  /// Get cache statistics
  static Map<String, int> getCacheStats() {
    final box = Hive.box<ScannedProduct>(_boxName);
    return {
      'memoryCount': _memoryCache.length,
      'hiveCount': box.length,
    };
  }

  /// Clear all caches (memory + Hive)
  static Future<void> clearAllCaches() async {
    _memoryCache.clear();
    final box = Hive.box<ScannedProduct>(_boxName);
    await box.clear();
    debugPrint('✓ All caches cleared (Memory + Hive)');
  }

  /// Clear only memory cache (keeps Hive intact)
  static void clearMemoryCache() {
    _memoryCache.clear();
    debugPrint('✓ Memory cache cleared');
  }

  /// Delete specific product from all caches
  static Future<void> deleteProduct(String barcode) async {
    _memoryCache.remove(barcode);
    final box = Hive.box<ScannedProduct>(_boxName);
    await box.delete(barcode);
    debugPrint('✓ Deleted from all caches: $barcode');
  }
}

