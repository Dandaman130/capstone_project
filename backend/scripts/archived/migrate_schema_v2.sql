-- Migration Schema for Products Database
-- Removes dietary_rules table (now using confidence columns instead)

-- Drop old tables if they exist (clean slate)
DROP TABLE IF EXISTS product_ingredients CASCADE;
DROP TABLE IF EXISTS product_categories CASCADE;
DROP TABLE IF EXISTS dietary_rules CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS ingredients CASCADE;
DROP TABLE IF EXISTS categories CASCADE;

-- 1. Categories table with hierarchical structure
CREATE TABLE categories (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  parent_id INTEGER REFERENCES categories(id),
  level INTEGER NOT NULL DEFAULT 0,
  path TEXT[] NOT NULL DEFAULT '{}',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_categories_parent ON categories(parent_id);
CREATE INDEX IF NOT EXISTS idx_categories_level ON categories(level);

-- 2. Ingredients table with confidence scores
CREATE TABLE ingredients (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  normalized_name TEXT NOT NULL,
  is_vegan INTEGER DEFAULT -1,
  is_vegetarian INTEGER DEFAULT -1,
  is_gluten_free INTEGER DEFAULT -1,
  is_dairy_free INTEGER DEFAULT -1,
  allergen_tags TEXT[] DEFAULT '{}',
  vegan_confidence INTEGER DEFAULT 0,
  not_vegan_confidence INTEGER DEFAULT 0,
  vegetarian_confidence INTEGER DEFAULT 0,
  not_vegetarian_confidence INTEGER DEFAULT 0,
  gluten_free_confidence INTEGER DEFAULT 0,
  contains_gluten_confidence INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_ingredients_normalized ON ingredients(normalized_name);

-- 3. Products table
CREATE TABLE products (
  barcode TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  brand TEXT,
  image_url TEXT,
  is_vegan INTEGER DEFAULT -1,
  is_vegetarian INTEGER DEFAULT -1,
  is_gluten_free INTEGER DEFAULT -1,
  is_dairy_free INTEGER DEFAULT -1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  modified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_products_vegan ON products(is_vegan);
CREATE INDEX IF NOT EXISTS idx_products_vegetarian ON products(is_vegetarian);
CREATE INDEX IF NOT EXISTS idx_products_gluten_free ON products(is_gluten_free);

-- 4. Product-Category junction table (many-to-many)
CREATE TABLE product_categories (
  product_barcode TEXT REFERENCES products(barcode) ON DELETE CASCADE,
  category_id INTEGER REFERENCES categories(id) ON DELETE CASCADE,
  PRIMARY KEY (product_barcode, category_id)
);

CREATE INDEX IF NOT EXISTS idx_product_categories_category ON product_categories(category_id);

-- 5. Product-Ingredient junction table (many-to-many)
CREATE TABLE product_ingredients (
  product_barcode TEXT REFERENCES products(barcode) ON DELETE CASCADE,
  ingredient_id INTEGER REFERENCES ingredients(id) ON DELETE CASCADE,
  PRIMARY KEY (product_barcode, ingredient_id)
);

CREATE INDEX IF NOT EXISTS idx_product_ingredients_ingredient ON product_ingredients(ingredient_id);
