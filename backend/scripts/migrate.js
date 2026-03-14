/**
 * migrate.js  (v6 — zero-SELECT insert loop)
 * ──────────────────────────────────────────────────────────────
 * Categories are already fully loaded (85,829 rows).
 * This run only inserts products + product_categories.
 *
 * Key optimisation: ON CONFLICT DO UPDATE … RETURNING id, barcode
 * returns IDs for every row (new OR existing) so we never need a
 * separate SELECT to resolve barcodes → product IDs.
 * This eliminates the growing-table scan that made the old script
 * slow to a crawl past 200k products.
 *
 * Usage:
 *   $env:DATABASE_URL = "postgresql://user:pass@host:port/railway"
 *   node migrate.js
 */

'use strict';

const fs       = require('fs');
const path     = require('path');
const readline = require('readline');
const { Pool } = require('pg');

/* ── Config ──────────────────────────────────────────────────── */
const DATABASE_URL = process.env.DATABASE_URL;
if (!DATABASE_URL) {
  console.error('\n✗ DATABASE_URL not set.\n  $env:DATABASE_URL="postgresql://…"\n  node migrate.js\n');
  process.exit(1);
}

const MAX_PRODUCTS    = Infinity;   // change to test smaller batches
const RESET_SCHEMA    = false;      // true = wipe + recreate tables first
const RESET_LINKS     = false;       // true = TRUNCATE product_categories before inserting
                                    // (required when switching from all-ancestors to leaf-only)
                                    // Ignored if a checkpoint file exists (resuming a run)
const FLUSH_EVERY     = 5_000;      // products buffered before each DB flush
const CHECKPOINT_FILE = path.join(__dirname, 'migrate_checkpoint.json');

const JSONL_FILE  = path.join(__dirname, 'openfoodfacts-products.jsonl');
const SCHEMA_FILE = path.join(__dirname, 'setup_schema.sql');

const pool = new Pool({
  connectionString:        DATABASE_URL,
  ssl:                     { rejectUnauthorized: false },
  statement_timeout:       120_000,
  query_timeout:           120_000,
  connectionTimeoutMillis: 30_000,
  idleTimeoutMillis:       60_000,
});

/* ── Diet flag extraction ────────────────────────────────────── */
function extractDietFlags(raw) {
  const tags = new Set([
    ...(Array.isArray(raw.labels_tags)               ? raw.labels_tags               : []),
    ...(Array.isArray(raw.ingredients_analysis_tags) ? raw.ingredients_analysis_tags : []),
  ]);

  const flag = (pos, neg) => tags.has(pos) ? 1 : tags.has(neg) ? 0 : -1;

  return {
    is_vegan:       flag('en:vegan',       'en:non-vegan'),
    is_vegetarian:  flag('en:vegetarian',  'en:non-vegetarian'),
    is_gluten_free: tags.has('en:gluten-free') || tags.has('en:no-gluten')      ? 1
                  : tags.has('en:contains-gluten')                              ? 0 : -1,
    is_dairy_free:  tags.has('en:dairy-free') || tags.has('en:lactose-free')    ? 1
                  : tags.has('en:contains-milk') || tags.has('en:contains-dairy')? 0 : -1,
  };
}

