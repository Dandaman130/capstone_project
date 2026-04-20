/**
 * verify_db.js
 * ──────────────────────────────────────────────────────────────
 * Quick sanity-check after running migrate.js.
 * Prints row counts, column structures, and sample data
 * for every table.  products_old is shown but never modified.
 *
 * Usage:
 *   DATABASE_URL=<railway_url> node verify_db.js
 */

'use strict';

const { Pool } = require('pg');

const DATABASE_URL = process.env.DATABASE_URL;
if (!DATABASE_URL) {
  console.error('\n✗ DATABASE_URL environment variable is not set.');
  console.error('  Get it from: Railway → your PostgreSQL service → Variables tab');
  console.error('  Then run:');
  console.error('    $env:DATABASE_URL = "postgresql://user:pass@host:port/railway"');
  console.error('    node verify_db.js\n');
  process.exit(1);
}

const pool = new Pool({ connectionString: DATABASE_URL });

async function verify() {
  console.log('=== Database Verification ===\n');

  try {
    // ── 1. All tables in public schema ────────────────────────
    const tables = await pool.query(`
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = 'public'
      ORDER BY table_name
    `);

    console.log('Tables present:');
    tables.rows.forEach(r => console.log(`  • ${r.table_name}`));
    console.log();

    // ── 2. Row counts ────────────────────────────────────────
    const tracked = [
      'products_old',
      'products',
      'categories',
      'product_categories',
    ];

    console.log('Row counts:');
    for (const t of tracked) {
      try {
        const res = await pool.query(`SELECT COUNT(*) FROM ${t}`);
        console.log(`  ${t.padEnd(25)} ${res.rows[0].count}`);
      } catch (_) {
        console.log(`  ${t.padEnd(25)} (not found)`);
      }
    }
    console.log();

    // ── 3. Column structure for each new table ───────────────
    const newTables = ['products', 'categories', 'product_categories'];

    for (const t of newTables) {
      const cols = await pool.query(`
        SELECT column_name, data_type, column_default, is_nullable
        FROM information_schema.columns
        WHERE table_name = $1 AND table_schema = 'public'
        ORDER BY ordinal_position
      `, [t]);

      if (cols.rows.length === 0) {
        console.log(`  ${t}: NOT FOUND\n`); continue;
      }

      console.log(`── ${t} ─────────────────────────`);
      cols.rows.forEach(c =>
        console.log(`  ${c.column_name.padEnd(30)} ${c.data_type.padEnd(20)} ${c.is_nullable === 'NO' ? 'NOT NULL' : ''}`)
      );
      console.log();
    }

    // ── 4. Sample products with diet flags ───────────────────
    console.log('── Sample products ──────────────────────');
    const products = await pool.query(`
      SELECT barcode, name, brand, is_vegan, is_vegetarian, is_gluten_free, is_dairy_free
      FROM products
      ORDER BY barcode
      LIMIT 5
    `);

    products.rows.forEach(p => {
      console.log(`  ${p.barcode}`);
      console.log(`    Name      : ${p.name}`);
      console.log(`    Brand     : ${p.brand}`);
      console.log(`    Vegan      ${p.is_vegan}  Vegetarian ${p.is_vegetarian}  GF ${p.is_gluten_free}  DF ${p.is_dairy_free}`);
    });
    console.log();

    // ── 5. Diet flag breakdown ────────────────────────────────
    console.log('── Diet flag breakdown ──────────────────────────');
    const flags = await pool.query(`
      SELECT
        SUM(CASE WHEN is_vegan        =  1 THEN 1 ELSE 0 END) AS vegan,
        SUM(CASE WHEN is_vegan        =  0 THEN 1 ELSE 0 END) AS not_vegan,
        SUM(CASE WHEN is_vegetarian   =  1 THEN 1 ELSE 0 END) AS vegetarian,
        SUM(CASE WHEN is_vegetarian   =  0 THEN 1 ELSE 0 END) AS not_vegetarian,
        SUM(CASE WHEN is_gluten_free  =  1 THEN 1 ELSE 0 END) AS gluten_free,
        SUM(CASE WHEN is_gluten_free  =  0 THEN 1 ELSE 0 END) AS not_gluten_free,
        SUM(CASE WHEN is_dairy_free   =  1 THEN 1 ELSE 0 END) AS dairy_free,
        SUM(CASE WHEN is_dairy_free   =  0 THEN 1 ELSE 0 END) AS not_dairy_free
      FROM products
    `);
    const f = flags.rows[0];
    console.log(`  Vegan:       ${f.vegan} yes / ${f.not_vegan} no`);
    console.log(`  Vegetarian:  ${f.vegetarian} yes / ${f.not_vegetarian} no`);
    console.log(`  Gluten-free: ${f.gluten_free} yes / ${f.not_gluten_free} no`);
    console.log(`  Dairy-free:  ${f.dairy_free} yes / ${f.not_dairy_free} no`);
    console.log();

    // ── 6. Categories: top-level breakdown ───────────────────
    console.log('── Category levels ──────────────────────');
    const catLevels = await pool.query(`
      SELECT level, COUNT(*) as count
      FROM categories
      GROUP BY level
      ORDER BY level
    `);
    catLevels.rows.forEach(r => console.log(`  Level ${r.level}: ${r.count} categories`));
    console.log();

    // ── 7. Junction coverage ─────────────────────────────────
    const junctionStats = await pool.query(`
      SELECT
        (SELECT COUNT(DISTINCT product_id) FROM product_categories) AS products_with_categories,
        (SELECT COUNT(*) FROM products)                              AS total_products
    `);
    const j = junctionStats.rows[0];
    console.log('── Junction coverage ────────────────────');
    console.log(`  Products with categories : ${j.products_with_categories} / ${j.total_products}`);

    // ── 8. Storage summary ───────────────────────────────────
    const storage = await pool.query(`
      SELECT
        SUM(pg_total_relation_size(oid)) AS total_bytes
      FROM pg_class
      WHERE relkind = 'r'
        AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
    `);
    const mb = (parseInt(storage.rows[0].total_bytes) / 1024 / 1024).toFixed(2);
    console.log(`\n── Total table+index storage: ${mb} MB ─────`);

    console.log('\n=== Verification complete ===');

  } catch (err) {
    console.error('Error:', err.message);
    console.error(err.stack);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

verify();
