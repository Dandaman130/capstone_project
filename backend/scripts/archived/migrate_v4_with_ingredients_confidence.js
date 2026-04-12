/**
 * migrate.js
 * ──────────────────────────────────────────────────────────────
 * Full migration script for the capstone app Railway database.
 *
 * What it does:
 *   1. Drops the 5 working tables (products_old is NEVER touched).
 *   2. Re-creates them with the v3 schema (setup_schema.sql).
 *   3. Reads up to MAX_PRODUCTS lines from the JSONL file.
 *   4. Populates: products, categories, ingredients,
 *                 product_categories, product_ingredients.
 *   5. Calculates ingredient confidence scores:
 *        If a product has label tag "en:vegan"     → every ingredient
 *        in that product gets +1 to vegan_confidence.
 *        If it has "en:non-vegan"                  → +1 to not_vegan_confidence.
 *        Same pattern for vegetarian / gluten-free / dairy-free.
 *
 * Usage:
 *   DATABASE_URL=<railway_url> node migrate.js
 *   (or set DATABASE_URL in your environment and run without the prefix)
 */

'use strict';

const fs      = require('fs');
const path    = require('path');
const readline = require('readline');
const { Pool } = require('pg');

// ── Config ──────────────────────────────────────────────────────
const DATABASE_URL = process.env.DATABASE_URL;
if (!DATABASE_URL) {
  console.error('\n✗ DATABASE_URL environment variable is not set.');
  console.error('  Get it from: Railway → your PostgreSQL service → Variables tab');
  console.error('  Then run:');
  console.error('    $env:DATABASE_URL = "postgresql://user:pass@host:port/railway"');
  console.error('    node migrate.js\n');
  process.exit(1);
}

const MAX_PRODUCTS       = 2000;
const MAX_ING_PER_PRODUCT = 12;  // cap ingredient links per product
                                  // 4M × 12 = 48M rows ≈ 3.4 GB (fits in 5 GB budget)
const JSONL_FILE    = path.join(__dirname, 'openfoodfacts-products.jsonl');
const SCHEMA_FILE   = path.join(__dirname, 'setup_schema.sql');
const BATCH_SIZE    = 200; // rows per INSERT batch

const pool = new Pool({
  connectionString: DATABASE_URL,
  connectionTimeoutMillis: 10_000,
  idleTimeoutMillis:       30_000,
});

// ── Known ingredient classifications (binary: 1 yes, 0 no) ──────
// These are set directly; confidence will still be calculated
// from product tag co-occurrence on top of this.
const KNOWN_INGREDIENTS = {
  'en:water':           { vegan: 1, vegetarian: 1, gluten_free: 1, dairy_free: 1 },
  'en:sugar':           { vegan: 1, vegetarian: 1, gluten_free: 1, dairy_free: 1 },
  'en:salt':            { vegan: 1, vegetarian: 1, gluten_free: 1, dairy_free: 1 },
  'en:carbon-dioxide':  { vegan: 1, vegetarian: 1, gluten_free: 1, dairy_free: 1 },
  'en:carbonated-water':{ vegan: 1, vegetarian: 1, gluten_free: 1, dairy_free: 1 },
  'en:fructose':        { vegan: 1, vegetarian: 1, gluten_free: 1, dairy_free: 1 },
  'en:glucose':         { vegan: 1, vegetarian: 1, gluten_free: 1, dairy_free: 1 },
  'en:rice':            { vegan: 1, vegetarian: 1, gluten_free: 1, dairy_free: 1 },
  'en:corn':            { vegan: 1, vegetarian: 1, gluten_free: 1, dairy_free: 1 },
  'en:soy':             { vegan: 1, vegetarian: 1, gluten_free: 1, dairy_free: 1 },
  'en:milk':            { vegan: 0, vegetarian: 1, gluten_free: 1, dairy_free: 0 },
  'en:cream':           { vegan: 0, vegetarian: 1, gluten_free: 1, dairy_free: 0 },
  'en:butter':          { vegan: 0, vegetarian: 1, gluten_free: 1, dairy_free: 0 },
  'en:cheese':          { vegan: 0, vegetarian: 1, gluten_free: 1, dairy_free: 0 },
  'en:whey':            { vegan: 0, vegetarian: 1, gluten_free: 1, dairy_free: 0 },
  'en:egg':             { vegan: 0, vegetarian: 1, gluten_free: 1, dairy_free: 1 },
  'en:honey':           { vegan: 0, vegetarian: 1, gluten_free: 1, dairy_free: 1 },
  'en:gelatin':         { vegan: 0, vegetarian: 0, gluten_free: 1, dairy_free: 1 },
  'en:gelatine':        { vegan: 0, vegetarian: 0, gluten_free: 1, dairy_free: 1 },
  'en:wheat':           { vegan: 1, vegetarian: 1, gluten_free: 0, dairy_free: 1 },
  'en:barley':          { vegan: 1, vegetarian: 1, gluten_free: 0, dairy_free: 1 },
  'en:rye':             { vegan: 1, vegetarian: 1, gluten_free: 0, dairy_free: 1 },
  'en:wheat-flour':     { vegan: 1, vegetarian: 1, gluten_free: 0, dairy_free: 1 },
};

