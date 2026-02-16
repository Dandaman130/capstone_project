// file: backend/scripts/importSample.js
const fs = require('fs');
const readline = require('readline');
// const { Pool } = require('pg');

// Connect to Railway Postgres (set DATABASE_URL in Railway project settings)
/* const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
}); */

async function run() {
  const cleaned = [];
  
  // Search for specific barcode
  const SEARCH_BARCODE = '5449000054227'; // Change this to search for different products
  
  // 1. Read JSONL file line-by-line (memory efficient)
  const fileStream = fs.createReadStream('openfoodfacts-products.jsonl');
  const rl = readline.createInterface({
    input: fileStream,
    crlfDelay: Infinity
  });
  
  let lineCount = 0;
  for await (const line of rl) {
    lineCount++;
    
    // Skip to line 490000 to speed up search
    if (lineCount < 490000) continue;
    
    // Show progress every 10,000 lines
    if (lineCount % 10000 === 0) {
      console.log(`Searched ${lineCount} products...`);
    }
    
    try {
      const p = JSON.parse(line);
      
      // Search for specific barcode
      if (p.code === SEARCH_BARCODE) {
        console.log('\nFound product! Writing all fields to product_data.json');
        
        // Write full product data to file
        fs.writeFileSync('product_data.json', JSON.stringify(p, null, 2));
        
        console.log('\nAll field names in this product:');
        console.log(Object.keys(p).sort());
        
        console.log('\nImage-related fields:');
        const imageFields = Object.keys(p).filter(key => key.toLowerCase().includes('image'));
        imageFields.forEach(field => {
          console.log(`${field}: ${p[field]}`);
        });
        
        break; // Stop after finding the product
      }
    } catch (err) {
      // Skip invalid JSON lines
    }
  }

  // 3. Create table if not exists
  /* await pool.query(`
    CREATE TABLE IF NOT EXISTS products (
      id SERIAL PRIMARY KEY,
      name TEXT,
      categories TEXT,
      ingredients TEXT,
      barcode TEXT UNIQUE,
      image_url TEXT
    ); 
  `); */ 

  /* 4. Insert sample products
  for (const product of cleaned) {
    await pool.query(
      `INSERT INTO products (name, categories, ingredients, barcode, image_url)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (barcode) DO NOTHING`,
      [product.name, product.categories, product.ingredients, product.barcode, product.image_url]
    );
  } */

  console.log('Search complete');
  // await pool.end();
}

run().catch(err => console.error(err));
