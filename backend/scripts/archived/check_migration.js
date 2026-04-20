const { Pool } = require('pg');

const DATABASE_URL = process.env.DATABASE_URL || 'postgresql://postgres:cFGvTOMRZauZulyRoryYpJILFUszgorI@switchyard.proxy.rlwy.net:29111/railway';

const pool = new Pool({
  connectionString: DATABASE_URL,
});

async function checkMigration() {
  try {
    console.log('Checking migration status...\n');
    
    // Check tables exist
    const tables = await pool.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public'
      ORDER BY table_name
    `);
    
    console.log('=== Tables ===');
    tables.rows.forEach(row => console.log(`  - ${row.table_name}`));
    console.log('');
    
    // Check counts
    const queries = [
      { name: 'products (old)', query: 'SELECT COUNT(*) FROM products_old' },
      { name: 'products (new)', query: 'SELECT COUNT(*) FROM products' },
      { name: 'categories', query: 'SELECT COUNT(*) FROM categories' },
      { name: 'ingredients', query: 'SELECT COUNT(*) FROM ingredients' },
      { name: 'product_categories', query: 'SELECT COUNT(*) FROM product_categories' },
      { name: 'product_ingredients', query: 'SELECT COUNT(*) FROM product_ingredients' },
      { name: 'dietary_rules', query: 'SELECT COUNT(*) FROM dietary_rules' }
    ];
    
    console.log('=== Record Counts ===');
    for (const q of queries) {
      try {
        const result = await pool.query(q.query);
        console.log(`  ${q.name}: ${result.rows[0].count}`);
      } catch (err) {
        console.log(`  ${q.name}: [Table not found or error]`);
      }
    }
    console.log('');
    
    // Sample products
    try {
      const sample = await pool.query('SELECT * FROM products LIMIT 3');
      console.log('=== Sample Products ===');
      sample.rows.forEach(p => {
        console.log(`  Barcode: ${p.barcode}`);
        console.log(`  Name: ${p.name}`);
        console.log(`  Brand: ${p.brand}`);
        console.log(`  Vegan: ${p.is_vegan}, Vegetarian: ${p.is_vegetarian}`);
        console.log(`  Image: ${p.image_url}`);
        console.log('');
      });
    } catch (err) {
      console.log('  No products table yet');
    }
    
  } catch (err) {
    console.error('Error:', err.message);
  } finally {
    await pool.end();
  }
}

checkMigration();
