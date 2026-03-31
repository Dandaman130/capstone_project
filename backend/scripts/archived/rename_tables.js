const { Pool } = require('pg');

const DATABASE_URL = process.env.DATABASE_URL || 'postgresql://postgres:cFGvTOMRZauZulyRoryYpJILFUszgorI@switchyard.proxy.rlwy.net:29111/railway';

const pool = new Pool({
  connectionString: DATABASE_URL,
});

async function renameTables() {
  try {
    console.log('Renaming tables...');
    
    // Check if products_old exists
    const oldExists = await pool.query(`
      SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'products_old')
    `);
    
    if (!oldExists.rows[0].exists) {
      console.log('Renaming products to products_old...');
      await pool.query('ALTER TABLE products RENAME TO products_old');
    } else {
      console.log('products_old already exists');
    }
    
    console.log('Renaming products_new to products...');
    await pool.query('ALTER TABLE products_new RENAME TO products');
    
    console.log('\n✓ Tables renamed successfully!');
    console.log('  - products (old) → products_old (backup)');
    console.log('  - products_new → products (active)');
    
  } catch (err) {
    console.error('Error:', err.message);
  } finally {
    await pool.end();
  }
}

renameTables();
