const fs = require('fs');
const readline = require('readline');
const { Pool } = require('pg');

const DATABASE_URL = process.env.DATABASE_URL || 'postgresql://postgres:cFGvTOMRZauZulyRoryYpJILFUszgorI@switchyard.proxy.rlwy.net:29111/railway';

const pool = new Pool({
  connectionString: DATABASE_URL,
});

// Known ingredient dietary properties
const INGREDIENT_DIET_INFO = {
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
  'en:milk': { vegan: 0, vegetarian: 1, gluten_free: 1, dairy_free: 0 },
  'en:cream': { vegan: 0, vegetarian: 1, gluten_free: 1, dairy_free: 0 },
  'en:butter': { vegan: 0, vegetarian: 1, gluten_free: 1, dairy_free: 0 },
  'en:cheese': { vegan: 0, vegetarian: 1, gluten_free: 1, dairy_free: 0 },
  'en:whey': { vegan: 0, vegetarian: 1, gluten_free: 1, dairy_free: 0 },
  'en:egg': { vegan: 0, vegetarian: 1, gluten_free: 1, dairy_free: 1 },
  'en:honey': { vegan: 0, vegetarian: 1, gluten_free: 1, dairy_free: 1 },
  'en:gelatin': { vegan: 0, vegetarian: 0, gluten_free: 1, dairy_free: 1 },
  'en:gelatine': { vegan: 0, vegetarian: 0, gluten_free: 1, dairy_free: 1 },
  'en:wheat': { vegan: 1, vegetarian: 1, gluten_free: 0, dairy_free: 1 },
  'en:barley': { vegan: 1, vegetarian: 1, gluten_free: 0, dairy_free: 1 },
  'en:rye': { vegan: 1, vegetarian: 1, gluten_free: 0, dairy_free: 1 },
  'en:wheat-flour': { vegan: 1, vegetarian: 1, gluten_free: 0, dairy_free: 1 },
};

const categoryCache = new Map();
const ingredientCache = new Map();

function formatImageUrl(barcode) {
  if (!barcode) return null;
  const paddedBarcode = barcode.padStart(13, '0');
  return `https://images.openfoodfacts.org/images/products/${paddedBarcode.substring(0,3)}/${paddedBarcode.substring(3,6)}/${paddedBarcode.substring(6,9)}/${paddedBarcode.substring(9,13)}/1.jpg`;
}

function getDietaryProperties(tags) {
  const props = { is_vegan: -1, is_vegetarian: -1, is_gluten_free: -1, is_dairy_free: -1 };
  if (!tags || !Array.isArray(tags)) return props;
  if (tags.includes('en:vegan')) props.is_vegan = 1;
  else if (tags.includes('en:non-vegan')) props.is_vegan = 0;
  if (tags.includes('en:vegetarian')) props.is_vegetarian = 1;
  else if (tags.includes('en:non-vegetarian')) props.is_vegetarian = 0;
  return props;
}

function normalizeIngredient(name) {
  return name.toLowerCase().replace(/^en:/, '').replace(/-/g, ' ').trim();
}

