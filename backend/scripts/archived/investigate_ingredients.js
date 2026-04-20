const { Pool } = require('pg');

const DATABASE_URL = process.env.DATABASE_URL || 'postgresql://postgres:cFGvTOMRZauZulyRoryYpJILFUszgorI@switchyard.proxy.rlwy.net:29111/railway';

const pool = new Pool({
  connectionString: DATABASE_URL,
});

async function investigateIngredients() {
  try {
    console.log('Investigating ingredient linking...\n');
    
    // Products with vs without ingredients
    const productStats = await pool.query(`
      SELECT 
        COUNT(*) as total_products,
        COUNT(DISTINCT pi.product_barcode) as products_with_ingredients,
        COUNT(*) - COUNT(DISTINCT pi.product_barcode) as products_without_ingredients
      FROM products p
      LEFT JOIN product_ingredients pi ON p.barcode = pi.product_barcode
    `);
    
    console.log('Product-Ingredient Link Status:');
    console.log(`  Total products: ${productStats.rows[0].total_products}`);
    console.log(`  Products WITH ingredients: ${productStats.rows[0].products_with_ingredients}`);
    console.log(`  Products WITHOUT ingredients: ${productStats.rows[0].products_without_ingredients}`);
    
    // Check if products have ingredients_text but no links
    const textVsLinks = await pool.query(`
      SELECT 
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE ingredients_text IS NOT NULL AND ingredients_text != '') as has_text,
        COUNT(*) FILTER (WHERE barcode IN (SELECT product_barcode FROM product_ingredients)) as has_links
      FROM products
    `);
    
    console.log('\nIngredients Text vs Links:');
    console.log(`  Total products: ${textVsLinks.rows[0].total}`);
    console.log(`  Products with ingredients_text: ${textVsLinks.rows[0].has_text}`);
    console.log(`  Products with ingredient links: ${textVsLinks.rows[0].has_links}`);
    
    // Sample products without ingredients
    console.log('\nSample products WITHOUT ingredient links:');
    const withoutLinks = await pool.query(`
      SELECT name, barcode, 
             SUBSTRING(ingredients_text, 1, 100) as ingredients_preview
      FROM products
      WHERE barcode NOT IN (SELECT product_barcode FROM product_ingredients)
      AND ingredients_text IS NOT NULL
      LIMIT 5
    `);
    
    withoutLinks.rows.forEach(p => {
      console.log(`\n  ${p.name} (${p.barcode})`);
      console.log(`    Text: ${p.ingredients_preview}...`);
    });
    
    // Sample products WITH ingredients
    console.log('\n\nSample products WITH ingredient links:');
    const withLinks = await pool.query(`
      SELECT p.name, p.barcode, COUNT(pi.ingredient_id) as ingredient_count,
             SUBSTRING(p.ingredients_text, 1, 100) as ingredients_preview
      FROM products p
      JOIN product_ingredients pi ON p.barcode = pi.product_barcode
      GROUP BY p.name, p.barcode, p.ingredients_text
      LIMIT 5
    `);
    
    withLinks.rows.forEach(p => {
      console.log(`\n  ${p.name} (${p.barcode})`);
      console.log(`    Linked ingredients: ${p.ingredient_count}`);
      console.log(`    Text: ${p.ingredients_preview}...`);
    });
    
  } catch (err) {
    console.error('Error:', err.message);
    console.error(err.stack);
  } finally {
    await pool.end();
  }
}

investigateIngredients();
