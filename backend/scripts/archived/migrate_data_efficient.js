const fs = require('fs');
const readline = require('readline');
const { Pool } = require('pg');

const DATABASE_URL = process.env.DATABASE_URL || 'YOUR_RAILWAY_DATABASE_URL_HERE';

const pool = new Pool({
  connectionString: DATABASE_URL,
});

// Known ingredient dietary properties
const INGREDIENT_DIET_INFO = {
  // Vegan ingredients
  'en:water': { vegan: 1, vegetarian: 1, gluten_free: 1, dairy_free: 1 },
  'en:sugar': { vegan: 1, vegetarian: 1, gluten_free: 1, dairy_free: 1 },
  'en:salt': { vegan: 1, vegetarian: 1, gluten_free: 1, dairy_free: 1 },
  'en:carbon-dioxide': { vegan: 1, vegetarian: 1, gluten_free: 1, dairy_free: 1 },
  'en:carbonated-water': { vegan: 1, vegetarian: 1, gluten_free: 1, dairy_free: 1 },
  'en:fructose': { vegan: 1, vegetarian: 1, gluten_free: 1, dairy_free: 1 },
  'en:glucose': { vegan: 1, vegetarian: 1, gluten_free: 1, dairy_free: 1 },
  'en:rice': { vegan: 1, vegetarian: 1, gluten_free: 1, dairy_free: 1 },
  'en:corn': { vegan: 1, vegetarian: 1, gluten_free: 1, dairy_free: 1 },
  'en:soy': { vegan: 1, vegetarian: 1, gluten_free: 1, dairy_free: 1 },
  
  // Non-vegan ingredients
  'en:milk': { vegan: 0, vegetarian: 1, gluten_free: 1, dairy_free: 0 },
  'en:cream': { vegan: 0, vegetarian: 1, gluten_free: 1, dairy_free: 0 },
  'en:butter': { vegan: 0, vegetarian: 1, gluten_free: 1, dairy_free: 0 },
  'en:cheese': { vegan: 0, vegetarian: 1, gluten_free: 1, dairy_free: 0 },
  'en:whey': { vegan: 0, vegetarian: 1, gluten_free: 1, dairy_free: 0 },
  'en:egg': { vegan: 0, vegetarian: 1, gluten_free: 1, dairy_free: 1 },
  'en:honey': { vegan: 0, vegetarian: 1, gluten_free: 1, dairy_free: 1 },
  'en:gelatin': { vegan: 0, vegetarian: 0, gluten_free: 1, dairy_free: 1 },
  'en:gelatine': { vegan: 0, vegetarian: 0, gluten_free: 1, dairy_free: 1 },
  
  // Gluten ingredients
  'en:wheat': { vegan: 1, vegetarian: 1, gluten_free: 0, dairy_free: 1 },
  'en:barley': { vegan: 1, vegetarian: 1, gluten_free: 0, dairy_free: 1 },
  'en:rye': { vegan: 1, vegetarian: 1, gluten_free: 0, dairy_free: 1 },
  'en:wheat-flour': { vegan: 1, vegetarian: 1, gluten_free: 0, dairy_free: 1 },
};

// Helper function to format barcode for image URL
function formatImageUrl(barcode) {
  if (!barcode) return null;
  
  // Pad with zeros to 13 digits
  const paddedBarcode = barcode.padStart(13, '0');
  
  // Split into parts: 3-3-3-4
  const part1 = paddedBarcode.substring(0, 3);
  const part2 = paddedBarcode.substring(3, 6);
  const part3 = paddedBarcode.substring(6, 9);
  const part4 = paddedBarcode.substring(9, 13);
  
  return `https://images.openfoodfacts.org/images/products/${part1}/${part2}/${part3}/${part4}/1.jpg`;
}

// Helper to normalize ingredient name
function normalizeIngredient(name) {
  return name
    .toLowerCase()
    .replace(/^en:/, '')
    .replace(/-/g, ' ')
    .trim();
}