async function migrateData() {
  console.log('Starting optimized migration...');
  
  try {
    console.log('Creating schema...');
    const schema = fs.readFileSync('./migrate_schema.sql', 'utf8');
    await pool.query(schema);
    console.log('✓ Schema created');
    
    console.log('Checking for already migrated products...');
    const alreadyMigrated = await pool.query('SELECT barcode FROM products_new');
    const migratedBarcodes = new Set(alreadyMigrated.rows.map(r => r.barcode));
    console.log(`✓ Found ${migratedBarcodes.size} already migrated`);
    
    console.log('Fetching products to migrate...');
    const oldProducts = await pool.query(`
      SELECT barcode, name, categories, ingredients, image_url
      FROM products
      WHERE barcode IS NOT NULL AND barcode != ''
      ORDER BY id
      LIMIT 1000
    `);
    
    const productsToMigrate = oldProducts.rows.filter(row => !migratedBarcodes.has(row.barcode));
    console.log(`✓ ${productsToMigrate.length} products to migrate (${migratedBarcodes.size} already done)`);
    
    if (productsToMigrate.length === 0) {
      console.log('All products migrated!');
      return;
    }
    
    const barcodesToFind = new Set(productsToMigrate.map(r => r.barcode));
    
    console.log('Scanning JSONL file...');
    const productMap = new Map();
    const fileStream = fs.createReadStream('./openfoodfacts-products.jsonl');
    const rl = readline.createInterface({ input: fileStream, crlfDelay: Infinity });
    
    let lineCount = 0;
    for await (const line of rl) {
      try {
        const product = JSON.parse(line);
        if (product.code && barcodesToFind.has(product.code)) {
          productMap.set(product.code, product);
          if (productMap.size === barcodesToFind.size) {
            rl.close();
            fileStream.destroy();
            break;
          }
        }
        lineCount++;
        if (lineCount % 50000 === 0) {
          console.log(`  Scanned ${lineCount} lines, found ${productMap.size}/${barcodesToFind.size}`);
        }
      } catch (err) {}
    }
    
    console.log(`✓ Loaded ${productMap.size} products from JSONL`);
    
    console.log('Loading existing categories and ingredients...');
    const existingCats = await pool.query('SELECT id, name FROM categories');
    existingCats.rows.forEach(row => categoryCache.set(row.name, row.id));
    const existingIngs = await pool.query('SELECT id, name FROM ingredients');
    existingIngs.rows.forEach(row => ingredientCache.set(row.name, row.id));
    console.log(`✓ Cached ${categoryCache.size} categories, ${ingredientCache.size} ingredients`);
    
    console.log('Collecting unique categories and ingredients...');
    const allCategories = new Map();
    const allIngredients = new Set();
    
    for (const row of productsToMigrate) {
      const fullProduct = productMap.get(row.barcode);
      if (!fullProduct) continue;
      
      if (fullProduct.categories_hierarchy && Array.isArray(fullProduct.categories_hierarchy)) {
        let parentName = null;
        const pathArray = [];
        for (let i = 0; i < fullProduct.categories_hierarchy.length; i++) {
          const catName = fullProduct.categories_hierarchy[i];
          pathArray.push(catName);
          if (!categoryCache.has(catName) && !allCategories.has(catName)) {
            allCategories.set(catName, { level: i, parent: parentName, path: [...pathArray] });
          }
          parentName = catName;
        }
      }
      
      if (fullProduct.ingredients_tags && Array.isArray(fullProduct.ingredients_tags)) {
        fullProduct.ingredients_tags.forEach(tag => {
          if (!ingredientCache.has(tag)) allIngredients.add(tag);
        });
      }
    }
    
    console.log(`✓ Found ${allCategories.size} new categories, ${allIngredients.size} new ingredients`);
    
    if (allCategories.size > 0) {
      console.log('Batch inserting categories...');
      const catValues = [];
      const catParams = [];
      let idx = 1;
      for (const [name, data] of allCategories) {
        catValues.push(`($${idx}, $${idx+1}, $${idx+2})`);
        catParams.push(name, data.level, `{${data.path.join(',')}}`);
        idx += 3;
      }
      if (catValues.length > 0) {
        await pool.query(`INSERT INTO categories (name, level, path) VALUES ${catValues.join(', ')} ON CONFLICT DO NOTHING`, catParams);
      }
      
      const allCats = await pool.query('SELECT id, name FROM categories');
      categoryCache.clear();
      allCats.rows.forEach(row => categoryCache.set(row.name, row.id));
      
      for (const [name, data] of allCategories) {
        if (data.parent) {
          const parentId = categoryCache.get(data.parent);
          const childId = categoryCache.get(name);
          if (parentId && childId) {
            await pool.query('UPDATE categories SET parent_id = $1 WHERE id = $2', [parentId, childId]);
          }
        }
      }
      console.log('✓ Categories inserted');
    }
    
    if (allIngredients.size > 0) {
      console.log('Batch inserting ingredients...');
      const ingValues = [];
      const ingParams = [];
      let idx = 1;
      for (const tag of allIngredients) {
        const normalized = normalizeIngredient(tag);
        const dietInfo = INGREDIENT_DIET_INFO[tag] || {};
        ingValues.push(`($${idx}, $${idx+1}, $${idx+2}, $${idx+3}, $${idx+4}, $${idx+5}, $${idx+6})`);
        ingParams.push(tag, normalized, dietInfo.vegan ?? -1, dietInfo.vegetarian ?? -1, dietInfo.gluten_free ?? -1, dietInfo.dairy_free ?? -1, '{}');
        idx += 7;
      }
      if (ingValues.length > 0) {
        await pool.query(`INSERT INTO ingredients (name, normalized_name, is_vegan, is_vegetarian, is_gluten_free, is_dairy_free, allergen_tags) VALUES ${ingValues.join(', ')} ON CONFLICT DO NOTHING`, ingParams);
      }
      
      const allIngs = await pool.query('SELECT id, name FROM ingredients');
      ingredientCache.clear();
      allIngs.rows.forEach(row => ingredientCache.set(row.name, row.id));
      console.log('✓ Ingredients inserted');
    }
    
    console.log('Batch inserting products...');
    const prodValues = [];
    const prodParams = [];
    const prodCatLinks = [];
    const prodIngLinks = [];
    let idx = 1;
    
    for (const row of productsToMigrate) {
      const barcode = row.barcode;
      const fullProduct = productMap.get(barcode);
      const dietProps = fullProduct ? getDietaryProperties(fullProduct.ingredients_analysis_tags) : { is_vegan: -1, is_vegetarian: -1, is_gluten_free: -1, is_dairy_free: -1 };
      const brand = fullProduct?.brands || null;
      const imageUrl = formatImageUrl(barcode);
      
      prodValues.push(`($${idx}, $${idx+1}, $${idx+2}, $${idx+3}, $${idx+4}, $${idx+5}, $${idx+6}, $${idx+7})`);
      prodParams.push(barcode, row.name, brand, imageUrl, dietProps.is_vegan, dietProps.is_vegetarian, dietProps.is_gluten_free, dietProps.is_dairy_free);
      idx += 8;
      
      if (fullProduct?.categories_hierarchy) {
        for (const catName of fullProduct.categories_hierarchy) {
          const categoryId = categoryCache.get(catName);
          if (categoryId) prodCatLinks.push([barcode, categoryId]);
        }
      }
      
      if (fullProduct?.ingredients_tags) {
        for (const tag of fullProduct.ingredients_tags) {
          const ingredientId = ingredientCache.get(tag);
          if (ingredientId) prodIngLinks.push([barcode, ingredientId]);
        }
      }
    }
    
    if (prodValues.length > 0) {
      await pool.query(`INSERT INTO products_new (barcode, name, brand, image_url, is_vegan, is_vegetarian, is_gluten_free, is_dairy_free) VALUES ${prodValues.join(', ')} ON CONFLICT (barcode) DO NOTHING`, prodParams);
    }
    console.log('✓ Products inserted');
    
    console.log('Batch inserting product-category links...');
    if (prodCatLinks.length > 0) {
      const linkValues = prodCatLinks.map((_, i) => `($${i*2+1}, $${i*2+2})`);
      const linkParams = prodCatLinks.flat();
      for (let i = 0; i < linkValues.length; i += 1000) {
        const chunk = linkValues.slice(i, i+1000);
        const params = linkParams.slice(i*2, (i+1000)*2);
        if (chunk.length > 0 && params.length > 0) {
          await pool.query(`INSERT INTO product_categories (product_barcode, category_id) VALUES ${chunk.join(', ')} ON CONFLICT DO NOTHING`, params);
        }
      }
    }
    console.log('✓ Product-category links inserted');
    
    console.log('Batch inserting product-ingredient links...');
    if (prodIngLinks.length > 0) {
      const linkValues = prodIngLinks.map((_, i) => `($${i*2+1}, $${i*2+2})`);
      const linkParams = prodIngLinks.flat();
      for (let i = 0; i < linkValues.length; i += 1000) {
        const chunk = linkValues.slice(i, i+1000);
        const params = linkParams.slice(i*2, (i+1000)*2);
        if (chunk.length > 0 && params.length > 0) {
          await pool.query(`INSERT INTO product_ingredients (product_barcode, ingredient_id) VALUES ${chunk.join(', ')} ON CONFLICT DO NOTHING`, params);
        }
      }
    }
    console.log('✓ Product-ingredient links inserted');
    
    const totalMigrated = await pool.query('SELECT COUNT(*) FROM products_new');
    console.log(`\n✓ Migration batch complete! Total: ${totalMigrated.rows[0].count}/1000`);
    
    if (parseInt(totalMigrated.rows[0].count) >= 1000) {
      console.log('All products migrated! Renaming tables...');
      const oldTableExists = await pool.query(`SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'products_old')`);
      if (!oldTableExists.rows[0].exists) {
        await pool.query('ALTER TABLE products RENAME TO products_old');
      }
      await pool.query('ALTER TABLE products_new RENAME TO products');
      console.log('✓ Tables renamed!');
    }
    
    console.log('\n=== Summary ===');
    const stats = await Promise.all([
      pool.query('SELECT COUNT(*) FROM products_new'),
      pool.query('SELECT COUNT(*) FROM categories'),
      pool.query('SELECT COUNT(*) FROM ingredients'),
      pool.query('SELECT COUNT(*) FROM product_categories'),
      pool.query('SELECT COUNT(*) FROM product_ingredients'),
      pool.query('SELECT COUNT(*) FROM dietary_rules')
    ]);
    console.log(`Products: ${stats[0].rows[0].count}`);
    console.log(`Categories: ${stats[1].rows[0].count}`);
    console.log(`Ingredients: ${stats[2].rows[0].count}`);
    console.log(`Product-Category links: ${stats[3].rows[0].count}`);
    console.log(`Product-Ingredient links: ${stats[4].rows[0].count}`);
    console.log(`Dietary rules: ${stats[5].rows[0].count}`);
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
