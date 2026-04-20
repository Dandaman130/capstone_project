-- ============================================
-- PostgreSQL Schema Migration Script
-- Creates new normalized product database schema
-- ============================================

BEGIN;

-- ============================================
-- 1. CREATE NEW TABLES
-- ============================================

-- Categories table (hierarchical)
CREATE TABLE IF NOT EXISTS categories (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    parent_id INTEGER REFERENCES categories(id),
    level INTEGER NOT NULL DEFAULT 0,
    path TEXT[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_categories_parent ON categories(parent_id);
CREATE INDEX IF NOT EXISTS idx_categories_name ON categories(name);
CREATE INDEX IF NOT EXISTS idx_categories_path ON categories USING GIN(path);

-- Ingredients table
CREATE TABLE IF NOT EXISTS ingredients (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    normalized_name TEXT NOT NULL,
    is_vegan INTEGER DEFAULT -1 CHECK (is_vegan IN (-1, 0, 1)),
    is_vegetarian INTEGER DEFAULT -1 CHECK (is_vegetarian IN (-1, 0, 1)),
    is_gluten_free INTEGER DEFAULT -1 CHECK (is_gluten_free IN (-1, 0, 1)),
    is_dairy_free INTEGER DEFAULT -1 CHECK (is_dairy_free IN (-1, 0, 1)),
    allergen_tags TEXT[] DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ingredients_name ON ingredients(name);
CREATE INDEX IF NOT EXISTS idx_ingredients_normalized ON ingredients(normalized_name);
CREATE INDEX IF NOT EXISTS idx_ingredients_vegan ON ingredients(is_vegan);
CREATE INDEX IF NOT EXISTS idx_ingredients_vegetarian ON ingredients(is_vegetarian);

-- New products table with barcode as PK
CREATE TABLE IF NOT EXISTS products_new (
    barcode TEXT PRIMARY KEY,
    name TEXT,
    brand TEXT,
    image_url TEXT,
    is_vegan INTEGER DEFAULT -1 CHECK (is_vegan IN (-1, 0, 1)),
    is_vegetarian INTEGER DEFAULT -1 CHECK (is_vegetarian IN (-1, 0, 1)),
    is_gluten_free INTEGER DEFAULT -1 CHECK (is_gluten_free IN (-1, 0, 1)),
    is_dairy_free INTEGER DEFAULT -1 CHECK (is_dairy_free IN (-1, 0, 1)),
    created_at TIMESTAMP DEFAULT NOW(),
    modified_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_products_name ON products_new(name);
CREATE INDEX IF NOT EXISTS idx_products_brand ON products_new(brand);

-- Product-Categories junction table
CREATE TABLE IF NOT EXISTS product_categories (
    product_barcode TEXT REFERENCES products_new(barcode) ON DELETE CASCADE,
    category_id INTEGER REFERENCES categories(id) ON DELETE CASCADE,
    PRIMARY KEY (product_barcode, category_id)
);

CREATE INDEX IF NOT EXISTS idx_product_categories_barcode ON product_categories(product_barcode);
CREATE INDEX IF NOT EXISTS idx_product_categories_category ON product_categories(category_id);

-- Product-Ingredients junction table
CREATE TABLE IF NOT EXISTS product_ingredients (
    product_barcode TEXT REFERENCES products_new(barcode) ON DELETE CASCADE,
    ingredient_id INTEGER REFERENCES ingredients(id) ON DELETE CASCADE,
    PRIMARY KEY (product_barcode, ingredient_id)
);

CREATE INDEX IF NOT EXISTS idx_product_ingredients_barcode ON product_ingredients(product_barcode);
CREATE INDEX IF NOT EXISTS idx_product_ingredients_ingredient ON product_ingredients(ingredient_id);

-- Dietary rules table
CREATE TABLE IF NOT EXISTS dietary_rules (
    id SERIAL PRIMARY KEY,
    diet_type VARCHAR(50) NOT NULL,
    ingredient_pattern VARCHAR(255) NOT NULL,
    rule_type VARCHAR(20) NOT NULL CHECK (rule_type IN ('low', 'med', 'high')),
    confidence_impact VARCHAR(50) NOT NULL,
    notes TEXT[],
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_dietary_rules_diet ON dietary_rules(diet_type);
CREATE INDEX IF NOT EXISTS idx_dietary_rules_pattern ON dietary_rules(ingredient_pattern);

-- ============================================
-- 2. SEED DIETARY RULES
-- ============================================

-- Vegan rules (high confidence - animal products)
INSERT INTO dietary_rules (diet_type, ingredient_pattern, rule_type, confidence_impact, notes) VALUES
('vegan', 'milk', 'high', 'not_vegan', '{"Common dairy product"}'),
('vegan', 'cream', 'high', 'not_vegan', '{"Dairy product"}'),
('vegan', 'butter', 'high', 'not_vegan', '{"Dairy product"}'),
('vegan', 'cheese', 'high', 'not_vegan', '{"Dairy product"}'),
('vegan', 'whey', 'high', 'not_vegan', '{"Dairy byproduct"}'),
('vegan', 'lactose', 'high', 'not_vegan', '{"Milk sugar"}'),
('vegan', 'casein', 'high', 'not_vegan', '{"Milk protein"}'),
('vegan', 'egg', 'high', 'not_vegan', '{"Animal product"}'),
('vegan', 'honey', 'high', 'not_vegan', '{"Bee product"}'),
('vegan', 'gelatin', 'high', 'not_vegan', '{"Animal collagen"}'),
('vegan', 'gelatine', 'high', 'not_vegan', '{"Animal collagen"}'),
('vegan', 'meat', 'high', 'not_vegan', '{"Animal flesh"}'),
('vegan', 'chicken', 'high', 'not_vegan', '{"Poultry"}'),
('vegan', 'beef', 'high', 'not_vegan', '{"Meat"}'),
('vegan', 'pork', 'high', 'not_vegan', '{"Meat"}'),
('vegan', 'fish', 'high', 'not_vegan', '{"Seafood"}'),
('vegan', 'salmon', 'high', 'not_vegan', '{"Seafood"}'),
('vegan', 'tuna', 'high', 'not_vegan', '{"Seafood"}'),
('vegan', 'anchovy', 'high', 'not_vegan', '{"Seafood"}'),
('vegan', 'shellfish', 'high', 'not_vegan', '{"Seafood"}'),
('vegan', 'shrimp', 'high', 'not_vegan', '{"Seafood"}'),
('vegan', 'lard', 'high', 'not_vegan', '{"Animal fat"}'),
('vegan', 'tallow', 'high', 'not_vegan', '{"Animal fat"}'),
('vegan', 'suet', 'high', 'not_vegan', '{"Animal fat"}');

-- Vegan rules (known vegan ingredients)
INSERT INTO dietary_rules (diet_type, ingredient_pattern, rule_type, confidence_impact, notes) VALUES
('vegan', 'water', 'high', 'vegan', '{"Plant-based"}'),
('vegan', 'sugar', 'med', 'vegan', '{"Usually vegan, sometimes bone char processed"}'),
('vegan', 'salt', 'high', 'vegan', '{"Mineral"}'),
('vegan', 'flour', 'high', 'vegan', '{"Plant-based"}'),
('vegan', 'vegetable', 'high', 'vegan', '{"Plant-based"}'),
('vegan', 'fruit', 'high', 'vegan', '{"Plant-based"}'),
('vegan', 'rice', 'high', 'vegan', '{"Plant-based"}'),
('vegan', 'wheat', 'high', 'vegan', '{"Plant-based grain"}'),
('vegan', 'corn', 'high', 'vegan', '{"Plant-based grain"}'),
('vegan', 'soy', 'high', 'vegan', '{"Plant-based legume"}'),
('vegan', 'bean', 'high', 'vegan', '{"Plant-based legume"}'),
('vegan', 'lentil', 'high', 'vegan', '{"Plant-based legume"}'),
('vegan', 'oil', 'med', 'vegan', '{"Usually plant-based"}'),
('vegan', 'starch', 'high', 'vegan', '{"Plant-based"}'),
('vegan', 'vinegar', 'high', 'vegan', '{"Fermented plant product"}');

-- Vegetarian rules
INSERT INTO dietary_rules (diet_type, ingredient_pattern, rule_type, confidence_impact, notes) VALUES
('vegetarian', 'meat', 'high', 'not_vegetarian', '{"Animal flesh"}'),
('vegetarian', 'chicken', 'high', 'not_vegetarian', '{"Poultry"}'),
('vegetarian', 'beef', 'high', 'not_vegetarian', '{"Meat"}'),
('vegetarian', 'pork', 'high', 'not_vegetarian', '{"Meat"}'),
('vegetarian', 'fish', 'high', 'not_vegetarian', '{"Seafood"}'),
('vegetarian', 'salmon', 'high', 'not_vegetarian', '{"Seafood"}'),
('vegetarian', 'tuna', 'high', 'not_vegetarian', '{"Seafood"}'),
('vegetarian', 'anchovy', 'high', 'not_vegetarian', '{"Seafood"}'),
('vegetarian', 'gelatin', 'high', 'not_vegetarian', '{"Animal collagen"}'),
('vegetarian', 'gelatine', 'high', 'not_vegetarian', '{"Animal collagen"}'),
('vegetarian', 'lard', 'high', 'not_vegetarian', '{"Animal fat"}'),
('vegetarian', 'tallow', 'high', 'not_vegetarian', '{"Animal fat"}'),
('vegetarian', 'rennet', 'med', 'not_vegetarian', '{"Animal enzyme, some vegetarian versions exist"}');

-- Vegetarian rules (allowed)
INSERT INTO dietary_rules (diet_type, ingredient_pattern, rule_type, confidence_impact, notes) VALUES
('vegetarian', 'milk', 'high', 'vegetarian', '{"Dairy allowed"}'),
('vegetarian', 'egg', 'high', 'vegetarian', '{"Eggs allowed"}'),
('vegetarian', 'honey', 'high', 'vegetarian', '{"Bee product allowed"}'),
('vegetarian', 'cheese', 'med', 'vegetarian', '{"Usually vegetarian, check for rennet"}');

-- Gluten-free rules
INSERT INTO dietary_rules (diet_type, ingredient_pattern, rule_type, confidence_impact, notes) VALUES
('gluten_free', 'wheat', 'high', 'contains_gluten', '{"Contains gluten"}'),
('gluten_free', 'barley', 'high', 'contains_gluten', '{"Contains gluten"}'),
('gluten_free', 'rye', 'high', 'contains_gluten', '{"Contains gluten"}'),
('gluten_free', 'malt', 'high', 'contains_gluten', '{"Usually from barley"}'),
('gluten_free', 'spelt', 'high', 'contains_gluten', '{"Contains gluten"}'),
('gluten_free', 'kamut', 'high', 'contains_gluten', '{"Contains gluten"}'),
('gluten_free', 'triticale', 'high', 'contains_gluten', '{"Wheat-rye hybrid"}'),
('gluten_free', 'flour', 'med', 'contains_gluten', '{"Usually wheat flour"}'),
('gluten_free', 'bread', 'med', 'contains_gluten', '{"Usually contains gluten"}'),
('gluten_free', 'pasta', 'med', 'contains_gluten', '{"Usually contains gluten"}'),
('gluten_free', 'oat', 'med', 'contains_gluten', '{"Cross-contamination risk"}');

-- Gluten-free rules (allowed)
INSERT INTO dietary_rules (diet_type, ingredient_pattern, rule_type, confidence_impact, notes) VALUES
('gluten_free', 'rice', 'high', 'gluten_free', '{"Naturally gluten-free"}'),
('gluten_free', 'corn', 'high', 'gluten_free', '{"Naturally gluten-free"}'),
('gluten_free', 'potato', 'high', 'gluten_free', '{"Naturally gluten-free"}'),
('gluten_free', 'quinoa', 'high', 'gluten_free', '{"Naturally gluten-free"}'),
('gluten_free', 'buckwheat', 'high', 'gluten_free', '{"Naturally gluten-free despite name"}'),
('gluten_free', 'soy', 'high', 'gluten_free', '{"Naturally gluten-free"}'),
('gluten_free', 'tapioca', 'high', 'gluten_free', '{"Naturally gluten-free"}');

COMMIT;
