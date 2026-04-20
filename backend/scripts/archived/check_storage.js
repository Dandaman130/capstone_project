/**
 * check_storage.js
 * Shows per-table size (data + indexes + total) so we can see
 * exactly where the storage is going.
 */
'use strict';
const { Pool } = require('pg');

const DATABASE_URL = process.env.DATABASE_URL;
if (!DATABASE_URL) { console.error('Set DATABASE_URL first'); process.exit(1); }

const pool = new Pool({ connectionString: DATABASE_URL });

async function checkStorage() {
  try {
    // Per-table sizes
    const tables = await pool.query(`
      SELECT
        relname                                          AS table_name,
        pg_size_pretty(pg_table_size(oid))               AS data_size,
        pg_size_pretty(pg_indexes_size(oid))             AS index_size,
        pg_size_pretty(pg_total_relation_size(oid))      AS total_size,
        pg_total_relation_size(oid)                      AS total_bytes
      FROM pg_class
      WHERE relkind = 'r'
        AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
      ORDER BY total_bytes DESC
    `);

    console.log('\n=== Table Storage Breakdown ===\n');
    console.log('Table'.padEnd(28) + 'Data'.padEnd(12) + 'Indexes'.padEnd(12) + 'Total');
    console.log('─'.repeat(64));
    let grandTotal = 0;
    for (const r of tables.rows) {
      console.log(
        r.table_name.padEnd(28) +
        r.data_size.padEnd(12) +
        r.index_size.padEnd(12) +
        r.total_size
      );
      grandTotal += parseInt(r.total_bytes);
    }
    console.log('─'.repeat(64));
    console.log(`${'TOTAL'.padEnd(52)} ${(grandTotal / 1024 / 1024).toFixed(1)} MB`);

    // Per-index sizes
    const indexes = await pool.query(`
      SELECT
        indexname,
        tablename,
        pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size,
        pg_relation_size(indexname::regclass)                 AS index_bytes
      FROM pg_indexes
      WHERE schemaname = 'public'
      ORDER BY index_bytes DESC
    `);

    console.log('\n=== Index Sizes ===\n');
    for (const r of indexes.rows) {
      console.log(`  ${r.index_size.padEnd(10)} ${r.tablename}.${r.indexname}`);
    }

    // Column type audit for key tables
    console.log('\n=== Column Types (space-relevant) ===\n');
    const cols = await pool.query(`
      SELECT table_name, column_name, data_type, character_maximum_length
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name IN ('products','ingredients','categories','product_categories','product_ingredients')
      ORDER BY table_name, ordinal_position
    `);
    let lastTable = '';
    for (const c of cols.rows) {
      if (c.table_name !== lastTable) { console.log(`\n  ${c.table_name}`); lastTable = c.table_name; }
      console.log(`    ${c.column_name.padEnd(35)} ${c.data_type}`);
    }

    // Row counts
    console.log('\n=== Row Counts ===\n');
    for (const t of ['products_old','products','categories','ingredients','product_categories','product_ingredients']) {
      try {
        const r = await pool.query(`SELECT COUNT(*) FROM ${t}`);
        console.log(`  ${t.padEnd(28)} ${r.rows[0].count}`);
      } catch (_) {
        console.log(`  ${t.padEnd(28)} (not found)`);
      }
    }

    // Avg row width estimate
    console.log('\n=== Avg Row Width (bytes) ===\n');
    for (const t of ['products','categories','ingredients','product_categories','product_ingredients']) {
      try {
        const r = await pool.query(
          `SELECT AVG(pg_column_size(t.*)) AS avg_row FROM ${t} t`
        );
        console.log(`  ${t.padEnd(28)} ~${parseFloat(r.rows[0].avg_row || 0).toFixed(0)} bytes/row`);
      } catch(_) {}
    }

  } catch (err) {
    console.error(err.message);
  } finally {
    await pool.end();
  }
}

checkStorage();
