/*
Rate Limiter Service
Current State 12/15/25 Last Modified v(Alpha 2.3)

Implements rate limiting for API calls:
- Barcode scanning: 15 calls per minute
- Batch search: 10 calls per minute

TODO: When account system is implemented, replace getUserId()
      to return the actual user ID instead of "guest"
*/

import 'package:flutter/foundation.dart';

enum RateLimitType {
  barcodeScan,
  batchSearch,
}

class RateLimiterService {
  // Rate limit configurations
  static const int _barcodeScanLimit = 15; // calls per minute
  static const int _batchSearchLimit = 10; // calls per minute

  // Storage for tracking API calls per user
  // Key format: "userId_limitType"
  static final Map<String, List<DateTime>> _callHistory = {};

  // TODO: Replace this with actual user ID when account system is implemented
  static String getUserId() {
    // For now, using "guest" as placeholder
    // Future: return actual user ID from auth service
    return "guest";
  }

  /// Check if a user can make an API call based on rate limits
  /// Returns true if call is allowed, false if rate limit exceeded
  static bool canMakeCall(RateLimitType limitType) {
    final userId = getUserId();
    final limit = _getLimit(limitType);
    final key = '${userId}_${limitType.name}';

    // Get call history for this user and limit type
    final history = _callHistory[key] ?? [];

    // Remove calls older than 1 minute
    final now = DateTime.now();
    final oneMinuteAgo = now.subtract(const Duration(minutes: 1));
    history.removeWhere((callTime) => callTime.isBefore(oneMinuteAgo));

    // Check if under limit
    final remainingCalls = limit - history.length;
    final canCall = history.length < limit;

    if (kDebugMode) {
      print('═══════════════════════════════════════');
      print('📊 RATE LIMIT CHECK');
      print('───────────────────────────────────────');
      print('User ID: $userId');
      print('Type: ${_getLimitTypeName(limitType)}');
      print('Limit: $limit calls/minute');
      print('Calls in last minute: ${history.length}');
      print('Remaining calls: $remainingCalls');
      print('Status: ${canCall ? '✅ ALLOWED' : '❌ RATE LIMIT EXCEEDED'}');
      print('═══════════════════════════════════════');
    }

    return canCall;
  }

  /// Record an API call for rate limiting
  /// Call this AFTER successfully making an API call
  static void recordCall(RateLimitType limitType) {
    final userId = getUserId();
    final key = '${userId}_${limitType.name}';

    final history = _callHistory[key] ?? [];
    history.add(DateTime.now());
    _callHistory[key] = history;

    // Clean up old entries
    final oneMinuteAgo = DateTime.now().subtract(const Duration(minutes: 1));
    history.removeWhere((callTime) => callTime.isBefore(oneMinuteAgo));

    final limit = _getLimit(limitType);
    final remainingCalls = limit - history.length;

    if (kDebugMode) {
      print('═══════════════════════════════════════');
      print('✅ API CALL RECORDED');
      print('───────────────────────────────────────');
      print('User ID: $userId');
      print('Type: ${_getLimitTypeName(limitType)}');
      print('Total calls in last minute: ${history.length}/$limit');
      print('Remaining calls: $remainingCalls');
      print('═══════════════════════════════════════');
    }
  }

  /// Get remaining calls for a specific limit type
  static int getRemainingCalls(RateLimitType limitType) {
    final userId = getUserId();
    final limit = _getLimit(limitType);
    final key = '${userId}_${limitType.name}';

    final history = _callHistory[key] ?? [];

    // Remove calls older than 1 minute
    final oneMinuteAgo = DateTime.now().subtract(const Duration(minutes: 1));
    history.removeWhere((callTime) => callTime.isBefore(oneMinuteAgo));

    return limit - history.length;
  }

  /// Get the limit for a specific limit type
  static int _getLimit(RateLimitType limitType) {
    switch (limitType) {
      case RateLimitType.barcodeScan:
        return _barcodeScanLimit;
      case RateLimitType.batchSearch:
        return _batchSearchLimit;
    }
  }

  /// Get human-readable name for limit type
  static String _getLimitTypeName(RateLimitType limitType) {
    switch (limitType) {
      case RateLimitType.barcodeScan:
        return 'Barcode Scan';
      case RateLimitType.batchSearch:
        return 'Batch Search';
    }
  }

  /// Reset rate limits (useful for testing or when user logs out)
  static void resetLimits({String? userId}) {
    if (userId != null) {
      // Remove only this user's history
      final prefix = '${userId}_';
      _callHistory.removeWhere((key, _) => key.startsWith(prefix));
      if (kDebugMode) {
        print('🔄 Rate limits reset for user: $userId');
      }
    } else {
      // Remove all history
      _callHistory.clear();
      if (kDebugMode) {
        print('🔄 All rate limits reset');
      }
    }
  }
}