// ── Helpers ──────────────────────────────────────────────────────

/** Normalise an ingredient tag to a human-readable name. */
function normalizeIngredient(tag) {
  return tag.toLowerCase().replace(/^en:/, '').replace(/-/g, ' ').trim();
}

/**
 * Extract diet flags from a product's raw JSON.
 * Checks labels_tags first, then falls back to ingredients_analysis_tags.
 * Returns { is_vegan, is_vegetarian, is_gluten_free, is_dairy_free }
 * with values 1 | 0 | -1.
 */
function extractDietFlags(product) {
  const flags = { is_vegan: -1, is_vegetarian: -1, is_gluten_free: -1, is_dairy_free: -1 };

  // Merge both tag arrays so we catch explicit labels AND OFF's computed analysis
  const tags = new Set([
    ...(Array.isArray(product.labels_tags)              ? product.labels_tags              : []),
    ...(Array.isArray(product.ingredients_analysis_tags)? product.ingredients_analysis_tags : []),
  ]);

  if (tags.has('en:vegan'))          flags.is_vegan        = 1;
  else if (tags.has('en:non-vegan')) flags.is_vegan        = 0;

  if (tags.has('en:vegetarian'))          flags.is_vegetarian  = 1;
  else if (tags.has('en:non-vegetarian')) flags.is_vegetarian  = 0;

  if (tags.has('en:gluten-free') || tags.has('en:no-gluten'))
                                          flags.is_gluten_free = 1;
  else if (tags.has('en:contains-gluten'))flags.is_gluten_free = 0;

  if (tags.has('en:dairy-free') || tags.has('en:no-lactose') || tags.has('en:lactose-free'))
                                          flags.is_dairy_free  = 1;
  else if (tags.has('en:contains-milk') || tags.has('en:contains-dairy'))
                                          flags.is_dairy_free  = 0;

  return flags;
}

/**
 * Return a dict of which confidence columns to increment for a product.
 * Keys are confidence column names; returned only if the product has
 * an explicit positive or negative diet tag.
 */
function getConfidenceDeltas(dietFlags) {
  const deltas = {};
  if (dietFlags.is_vegan       ===  1) deltas.vegan_confidence           = true;
  if (dietFlags.is_vegan       ===  0) deltas.not_vegan_confidence       = true;
  if (dietFlags.is_vegetarian  ===  1) deltas.vegetarian_confidence      = true;
  if (dietFlags.is_vegetarian  ===  0) deltas.not_vegetarian_confidence  = true;
  if (dietFlags.is_gluten_free ===  1) deltas.gluten_free_confidence     = true;
  if (dietFlags.is_gluten_free ===  0) deltas.not_gluten_free_confidence = true;
  if (dietFlags.is_dairy_free  ===  1) deltas.dairy_free_confidence      = true;
  if (dietFlags.is_dairy_free  ===  0) deltas.not_dairy_free_confidence  = true;
  return deltas;
}

/** Build the canonical image URL from a barcode. */
function formatImageUrl(barcode) {
  if (!barcode) return null;
  const p = barcode.padStart(13, '0');
  return `https://images.openfoodfacts.org/images/products/${p.slice(0,3)}/${p.slice(3,6)}/${p.slice(6,9)}/${p.slice(9,13)}/1.jpg`;
}