// Helper to get or create category
async function getOrCreateCategory(name, level, parentId, pathArray) {
  const existing = await pool.query(
    'SELECT id FROM categories WHERE name = $1',
    [name]
  );
  
  if (existing.rows.length > 0) {
    return existing.rows[0].id;
  }
  
  const result = await pool.query(
    `INSERT INTO categories (name, level, parent_id, path)
     VALUES ($1, $2, $3, $4)
     RETURNING id`,
    [name, level, parentId, pathArray]
  );
  
  return result.rows[0].id;
}

// Helper to get or create ingredient
async function getOrCreateIngredient(tag) {
  const normalized = normalizeIngredient(tag);
  
  const existing = await pool.query(
    'SELECT id FROM ingredients WHERE name = $1',
    [tag]
  );
  
  if (existing.rows.length > 0) {
    return existing.rows[0].id;
  }
  
  const dietInfo = INGREDIENT_DIET_INFO[tag] || {};
  
  const result = await pool.query(
    `INSERT INTO ingredients 
     (name, normalized_name, is_vegan, is_vegetarian, is_gluten_free, is_dairy_free, allergen_tags)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING id`,
    [
      tag,
      normalized,
      dietInfo.vegan ?? -1,
      dietInfo.vegetarian ?? -1,
      dietInfo.gluten_free ?? -1,
      dietInfo.dairy_free ?? -1,
      []
    ]
  );
  
  return result.rows[0].id;
}

// Find product data in JSONL by barcode (memory efficient - stops after finding)
async function findProductInJSONL(targetBarcode) {
  const fileStream = fs.createReadStream('./openfoodfacts-products.jsonl');
  const rl = readline.createInterface({
    input: fileStream,
    crlfDelay: Infinity
  });
  
  try {
    for await (const line of rl) {
      try {
        const product = JSON.parse(line);
        if (product.code === targetBarcode) {
          rl.close();
          fileStream.destroy();
          return product;
        }
      } catch (err) {
        // Skip invalid lines
      }
    }
  } catch (err) {
    // File stream closed early (expected when we find the product)
  }
  
  return null;
}

