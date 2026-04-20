const { Pool } = require('pg');

const DATABASE_URL = process.env.DATABASE_URL || 'postgresql://postgres:cFGvTOMRZauZulyRoryYpJILFUszgorI@switchyard.proxy.rlwy.net:29111/railway';

const pool = new Pool({
  connectionString: DATABASE_URL,
});

async function resetDatabase() {
  try {
    console.log('Resetting database to start fresh...');
    
    // Drop all new tables
    await pool.query('DROP TABLE IF EXISTS product_ingredients CASCADE');
    await pool.query('DROP TABLE IF EXISTS product_categories CASCADE');
    await pool.query('DROP TABLE IF EXISTS dietary_rules CASCADE');
    await pool.query('DROP TABLE IF EXISTS ingredients CASCADE');
    await pool.query('DROP TABLE IF EXISTS categories CASCADE');
    await pool.query('DROP TABLE IF EXISTS products_new CASCADE');
    
    // Check if products_old exists, if so rename it back
    const checkOld = await pool.query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'products_old'
      )
    `);
    
    if (checkOld.rows[0].exists) {
      console.log('Restoring products_old to products...');
      await pool.query('DROP TABLE IF EXISTS products CASCADE');
      await pool.query('ALTER TABLE products_old RENAME TO products');
    } else {
      console.log('No products_old table found, keeping current products table');
    }
    
    console.log('✓ Database reset complete!');
    console.log('You can now run: node migrate_data.js');
    
  } catch (err) {
    console.error('Error:', err.message);
  } finally {
    await pool.end();
  }
}

resetDatabase();
