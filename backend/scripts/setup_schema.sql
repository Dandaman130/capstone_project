-- ============================================================
-- setup_schema.sql  (v5 — 3-table, simplified)
-- Drops and recreates the 3 working tables.
-- products_old is NOT touched — it is the source of truth backup.
--
-- Diet tags (is_vegan etc.) are read from OFF's labels_tags /
-- ingredients_analysis_tags during migration and stored per product.
-- Full ingredient lists are fetched live from the OFF API by the app.
-- ============================================================

-- Drop in dependency order (junction tables first, then ingredients which is now unused)
DROP TABLE IF EXISTS product_ingredients  CASCADE;
DROP TABLE IF EXISTS product_categories   CASCADE;
DROP TABLE IF EXISTS ingredients          CASCADE;
DROP TABLE IF EXISTS categories           CASCADE;
DROP TABLE IF EXISTS products             CASCADE;

-- ------------------------------------------------------------
-- 1. products
--    Compact result card per product.
--    id  — surrogate PK used by junction tables (4-byte int).
--    barcode — public identifier used by barcode scanner & API.
--    is_* — SMALLINT: 1 yes, 0 no, -1 unknown.
-- ------------------------------------------------------------
CREATE TABLE products (
  id             SERIAL        PRIMARY KEY,
  barcode        VARCHAR(50)   NOT NULL UNIQUE,
  name           VARCHAR(500),
  brand          VARCHAR(200),
  -- image_url is NOT stored — reconstructed from barcode at query time:
  -- https://images.openfoodfacts.org/images/products/<3>/<3>/<3>/<4>/1.jpg
  -- Saves ~80 bytes/row = ~320 MB at 4M products.
  is_vegan       SMALLINT      DEFAULT -1 CHECK (is_vegan       IN (-1, 0, 1)),
  is_vegetarian  SMALLINT      DEFAULT -1 CHECK (is_vegetarian  IN (-1, 0, 1)),
  is_gluten_free SMALLINT      DEFAULT -1 CHECK (is_gluten_free IN (-1, 0, 1)),
  is_dairy_free  SMALLINT      DEFAULT -1 CHECK (is_dairy_free  IN (-1, 0, 1))
);

-- barcode lookup is the primary API access pattern
CREATE INDEX idx_products_barcode      ON products(barcode);
-- diet-filter queries (search screen)
CREATE INDEX idx_products_vegan        ON products(is_vegan);
CREATE INDEX idx_products_vegetarian   ON products(is_vegetarian);
CREATE INDEX idx_products_gluten_free  ON products(is_gluten_free);
CREATE INDEX idx_products_dairy_free   ON products(is_dairy_free);

-- ------------------------------------------------------------
-- 2. categories
--    Hierarchical groupings for search tab and search results.
--    parent_id enables tree traversal via recursive CTE.
--    path array removed — saves ~150 bytes/row and is redundant
--    with parent_id for all practical query patterns.
-- ------------------------------------------------------------
CREATE TABLE categories (
  id        SERIAL       PRIMARY KEY,
  name      VARCHAR(500) NOT NULL UNIQUE,
  parent_id INTEGER      REFERENCES categories(id),
  level     SMALLINT     NOT NULL DEFAULT 0
);

CREATE INDEX idx_categories_parent ON categories(parent_id);
CREATE INDEX idx_categories_level  ON categories(level);

-- ------------------------------------------------------------
-- 3. product_categories  (many-to-many junction)
--    Both columns are 4-byte ints → 8 bytes/row.
-- ------------------------------------------------------------
CREATE TABLE product_categories (
  product_id  INTEGER NOT NULL REFERENCES products(id)   ON DELETE CASCADE,
  category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  PRIMARY KEY (product_id, category_id)
);

-- category_id index enables "all products in category X" queries
CREATE INDEX idx_pc_category_id ON product_categories(category_id);
