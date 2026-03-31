const { Pool } = require('pg');

const DATABASE_URL = process.env.DATABASE_URL || 'postgresql://postgres:cFGvTOMRZauZulyRoryYpJILFUszgorI@switchyard.proxy.rlwy.net:29111/railway';

const pool = new Pool({
  connectionString: DATABASE_URL,
});

async function checkProductSchema() {
  try {
    // Get table columns
    const columns = await pool.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'products'
      ORDER BY ordinal_position
    `);
    
    console.log('Products table columns:');
    columns.rows.forEach(col => {
      console.log(`  ${col.column_name}: ${col.data_type}`);
    });
    
    // Sample a product with ingredients
    console.log('\n\nSample product WITH ingredients:');
    const withIng = await pool.query(`
      SELECT p.*, COUNT(pi.ingredient_id) as ingredient_count
      FROM products p
      JOIN product_ingredients pi ON p.barcode = pi.product_barcode
      GROUP BY p.barcode
      LIMIT 1
    `);
    
    if (withIng.rows.length > 0) {
      console.log(JSON.stringify(withIng.rows[0], null, 2));
      
      // Show the ingredients
      console.log('\n  Ingredients for this product:');
      const ings = await pool.query(`
        SELECT i.name, i.normalized_name
        FROM product_ingredients pi
        JOIN ingredients i ON pi.ingredient_id = i.id
        WHERE pi.product_barcode = $1
      `, [withIng.rows[0].barcode]);
      
      ings.rows.forEach(ing => {
        console.log(`    - ${ing.normalized_name}`);
      });
    }
    
    // Sample a product without ingredients
    console.log('\n\nSample product WITHOUT ingredients:');
    const withoutIng = await pool.query(`
      SELECT *
      FROM products p
      WHERE barcode NOT IN (SELECT product_barcode FROM product_ingredients)
      LIMIT 1
    `);
    
    if (withoutIng.rows.length > 0) {
      console.log(JSON.stringify(withoutIng.rows[0], null, 2));
    }
    
  } catch (err) {
    console.error('Error:', err.message);
  } finally {
    await pool.end();
  }
}

checkProductSchema();