async function migrateData() {
  console.log('Starting memory-efficient migration...');
  
  try {
    // 1. Run schema migration
    console.log('Creating new schema...');
    const schema = fs.readFileSync('./migrate_schema.sql', 'utf8');
    await pool.query(schema);
    console.log('Schema created successfully!');
    
    // 2. Get first 1000 products from database (limit to what's there)
    console.log('Fetching products from database...');
    const oldProducts = await pool.query(`
      SELECT barcode, name, categories, ingredients, image_url
      FROM products
      WHERE barcode IS NOT NULL AND barcode != ''
      ORDER BY id
      LIMIT 1000
    `);
    
    console.log(`Found ${oldProducts.rows.length} products to migrate`);
    
    // 3. Process each product individually (memory efficient)
    let migratedCount = 0;
    
    for (const row of oldProducts.rows) {
      const barcode = row.barcode;
      
      // Search for product in JSONL file (stops after finding)
      console.log(`[${migratedCount + 1}/${oldProducts.rows.length}] Processing barcode: ${barcode}`);
      const fullProduct = await findProductInJSONL(barcode);
      
      // Determine dietary properties
      let dietProps = { is_vegan: -1, is_vegetarian: -1, is_gluten_free: -1, is_dairy_free: -1 };
      if (fullProduct?.ingredients_analysis_tags) {
        if (fullProduct.ingredients_analysis_tags.includes('en:vegan')) dietProps.is_vegan = 1;
        else if (fullProduct.ingredients_analysis_tags.includes('en:non-vegan')) dietProps.is_vegan = 0;
        
        if (fullProduct.ingredients_analysis_tags.includes('en:vegetarian')) dietProps.is_vegetarian = 1;
        else if (fullProduct.ingredients_analysis_tags.includes('en:non-vegetarian')) dietProps.is_vegetarian = 0;
      }
      
      const brand = fullProduct?.brands || null;
      const imageUrl = formatImageUrl(barcode);
      
      // Insert into products_new table
      await pool.query(
        `INSERT INTO products_new (barcode, name, brand, image_url, is_vegan, is_vegetarian, is_gluten_free, is_dairy_free)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         ON CONFLICT (barcode) DO UPDATE SET
         name = EXCLUDED.name,
         brand = EXCLUDED.brand,
         image_url = EXCLUDED.image_url,
         is_vegan = EXCLUDED.is_vegan,
         is_vegetarian = EXCLUDED.is_vegetarian`,
        [barcode, row.name, brand, imageUrl, dietProps.is_vegan, dietProps.is_vegetarian, dietProps.is_gluten_free, dietProps.is_dairy_free]
      );
      
      // Process categories
      if (fullProduct?.categories_hierarchy && Array.isArray(fullProduct.categories_hierarchy)) {
        let parentId = null;
        const pathArray = [];
        
        for (let i = 0; i < fullProduct.categories_hierarchy.length; i++) {
          const categoryName = fullProduct.categories_hierarchy[i];
          pathArray.push(categoryName);
          
          const categoryId = await getOrCreateCategory(categoryName, i, parentId, pathArray);
          
          await pool.query(
            `INSERT INTO product_categories (product_barcode, category_id)
             VALUES ($1, $2)
             ON CONFLICT DO NOTHING`,
            [barcode, categoryId]
          );
          
          parentId = categoryId;
        }
      }
      
      // Process ingredients
      if (fullProduct?.ingredients_tags && Array.isArray(fullProduct.ingredients_tags)) {
        for (const ingredientTag of fullProduct.ingredients_tags) {
          const ingredientId = await getOrCreateIngredient(ingredientTag);
          
          await pool.query(
            `INSERT INTO product_ingredients (product_barcode, ingredient_id)
             VALUES ($1, $2)
             ON CONFLICT DO NOTHING`,
            [barcode, ingredientId]
          );
        }
      }
      
      migratedCount++;
      if (migratedCount % 50 === 0) {
        console.log(`Progress: ${migratedCount}/${oldProducts.rows.length} products migrated`);
      }
    }
    
    console.log(`\nMigration complete! Migrated ${migratedCount} products.`);
    
    // 5. Rename tables
    console.log('Renaming tables...');
    await pool.query('ALTER TABLE products RENAME TO products_old');
    await pool.query('ALTER TABLE products_new RENAME TO products');
    
    // 6. Print summary
    console.log('\n=== Migration Summary ===');
    const productCount = await pool.query('SELECT COUNT(*) FROM products');
    console.log(`Products: ${productCount.rows[0].count}`);
    
    const categoryCount = await pool.query('SELECT COUNT(*) FROM categories');
    console.log(`Categories: ${categoryCount.rows[0].count}`);
    
    const ingredientCount = await pool.query('SELECT COUNT(*) FROM ingredients');
    console.log(`Ingredients: ${ingredientCount.rows[0].count}`);
    
    const productCategoriesCount = await pool.query('SELECT COUNT(*) FROM product_categories');
    console.log(`Product-Category links: ${productCategoriesCount.rows[0].count}`);
    
    const productIngredientsCount = await pool.query('SELECT COUNT(*) FROM product_ingredients');
    console.log(`Product-Ingredient links: ${productIngredientsCount.rows[0].count}`);
    
    const dietaryRulesCount = await pool.query('SELECT COUNT(*) FROM dietary_rules');
    console.log(`Dietary rules: ${dietaryRulesCount.rows[0].count}`);
    
    console.log('\n✓ Migration completed successfully!');
    
  } catch (err) {
    console.error('Migration error:', err);
    throw err;
  } finally {
    await pool.end();
  }
}

migrateData().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