/* ── Helpers ─────────────────────────────────────────────────── */
function chunks(arr, size) {
  const out = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

/* ── Load category name→id map straight from DB ─────────────── */
async function loadCategories() {
  const map = new Map();
  let offset = 0;
  while (true) {
    const { rows } = await pool.query(
      'SELECT id, name FROM categories ORDER BY id LIMIT 50000 OFFSET $1',
      [offset],
    );
    if (rows.length === 0) break;
    for (const r of rows) map.set(r.name, r.id);
    offset += rows.length;
  }
  return map;
}

/* ── Insert products — returns barcode→id for EVERY row ─────── */
// Uses ON CONFLICT DO UPDATE … RETURNING so we get IDs for both
// new rows and already-existing ones without any extra SELECT.
async function insertProducts(batch) {
  const barcodeToId = new Map();
  for (const slice of chunks(batch, 500)) {
    const phs = [], vals = [];
    let i = 1;
    for (const p of slice) {
      phs.push(`($${i},$${i+1},$${i+2},$${i+3},$${i+4},$${i+5},$${i+6})`);
      vals.push(
        (p.barcode || '').slice(0, 199),
        (p.name    || '').slice(0, 999),
        (p.brand   || '').slice(0, 499),
        p.flags.is_vegan, p.flags.is_vegetarian,
        p.flags.is_gluten_free, p.flags.is_dairy_free,
      );
      i += 7;
    }
    const { rows } = await pool.query(`
      INSERT INTO products
        (barcode, name, brand, is_vegan, is_vegetarian, is_gluten_free, is_dairy_free)
      VALUES ${phs.join(',')}
      ON CONFLICT (barcode) DO UPDATE SET barcode = EXCLUDED.barcode
      RETURNING id, barcode`, vals);
    for (const r of rows) barcodeToId.set(r.barcode, r.id);
  }
  return barcodeToId;
}

/* ── Insert product_categories (resolved links only) ────────── */
async function insertProductCategories(links) {
  for (const slice of chunks(links, 1000)) {
    const phs = [], vals = [];
    let i = 1;
    for (const lk of slice) {
      phs.push(`($${i},$${i+1})`);
      vals.push(lk.productId, lk.categoryId);
      i += 2;
    }
    await pool.query(`
      INSERT INTO product_categories (product_id, category_id)
      VALUES ${phs.join(',')}
      ON CONFLICT DO NOTHING`, vals);
  }
}

/* ── Main ────────────────────────────────────────────────────── */
async function migrate() {
  const t0 = Date.now();
  console.log('=== capstone migration (v6) starting ===\n');

  try {
    /* Step 1a — optional schema reset */
    if (RESET_SCHEMA) {
      console.log('Step 1/4 — Applying schema…');
      await pool.query(fs.readFileSync(SCHEMA_FILE, 'utf8'));
      console.log('✓ Schema applied\n');
    } else {
      console.log('Step 1/4 — Skipping schema reset (RESET_SCHEMA=false)\n');
      await pool.query(`ALTER TABLE categories ALTER COLUMN name    TYPE VARCHAR(1000)`);
      await pool.query(`ALTER TABLE products   ALTER COLUMN name    TYPE VARCHAR(1000)`);
      await pool.query(`ALTER TABLE products   ALTER COLUMN brand   TYPE VARCHAR(500)`);
      await pool.query(`ALTER TABLE products   ALTER COLUMN barcode TYPE VARCHAR(200)`);
    }

    /* Step 1b — checkpoint / RESET_LINKS logic */
    let skipProducts = 0;
    const hasCheckpoint = fs.existsSync(CHECKPOINT_FILE);

    if (hasCheckpoint) {
      const cp = JSON.parse(fs.readFileSync(CHECKPOINT_FILE, 'utf8'));
      skipProducts = cp.productsRead || 0;
      console.log(`  ► Checkpoint found — resuming from product ${skipProducts.toLocaleString()}\n`);
    } else if (RESET_LINKS) {
      console.log('Step 1b/4 — Truncating product_categories (switching to leaf-only links)…');
      await pool.query('TRUNCATE TABLE product_categories');
      console.log('  ✓ product_categories cleared\n');
    }

    /* Step 2 — load category map */
    console.log('Step 2/4 — Loading categories from DB…');
    const catNameToId = await loadCategories();
    console.log(`   ${catNameToId.size.toLocaleString()} categories loaded\n`);

    /* Step 3 — current product count */
    const { rows: [{ n: existingN }] } = await pool.query('SELECT COUNT(*) AS n FROM products');
    console.log(`Step 3/4 — Existing products in DB: ${Number(existingN).toLocaleString()}`);
    if (skipProducts > 0) console.log(`          Skipping first ${skipProducts.toLocaleString()} valid JSONL lines (checkpoint)\n`);
    else console.log();

    /* Step 4 — stream JSONL and flush */
    console.log(`Step 4/4 — Streaming products (flush every ${FLUSH_EVERY.toLocaleString()})…`);

    let productBatch  = [];
    let catLinkBatch  = [];   // { barcode, categoryId }
    let totalRead     = 0;
    let totalNew      = 0;
    let flushNum      = 0;
    let skipped       = 0;   // lines skipped during checkpoint resume

    async function flush() {
      if (productBatch.length === 0) return;
      // Deduplicate productBatch by barcode to avoid ON CONFLICT errors
      const seenBarcodes = new Set();
      const dedupedBatch = [];
      for (const product of productBatch) {
        if (!seenBarcodes.has(product.barcode)) {
          seenBarcodes.add(product.barcode);
          dedupedBatch.push(product);
        }
      }
      productBatch = dedupedBatch;
      if (productBatch.length === 0) return;
      flushNum++;
      const ft0 = Date.now();

      const barcodeToId = await insertProducts(productBatch);

      // Resolve barcode → product_id now that we have the map
      const resolved = catLinkBatch
        .map(lk => ({ productId: barcodeToId.get(lk.barcode), categoryId: lk.categoryId }))
        .filter(lk => lk.productId != null);

      await insertProductCategories(resolved);

      totalNew += barcodeToId.size;

      const elapsed = ((Date.now() - ft0) / 1000).toFixed(1);
      process.stdout.write(
        `    Flush #${flushNum}: ${productBatch.length.toLocaleString()} processed` +
        ` | script total: ${totalRead.toLocaleString()} | ${elapsed}s\n`
      );

      // Save checkpoint after every successful flush
      fs.writeFileSync(CHECKPOINT_FILE, JSON.stringify({ productsRead: totalRead }));

      // Real DB count every 50 flushes
      if (flushNum % 50 === 0) {
        const { rows } = await pool.query('SELECT COUNT(*) AS n FROM products');
        console.log(`    ── DB row count: ${Number(rows[0].n).toLocaleString()} ──`);
      }

      productBatch = [];
      catLinkBatch = [];
    }

    const rl = readline.createInterface({
      input: fs.createReadStream(JSONL_FILE),
      crlfDelay: Infinity,
    });

    for await (const line of rl) {
      if (totalRead >= MAX_PRODUCTS) { rl.close(); break; }
      let raw;
      try { raw = JSON.parse(line); } catch { continue; }

      const barcode = (raw.code || '').trim();
      const name    = (raw.product_name || '').trim();
      if (!barcode || !name) continue;

      // Skip products already processed in a previous run
      if (skipped < skipProducts) {
        skipped++;
        totalRead++;
        continue;
      }

      totalRead++;
      productBatch.push({
        barcode,
        name,
        brand: (raw.brands || '').trim(),
        flags: extractDietFlags(raw),
      });

      // Leaf-only: only link to the most-specific category.
      // Ancestor traversal is done at query time via recursive CTE.
      const cats = Array.isArray(raw.categories_hierarchy) ? raw.categories_hierarchy : [];
      if (cats.length > 0) {
        const leaf  = cats[cats.length - 1];
        const catId = catNameToId.get(leaf);
        if (catId != null) catLinkBatch.push({ barcode, categoryId: catId });
      }

      if (productBatch.length >= FLUSH_EVERY) await flush();
    }

    await flush(); // final partial batch

    const secs = ((Date.now() - t0) / 1000).toFixed(1);
    const { rows: [{ n: finalN }] } = await pool.query('SELECT COUNT(*) AS n FROM products');
    console.log(`\n=== Migration complete in ${secs}s ===`);
    console.log(`    Products read : ${totalRead.toLocaleString()}`);
    console.log(`    DB total      : ${Number(finalN).toLocaleString()}`);

    // Clean up checkpoint — migration finished successfully
    if (fs.existsSync(CHECKPOINT_FILE)) {
      fs.unlinkSync(CHECKPOINT_FILE);
      console.log('    Checkpoint file deleted.');+
    }

  } catch (err) {
    console.error('\n✗ Migration failed:', err.message);
    console.error(err.stack);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

migrate();

