# Root Categories Display Implementation Summary

## Overview
Changed the Search screen to display **root categories (top 10, most populated)** in a scrollable list instead of hardcoded "Snacks" and "Beverages" categories.

## Changes Made

### 1. **Backend API - `backend/scripts/index.js`**
- **Endpoint**: `/api/categories/root`
  - Fetches **root categories** (`parent_id IS NULL`)
  - Returns the **most populated** roots (ranked by distinct product count across the entire subtree: root + descendants)
  - Default limit: 10 categories
  - Response format: Array of category objects with `id`, `name`, `level`, `parent_id`, and `product_count`

**Endpoint Details:**
```
GET /api/categories/root?limit=10
Response: [
  { id: 1, name: "en:snacks", level: 0, parent_id: null, product_count: 194490 },
  ...
]
```

### 2. **Dart API Service - `lib/services/railway_api_service.dart`**
- **Added/updated**: `getRootCategories()`
  - Calls `/api/categories/root`
  - Returns a `List<String>` of category names (taken from `name` field)

- **Fix**: `getProductsByCategories()` now builds the URI using `queryParameters`
  - This properly URL-encodes category names that contain spaces/commas

### 3. **Flutter Search Screen - `lib/screens/search.dart`**
- Loads root categories via `getRootCategories(limit: 10)`
- Uses those categories for the batch products request
- Entire view is scrollable and supports pull-to-refresh

## Notes
- If you want **subcategory drill-down**, that should be driven by category IDs (via `/api/category-rows?parent_id=...`), not by tapping a product.
