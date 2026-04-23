/**
 * recommend_recipes_by_barcodes.js
 *
 * Demo query runner:
 * Given product barcodes, returns top recipe matches using canonical ingredients.
 *
 * Usage:
 *   $env:DATABASE_URL = "postgresql://..."
 *   node recommend_recipes_by_barcodes.js 00000000,00000007 20
 */

'use strict';

const { Pool } = require('pg');

const DATABASE_URL = process.env.DATABASE_URL;
if (!DATABASE_URL) {
  console.error('DATABASE_URL is required.');
  process.exit(1);
}

const barcodeCsv = process.argv[2] || '';
const limit = Number(process.argv[3] || 20);

const barcodes = barcodeCsv
  .split(',')
  .map((x) => x.trim())
  .filter(Boolean);

if (barcodes.length === 0) {
  console.error('Pass barcodes CSV as first arg, e.g. node recommend_recipes_by_barcodes.js 0001,0002');
  process.exit(1);
}

const pool = new Pool({ connectionString: DATABASE_URL });

async function run() {
  const sql = `
    WITH pantry_ingredients AS (
      SELECT DISTINCT pci.canonical_ingredient_id
      FROM products p
      JOIN product_canonical_ingredients pci ON pci.product_id = p.id
      WHERE p.barcode = ANY($1)
    ),
    recipe_scores AS (
      SELECT
        r.id,
        r.title,
        r.source,
        r.source_site,
        r.source_link,
        COUNT(*) FILTER (
          WHERE rci.canonical_ingredient_id IN (
            SELECT canonical_ingredient_id FROM pantry_ingredients
          )
        ) AS matched_ingredients,
        COUNT(*) AS total_recipe_ingredients
      FROM recipes r
      JOIN recipe_canonical_ingredients rci ON rci.recipe_id = r.id
      GROUP BY r.id, r.title, r.source, r.source_site, r.source_link
    )
    SELECT
      id,
      title,
      source,
      source_site,
      source_link,
      matched_ingredients,
      total_recipe_ingredients,
      ROUND(matched_ingredients::numeric / NULLIF(total_recipe_ingredients, 0), 4) AS coverage
    FROM recipe_scores
    WHERE matched_ingredients > 0
    ORDER BY coverage DESC, matched_ingredients DESC, total_recipe_ingredients ASC
    LIMIT $2;
  `;

  const { rows } = await pool.query(sql, [barcodes, limit]);

  console.log(`Found ${rows.length} recipe matches for ${barcodes.length} barcode(s).\n`);
  rows.forEach((r, idx) => {
    console.log(`${idx + 1}. ${r.title}`);
    console.log(`   coverage=${r.coverage} matched=${r.matched_ingredients}/${r.total_recipe_ingredients}`);
    if (r.source_site || r.source) {
      console.log(`   source=${r.source_site || r.source}`);
    }
    if (r.source_link) {
      console.log(`   link=${r.source_link}`);
    }
  });
}

run()
  .catch((err) => {
    console.error('Recommendation query failed:', err.message);
    console.error(err.stack);
    process.exitCode = 1;
  })
  .finally(async () => {
    await pool.end();
  });
