const { Pool } = require('pg');

const DATABASE_URL = process.env.DATABASE_URL || 'postgresql://postgres:cFGvTOMRZauZulyRoryYpJILFUszgorI@switchyard.proxy.rlwy.net:29111/railway';

const pool = new Pool({
  connectionString: DATABASE_URL,
});

async function analyzeIngredientCoverage() {
  try {
    console.log('Analyzing ingredient coverage...\n');
    
    // Total ingredients
    const total = await pool.query(`SELECT COUNT(*) FROM ingredients`);
    console.log(`Total ingredients in database: ${total.rows[0].count}`);
    
    // Ingredients that appear in ANY product
    const withProducts = await pool.query(`
      SELECT COUNT(DISTINCT ingredient_id) as count
      FROM product_ingredients
    `);
    console.log(`Ingredients linked to products: ${withProducts.rows[0].count}`);
    
    // Ingredients in products with KNOWN vegan status (not -1)
    const withVeganTag = await pool.query(`
      SELECT COUNT(DISTINCT pi.ingredient_id) as count
      FROM product_ingredients pi
      JOIN products p ON pi.product_barcode = p.barcode
      WHERE p.is_vegan IN (0, 1)
    `);
    console.log(`Ingredients in products with vegan tag (0 or 1): ${withVeganTag.rows[0].count}`);
    
    // Ingredients only in UNKNOWN products
    const onlyUnknown = await pool.query(`
      SELECT COUNT(DISTINCT pi.ingredient_id) as count
      FROM product_ingredients pi
      JOIN products p ON pi.product_barcode = p.barcode
      WHERE p.is_vegan = -1
      AND pi.ingredient_id NOT IN (
        SELECT DISTINCT pi2.ingredient_id
        FROM product_ingredients pi2
        JOIN products p2 ON pi2.product_barcode = p2.barcode
        WHERE p2.is_vegan IN (0, 1)
      )
    `);
    console.log(`Ingredients ONLY in unknown products: ${onlyUnknown.rows[0].count}`);
    
    // Ingredients never used
    const neverUsed = await pool.query(`
      SELECT COUNT(*) as count
      FROM ingredients
      WHERE id NOT IN (SELECT DISTINCT ingredient_id FROM product_ingredients)
    `);
    console.log(`Ingredients never used in any product: ${neverUsed.rows[0].count}`);
    
    // Product stats
    console.log('\nProduct breakdown:');
    const products = await pool.query(`
      SELECT 
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE is_vegan IN (0,1)) as has_vegan_tag,
        COUNT(*) FILTER (WHERE is_vegan = -1) as vegan_unknown
      FROM products
    `);
    console.log(`  Total products: ${products.rows[0].total}`);
    console.log(`  With vegan tag (0 or 1): ${products.rows[0].has_vegan_tag}`);
    console.log(`  Unknown vegan status (-1): ${products.rows[0].vegan_unknown}`);
    
    // Products with ingredients
    const withIngredients = await pool.query(`
      SELECT 
        COUNT(DISTINCT product_barcode) as total,
        COUNT(DISTINCT product_barcode) FILTER (
          WHERE product_barcode IN (
            SELECT barcode FROM products WHERE is_vegan IN (0,1)
          )
        ) as with_tags
      FROM product_ingredients
    `);
    console.log(`\nProducts with ingredients linked: ${withIngredients.rows[0].total}`);
    console.log(`  Of those, with vegan tags: ${withIngredients.rows[0].with_tags}`);
    
  } catch (err) {
    console.error('Error:', err.message);
  } finally {
    await pool.end();
  }
}

analyzeIngredientCoverage();