/** Split an array into chunks of <size>. */
function chunks(arr, size) {
  const out = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

// ── Step helpers ──────────────────────────────────────────────────

/**
 * Insert categories level by level (root → leaves) so parent rows
 * always exist before children.
 * Returns a Map<name, id>.
 */
async function insertCategories(categoryMap) {
  console.log(`  Inserting ${categoryMap.size} unique categories…`);

  // Sort by level so parents are inserted first
  const sorted = [...categoryMap.entries()].sort((a, b) => a[1].level - b[1].level);
  const nameToId = new Map();

  for (const batch of chunks(sorted, BATCH_SIZE)) {
    for (const [name, meta] of batch) {
      const parentId = meta.parentName ? nameToId.get(meta.parentName) ?? null : null;
      const res = await pool.query(
        `INSERT INTO categories (name, parent_id, level)
         VALUES ($1, $2, $3)
         ON CONFLICT (name) DO UPDATE SET parent_id = EXCLUDED.parent_id
         RETURNING id`,
        [name, parentId, meta.level],
      );
      nameToId.set(name, res.rows[0].id);
    }
  }

  console.log(`  ✓ ${nameToId.size} categories inserted`);
  return nameToId;
}

/**
 * Insert ingredients.
 * Returns a Map<name, id>.
 */
async function insertIngredients(ingredientSet) {
  console.log(`  Inserting ${ingredientSet.size} unique ingredients…`);
  const nameToId = new Map();
  const rows = [...ingredientSet];

  for (const batch of chunks(rows, BATCH_SIZE)) {
    const values = [];
    const params = [];
    let   idx    = 1;

    for (const name of batch) {
      const normalized = normalizeIngredient(name).slice(0, 499);
      const safeName   = name.slice(0, 499);
      const known      = KNOWN_INGREDIENTS[name] || {};
      values.push(
        `($${idx++}, $${idx++}, $${idx++}, $${idx++}, $${idx++}, $${idx++})`
      );
      params.push(
        safeName,
        normalized,
        known.vegan       ?? -1,
        known.vegetarian  ?? -1,
        known.gluten_free ?? -1,
        known.dairy_free  ?? -1,
      );
    }

    const res = await pool.query(
      `INSERT INTO ingredients
         (name, normalized_name, is_vegan, is_vegetarian, is_gluten_free, is_dairy_free)
       VALUES ${values.join(', ')}
       ON CONFLICT (name) DO NOTHING
       RETURNING id, name`,
      params,
    );
    res.rows.forEach(r => nameToId.set(r.name, r.id));
  }

  // Fetch any IDs that already existed (ON CONFLICT DO NOTHING returns nothing)
  if (nameToId.size < ingredientSet.size) {
    const missing = [...ingredientSet].filter(n => !nameToId.has(n));
    for (const batch of chunks(missing, BATCH_SIZE)) {
      const res = await pool.query(
        `SELECT id, name FROM ingredients WHERE name = ANY($1)`,
        [batch],
      );
      res.rows.forEach(r => nameToId.set(r.name, r.id));
    }
  }

  console.log(`  ✓ ${nameToId.size} ingredients ready`);
  return nameToId;
}

/**
 * Insert product rows in batches.
 * Returns a Map<barcode, id> so junction tables can use the surrogate int PK.
 */
async function insertProducts(products) {
  console.log(`  Inserting ${products.length} products…`);
  const barcodeToId = new Map();

  for (const batch of chunks(products, BATCH_SIZE)) {
    const values = [];
    const params = [];
    let idx = 1;

    for (const p of batch) {
      values.push(
        `($${idx++}, $${idx++}, $${idx++}, $${idx++}, $${idx++}, $${idx++}, $${idx++})`
      );
      params.push(
        p.barcode, p.name, p.brand,
        p.is_vegan, p.is_vegetarian, p.is_gluten_free, p.is_dairy_free,
      );
    }

    const res = await pool.query(
      `INSERT INTO products
         (barcode, name, brand,
          is_vegan, is_vegetarian, is_gluten_free, is_dairy_free)
       VALUES ${values.join(', ')}
       ON CONFLICT (barcode) DO NOTHING
       RETURNING id, barcode`,
      params,
    );
    res.rows.forEach(r => barcodeToId.set(r.barcode, r.id));
  }

  // Fetch IDs for any rows that already existed (ON CONFLICT DO NOTHING skips them)
  if (barcodeToId.size < products.length) {
    const missingBarcodes = products
      .filter(p => !barcodeToId.has(p.barcode))
      .map(p => p.barcode);
    for (const batch of chunks(missingBarcodes, BATCH_SIZE)) {
      const res = await pool.query(
        `SELECT id, barcode FROM products WHERE barcode = ANY($1)`, [batch]
      );
      res.rows.forEach(r => barcodeToId.set(r.barcode, r.id));
    }
  }

  console.log(`  ✓ Products inserted`);
  return barcodeToId;
}

/**
 * Insert product_categories junction rows.
 */
async function insertProductCategories(links, barcodeToId, categoryNameToId) {
  // Resolve barcode → product_id and catName → category_id
  const rows = links
    .map(l => ({ productId: barcodeToId.get(l.barcode), catId: categoryNameToId.get(l.catName) }))
    .filter(r => r.productId !== undefined && r.catId !== undefined);

  console.log(`  Inserting ${rows.length} product↔category links…`);

  for (const batch of chunks(rows, BATCH_SIZE)) {
    const values = [];
    const params = [];
    let idx = 1;
    for (const r of batch) {
      values.push(`($${idx++}, $${idx++})`);
      params.push(r.productId, r.catId);
    }
    await pool.query(
      `INSERT INTO product_categories (product_id, category_id)
       VALUES ${values.join(', ')}
       ON CONFLICT DO NOTHING`,
      params,
    );
  }

  console.log(`  ✓ product_categories links inserted`);
}

/**
 * Insert product_ingredients junction rows.
 */
async function insertProductIngredients(links, barcodeToId, ingredientNameToId) {
  const rows = links
    .map(l => ({ productId: barcodeToId.get(l.barcode), ingId: ingredientNameToId.get(l.ingName) }))
    .filter(r => r.productId !== undefined && r.ingId !== undefined);

  console.log(`  Inserting ${rows.length} product↔ingredient links…`);

  for (const batch of chunks(rows, BATCH_SIZE)) {
    const values = [];
    const params = [];
    let idx = 1;
    for (const r of batch) {
      values.push(`($${idx++}, $${idx++})`);
      params.push(r.productId, r.ingId);
    }
    await pool.query(
      `INSERT INTO product_ingredients (product_id, ingredient_id)
       VALUES ${values.join(', ')}
       ON CONFLICT DO NOTHING`,
      params,
    );
  }

  console.log(`  ✓ product_ingredients links inserted`);
}

/**
 * Apply accumulated confidence counts to the ingredients table.
 *
 * confidenceCounts structure:
 *   Map<ingredientName, { vegan_confidence: n, not_vegan_confidence: n, … }>
 */
async function updateConfidenceScores(confidenceCounts, ingredientNameToId) {
  const CONF_COLS = [
    'vegan_confidence',
    'not_vegan_confidence',
    'vegetarian_confidence',
    'not_vegetarian_confidence',
    'gluten_free_confidence',
    'not_gluten_free_confidence',
    'dairy_free_confidence',
    'not_dairy_free_confidence',
  ];

  // Build per-column update payloads: Map<col, Map<ingredientId, count>>
  const colMaps = {};
  CONF_COLS.forEach(c => colMaps[c] = new Map());

  for (const [name, counts] of confidenceCounts) {
    const id = ingredientNameToId.get(name);
    if (id === undefined) continue;
    for (const col of CONF_COLS) {
      if (counts[col]) colMaps[col].set(id, counts[col]);
    }
  }

  let totalUpdates = 0;

  for (const col of CONF_COLS) {
    const entries = [...colMaps[col].entries()]; // [id, count]
    if (entries.length === 0) continue;

    // Use single UPDATE with CASE for the whole column
    for (const batch of chunks(entries, BATCH_SIZE)) {
      const cases  = batch.map(([id, n]) => `WHEN ${id} THEN ${n}`).join(' ');
      const ids    = batch.map(([id])    => id).join(', ');
      await pool.query(
        `UPDATE ingredients
         SET ${col} = CASE id ${cases} END
         WHERE id IN (${ids})`
      );
      totalUpdates += batch.length;
    }
  }

  console.log(`  ✓ Confidence updated for ~${confidenceCounts.size} ingredients (${totalUpdates} row×col updates)`);
}

// ── Main ──────────────────────────────────────────────────────────

async function migrate() {
  const t0 = Date.now();
  console.log('=== capstone migration starting ===\n');

  try {
    // ─ Step 1: apply schema ────────────────────────────────────
    console.log('Step 1/7 — Applying schema (dropping & recreating 5 tables)…');
    const schema = fs.readFileSync(SCHEMA_FILE, 'utf8');
    await pool.query(schema);
    console.log('✓ Schema applied  (products_old untouched)\n');

    // ─ Step 2: read JSONL ─────────────────────────────────────
    console.log(`Step 2/7 — Reading up to ${MAX_PRODUCTS} products from JSONL…`);

    if (!fs.existsSync(JSONL_FILE)) {
      throw new Error(`JSONL file not found: ${JSONL_FILE}`);
    }

    const productsToInsert    = [];               // rows for products table
    const categoryMap         = new Map();        // catName → {level, parentName}
    const ingredientSet       = new Set();        // all unique ingredient tags
    const productCatLinks     = [];               // {barcode, catName}
    const productIngLinks     = [];               // {barcode, ingName}
    /**
     * confidenceCounts: Map<ingName, {colName: count, …}>
     * Accumulated during read pass; applied after all inserts.
     */
    const confidenceCounts    = new Map();

    const fileStream = fs.createReadStream(JSONL_FILE);
    const rl         = readline.createInterface({ input: fileStream, crlfDelay: Infinity });

    let linesRead   = 0;
    let validCount  = 0;

    for await (const line of rl) {
      if (validCount >= MAX_PRODUCTS) { rl.close(); fileStream.destroy(); break; }

      try {
        const raw = JSON.parse(line);
        linesRead++;

        // Must have barcode + name to be useful
        if (!raw.code || !raw.product_name) continue;

        const barcode   = raw.code;
        const dietFlags = extractDietFlags(raw);
        const deltas    = getConfidenceDeltas(dietFlags);
        const hasDeltas = Object.keys(deltas).length > 0;

        // ── categories ──────────────────────────────────────────
        const hierarchy = Array.isArray(raw.categories_hierarchy)
          ? raw.categories_hierarchy : [];

        let parentName = null;
        for (let i = 0; i < hierarchy.length; i++) {
          const catName = hierarchy[i];
          if (!categoryMap.has(catName)) {
            categoryMap.set(catName, { level: i, parentName });
          }
          productCatLinks.push({ barcode, catName });
          parentName = catName;
        }

        // ── ingredients (capped) ────────────────────────────
        const ingTags = Array.isArray(raw.ingredients_tags)
          ? raw.ingredients_tags.slice(0, MAX_ING_PER_PRODUCT)
          : [];

        for (const tag of ingTags) {
          ingredientSet.add(tag);
          productIngLinks.push({ barcode, ingName: tag });

          // Accumulate confidence deltas for this ingredient
          if (hasDeltas) {
            if (!confidenceCounts.has(tag)) confidenceCounts.set(tag, {});
            const counts = confidenceCounts.get(tag);
            for (const col of Object.keys(deltas)) {
              counts[col] = (counts[col] || 0) + 1;
            }
          }
        }

        // ── product row ─────────────────────────────────────────
        productsToInsert.push({
          barcode,
          name:           raw.product_name || null,
          brand:          (raw.brands       || raw.brand_owner || null),
          is_vegan:       dietFlags.is_vegan,
          is_vegetarian:  dietFlags.is_vegetarian,
          is_gluten_free: dietFlags.is_gluten_free,
          is_dairy_free:  dietFlags.is_dairy_free,
        });

        validCount++;
        if (validCount % 500 === 0) {
          console.log(`  … ${validCount} products collected (${linesRead} lines read)`);
        }
      } catch (_) {
        // Skip malformed JSON lines silently
      }
    }

    console.log(`✓ Collected ${validCount} products / ${categoryMap.size} categories / ${ingredientSet.size} ingredients\n`);

    // ─ Step 3-7: insert order matters (FK constraints) ────────
    console.log('Step 3/7 — Categories:');
    const categoryNameToId   = await insertCategories(categoryMap);
    console.log();

    console.log('Step 4/7 — Ingredients:');
    const ingredientNameToId = await insertIngredients(ingredientSet);
    console.log();

    console.log('Step 5/7 — Products:');
    const barcodeToId        = await insertProducts(productsToInsert);
    console.log();

    console.log('Step 6/7 — Junction tables:');
    await insertProductCategories(productCatLinks, barcodeToId, categoryNameToId);
    await insertProductIngredients(productIngLinks, barcodeToId, ingredientNameToId);
    console.log();

    console.log('Step 7/7 — Confidence scores:');
    await updateConfidenceScores(confidenceCounts, ingredientNameToId);
    console.log();

    const elapsed = ((Date.now() - t0) / 1000).toFixed(1);
    console.log(`=== Migration complete in ${elapsed}s ===`);
    console.log(`    Products        : ${validCount}`);
    console.log(`    Categories      : ${categoryNameToId.size}`);
    console.log(`    Ingredients     : ${ingredientNameToId.size}`);
    console.log(`    Cat links       : ${productCatLinks.length}`);
    console.log(`    Ing links       : ${productIngLinks.length}`);
    console.log(`    Conf. ingredients: ${confidenceCounts.size}`);

  } catch (err) {
    console.error('\n✗ Migration failed:', err.message);
    console.error(err.stack);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

migrate();
