const fs = require('fs');
const readline = require('readline');
const { Pool } = require('pg');

// Set this to your Railway DATABASE_URL
// Get it from Railway: Project → PostgreSQL → Variables → DATABASE_URL
const DATABASE_URL = process.env.DATABASE_URL || 'YOUR_RAILWAY_DATABASE_URL_HERE';

const pool = new Pool({
  connectionString: DATABASE_URL,
});

async function importProducts() {
  console.log('Connecting to database...');
  
  try {
    // 1. Create table
    console.log('Creating products table...');
    await pool.query(`
      CREATE TABLE IF NOT EXISTS products (
        id SERIAL PRIMARY KEY,
        name TEXT,
        categories TEXT,
        ingredients TEXT,
        barcode TEXT UNIQUE,
        image_url TEXT
      );
    `);
    console.log('Table created');

    // 2. Read and import products
    console.log('Reading JSONL file...');
    const fileStream = fs.createReadStream('openfoodfacts-products.jsonl');
    const rl = readline.createInterface({
      input: fileStream,
      crlfDelay: Infinity
    });

    let count = 0;
    let imported = 0;
    const MAX_PRODUCTS = 1000; // Import first 1000 products

    for await (const line of rl) {
      if (count >= MAX_PRODUCTS) break;
      
      try {
        const p = JSON.parse(line);
        
        // Only import if it has a barcode
        if (p.code) {
          await pool.query(
            `INSERT INTO products (name, categories, ingredients, barcode, image_url)
             VALUES ($1, $2, $3, $4, $5)
             ON CONFLICT (barcode) DO NOTHING`,
            [
              p.product_name || null,
              p.categories || null,
              p.ingredients_text || null,
              p.code,
              p.image_url || p.image_front_url || p.image_front_small_url || null
            ]
          );
          imported++;
          
          if (imported % 100 === 0) {
            console.log(`Imported ${imported} products...`);
          }
        }
        count++;
      } catch (err) {
        // Skip invalid lines
      }
    }

    console.log(`\nImport complete! Imported ${imported} products.`);
    
  } catch (err) {
    console.error('Error:', err.message);
  } finally {
    await pool.end();
  }
}

importProducts();
