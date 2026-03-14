const { Pool } = require('pg');

const DATABASE_URL = process.env.DATABASE_URL || 'postgresql://postgres:cFGvTOMRZauZulyRoryYpJILFUszgorI@switchyard.proxy.rlwy.net:29111/railway';

const pool = new Pool({
  connectionString: DATABASE_URL,
});

async function debugProducts() {
  try {
    console.log('Checking product dietary tags...\n');
    
    const stats = await pool.query(`
      SELECT 
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE is_vegan = 1) as vegan_yes,
        COUNT(*) FILTER (WHERE is_vegan = 0) as vegan_no,
        COUNT(*) FILTER (WHERE is_vegan = -1) as vegan_unknown,
        COUNT(*) FILTER (WHERE is_vegetarian = 1) as veg_yes,
        COUNT(*) FILTER (WHERE is_vegetarian = 0) as veg_no,
        COUNT(*) FILTER (WHERE is_vegetarian = -1) as veg_unknown,
        COUNT(*) FILTER (WHERE is_gluten_free = 1) as gf_yes,
        COUNT(*) FILTER (WHERE is_gluten_free = 0) as gf_no,
        COUNT(*) FILTER (WHERE is_gluten_free = -1) as gf_unknown
      FROM products
    `);
    
    const s = stats.rows[0];
    console.log(`Total products: ${s.total}\n`);
    console.log('Vegan:');
    console.log(`  Yes (1): ${s.vegan_yes}`);
    console.log(`  No (0): ${s.vegan_no}`);
    console.log(`  Unknown (-1): ${s.vegan_unknown}\n`);
    console.log('Vegetarian:');
    console.log(`  Yes (1): ${s.veg_yes}`);
    console.log(`  No (0): ${s.veg_no}`);
    console.log(`  Unknown (-1): ${s.veg_unknown}\n`);
    console.log('Gluten-free:');
    console.log(`  Yes (1): ${s.gf_yes}`);
    console.log(`  No (0): ${s.gf_no}`);
    console.log(`  Unknown (-1): ${s.gf_unknown}\n`);
    
    // Check which vegan=0 products have ingredients
    console.log('Checking vegan=0 products with ingredients...');
    const veganNoWithIng = await pool.query(`
      SELECT COUNT(DISTINCT p.barcode) as count
      FROM products p
      JOIN product_ingredients pi ON p.barcode = pi.product_barcode
      WHERE p.is_vegan = 0
    `);
    console.log(`  Products with is_vegan=0 AND ingredients: ${veganNoWithIng.rows[0].count}`);
    
    // Show sample
    console.log('\nSample vegan=0 products:');
    const sample = await pool.query(`
      SELECT barcode, name, is_vegan, is_vegetarian, is_gluten_free
      FROM products
      WHERE is_vegan = 0
      LIMIT 5
    `);
    sample.rows.forEach(p => {
      console.log(`  ${p.name} (${p.barcode})`);
      console.log(`    Vegan: ${p.is_vegan}, Vegetarian: ${p.is_vegetarian}, GF: ${p.is_gluten_free}`);
    });
    
  } catch (err) {
    console.error('Error:', err);
  } finally {
    await pool.end();
  }
}

debugProducts();
