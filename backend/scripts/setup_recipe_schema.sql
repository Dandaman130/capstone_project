-- ============================================================
-- setup_recipe_schema.sql (phase-1 recipe matching MVP)
-- Adds recipe + canonical ingredient tables without changing
-- the existing products table shape.
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS recipes (
  id BIGSERIAL PRIMARY KEY,
  title TEXT NOT NULL,
  directions TEXT,
  source TEXT,
  source_site TEXT,
  source_link TEXT,
  raw_ingredients TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS recipe_ingredients (
  recipe_id BIGINT NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
  raw_name TEXT NOT NULL,
  normalized_name TEXT NOT NULL,
  PRIMARY KEY (recipe_id, normalized_name)
);

CREATE INDEX IF NOT EXISTS idx_recipe_ingredients_normalized
  ON recipe_ingredients(normalized_name);

CREATE TABLE IF NOT EXISTS canonical_ingredients (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ingredient_aliases (
  alias TEXT PRIMARY KEY,
  canonical_ingredient_id INTEGER NOT NULL REFERENCES canonical_ingredients(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ingredient_aliases_canonical
  ON ingredient_aliases(canonical_ingredient_id);

CREATE TABLE IF NOT EXISTS recipe_canonical_ingredients (
  recipe_id BIGINT NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
  canonical_ingredient_id INTEGER NOT NULL REFERENCES canonical_ingredients(id) ON DELETE CASCADE,
  PRIMARY KEY (recipe_id, canonical_ingredient_id)
);

CREATE INDEX IF NOT EXISTS idx_recipe_ci_canonical
  ON recipe_canonical_ingredients(canonical_ingredient_id);

-- Maps existing products -> canonical ingredients.
-- Start by mapping only common pantry products for the MVP.
CREATE TABLE IF NOT EXISTS product_canonical_ingredients (
  product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  canonical_ingredient_id INTEGER NOT NULL REFERENCES canonical_ingredients(id) ON DELETE CASCADE,
  source TEXT NOT NULL DEFAULT 'manual',
  confidence NUMERIC(5,4) NOT NULL DEFAULT 1.0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (product_id, canonical_ingredient_id)
);

CREATE INDEX IF NOT EXISTS idx_product_ci_canonical
  ON product_canonical_ingredients(canonical_ingredient_id);

COMMIT;
