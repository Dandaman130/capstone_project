const fs = require('fs');
const readline = require('readline');
const { Pool } = require('pg');

const DATABASE_URL = process.env.DATABASE_URL || 'postgresql://postgres:cFGvTOMRZauZulyRoryYpJILFUszgorI@switchyard.proxy.rlwy.net:29111/railway';

const pool = new Pool({
  connectionString: DATABASE_URL,
});

// Known ingredients with 100% confidence
const KNOWN_INGREDIENTS = {
  'en:water': { vegan: 100, vegetarian: 100, gluten_free: 100, dairy_free: 100 },
  'en:sugar': { vegan: 100, vegetarian: 100, gluten_free: 100, dairy_free: 100 },
  'en:salt': { vegan: 100, vegetarian: 100, gluten_free: 100, dairy_free: 100 },
  'en:milk': { not_vegan: 100, vegetarian: 100, gluten_free: 100, not_dairy_free: 100 },
  'en:cream': { not_vegan: 100, vegetarian: 100, gluten_free: 100, not_dairy_free: 100 },
  'en:butter': { not_vegan: 100, vegetarian: 100, gluten_free: 100, not_dairy_free: 100 },
  'en:cheese': { not_vegan: 100, vegetarian: 100, gluten_free: 100, not_dairy_free: 100 },
  'en:whey': { not_vegan: 100, vegetarian: 100, gluten_free: 100, not_dairy_free: 100 },
  'en:egg': { not_vegan: 100, vegetarian: 100, gluten_free: 100, dairy_free: 100 },
  'en:honey': { not_vegan: 100, vegetarian: 100, gluten_free: 100, dairy_free: 100 },
  'en:gelatin': { not_vegan: 100, not_vegetarian: 100, gluten_free: 100, dairy_free: 100 },
  'en:gelatine': { not_vegan: 100, not_vegetarian: 100, gluten_free: 100, dairy_free: 100 },
  'en:wheat': { vegan: 100, vegetarian: 100, contains_gluten: 100, dairy_free: 100 },
  'en:barley': { vegan: 100, vegetarian: 100, contains_gluten: 100, dairy_free: 100 },
  'en:rye': { vegan: 100, vegetarian: 100, contains_gluten: 100, dairy_free: 100 },
  'en:wheat-flour': { vegan: 100, vegetarian: 100, contains_gluten: 100, dairy_free: 100 },
};

const categoryCache = new Map();
const ingredientCache = new Map();

function normalizeIngredient(name) {
  return name.toLowerCase().replace(/^en:/, '').replace(/-/g, ' ').trim();
}

function formatImageUrl(barcode) {
  if (!barcode) return null;
  const paddedBarcode = barcode.padStart(13, '0');
  return `https://images.openfoodfacts.org/images/products/${paddedBarcode.substring(0,3)}/${paddedBarcode.substring(3,6)}/${paddedBarcode.substring(6,9)}/${paddedBarcode.substring(9,13)}/1.jpg`;
}

function extractDietaryTags(labels_tags) {
  const props = { is_vegan: -1, is_vegetarian: -1, is_gluten_free: -1, is_dairy_free: -1 };
  if (!labels_tags || !Array.isArray(labels_tags)) return props;
  
  if (labels_tags.includes('en:vegan')) props.is_vegan = 1;
  else if (labels_tags.includes('en:non-vegan')) props.is_vegan = 0;
  
  if (labels_tags.includes('en:vegetarian')) props.is_vegetarian = 1;
  else if (labels_tags.includes('en:non-vegetarian')) props.is_vegetarian = 0;
  
  if (labels_tags.includes('en:gluten-free') || labels_tags.includes('en:no-gluten')) {
    props.is_gluten_free = 1;
  }
  
  if (labels_tags.includes('en:no-lactose') || labels_tags.includes('en:dairy-free')) {
    props.is_dairy_free = 1;
  }
  
  return props;
}

async function migrate100k() {
  console.log('=== Migrating 100k Products from JSONL ===\n');
  const startTime = Date.now();
  
  try {
    // Step 1: Create schema
    console.log('Step 1: Creating database schema...');
    const schema = fs.readFileSync('./migrate_schema_v2.sql', 'utf8');
    await pool.query(schema);
    console.log('Schema created\n');
    
    // Step 2: Load existing data into cache
    console.log('Step 2: Loading existing categories and ingredients...');
    const existingCats = await pool.query('SELECT id, name FROM categories');
    existingCats.rows.forEach(row => categoryCache.set(row.name, row.id));
    
    const existingIngs = await pool.query('SELECT id, name FROM ingredients');
    existingIngs.rows.forEach(row => ingredientCache.set(row.name, row.id));
    console.log(`Cached ${categoryCache.size} categories, ${ingredientCache.size} ingredients\n`);
    
    // Step 3: Read JSONL and collect data
    console.log('Step 3: Reading JSONL file (first 100k products)...');
    const fileStream = fs.createReadStream('./openfoodfacts-products.jsonl');
    const rl = readline.createInterface({ input: fileStream, crlfDelay: Infinity });
    
    const products = [];
    const allCategories = new Map(); // name -> {level, parent, path}
    const allIngredients = new Set();
    const productCategoryLinks = [];
    const productIngredientLinks = [];
    
    let lineCount = 0;
    let validProducts = 0;
    
    for await (const line of rl) {
      try {
        const product = JSON.parse(line);
        
        // Skip if missing essential data
        if (!product.code || !product.product_name) continue;
        
        const barcode = product.code;
        const name = product.product_name;
        const brand = product.brands || null;
        const imageUrl = formatImageUrl(barcode);
        const dietaryProps = extractDietaryTags(product.labels_tags);
        
        products.push({
          barcode,
          name,
          brand,
          imageUrl,
          ...dietaryProps
        });
        
        // Extract categories with hierarchy
        if (product.categories_hierarchy && Array.isArray(product.categories_hierarchy)) {
          let parentName = null;
          const pathArray = [];
          
          for (let i = 0; i < product.categories_hierarchy.length; i++) {
            const catName = product.categories_hierarchy[i];
            pathArray.push(catName);
            
            if (!categoryCache.has(catName) && !allCategories.has(catName)) {
              allCategories.set(catName, {
                level: i,
                parent: parentName,
                path: [...pathArray]
              });
            }
            
            productCategoryLinks.push({ barcode, category: catName });
            parentName = catName;
          }
        }
        
        // Extract ingredients
        if (product.ingredients_tags && Array.isArray(product.ingredients_tags)) {
          product.ingredients_tags.forEach(tag => {
            if (!ingredientCache.has(tag)) {
              allIngredients.add(tag);
            }
            productIngredientLinks.push({ barcode, ingredient: tag });
          });
        }
        
        validProducts++;
        
      } catch (err) {
        // Skip malformed lines
      }
      
      lineCount++;
      if (lineCount % 10000 === 0) {
        console.log(`  Processed ${lineCount} lines, ${validProducts} valid products...`);
      }
      
      if (lineCount >= 100000) {
        rl.close();
        fileStream.destroy();
        break;
      }
    }
    
    console.log(`Collected ${validProducts} valid products`);
    console.log(`  - ${allCategories.size} new categories`);
    console.log(`  - ${allIngredients.size} new ingredients`);
    console.log(`  - ${productCategoryLinks.length} product-category links`);
    console.log(`  - ${productIngredientLinks.length} product-ingredient links\n`);
    
    // Step 4: Insert categories (chunked)
    if (allCategories.size > 0) {
      console.log('Step 4: Inserting categories...');
      const categoriesArray = Array.from(allCategories);
      
      for (let i = 0; i < categoriesArray.length; i += 1000) {
        const chunk = categoriesArray.slice(i, i + 1000);
        const catValues = [];
        const catParams = [];
        let idx = 1;
        
        for (const [name, data] of chunk) {
          catValues.push(`($${idx}, $${idx+1}, $${idx+2})`);
          catParams.push(name, data.level, `{${data.path.join(',')}}`);
          idx += 3;
        }
        
        await pool.query(
          `INSERT INTO categories (name, level, path) VALUES ${catValues.join(', ')} ON CONFLICT (name) DO NOTHING`,
          catParams
        );
        
        if ((i + 1000) % 10000 === 0) {
          console.log(`  Inserted ${Math.min(i + 1000, categoriesArray.length)}/${categoriesArray.length}...`);
        }
      }
      
      // Reload cache with IDs
      const allCats = await pool.query('SELECT id, name FROM categories');
      categoryCache.clear();
      allCats.rows.forEach(row => categoryCache.set(row.name, row.id));
      
      // Update parent_id relationships in batch using CASE statement
      const updateCases = [];
      const updateIds = [];
      
      for (const [name, data] of categoriesArray) {
        if (data.parent) {
          const parentId = categoryCache.get(data.parent);
          const childId = categoryCache.get(name);
          if (parentId && childId) {
            updateCases.push(`WHEN ${childId} THEN ${parentId}`);
            updateIds.push(childId);
          }
        }
      }
      
      if (updateIds.length > 0) {
        await pool.query(`
          UPDATE categories 
          SET parent_id = CASE id 
            ${updateCases.join(' ')}
          END
          WHERE id IN (${updateIds.join(',')})
        `);
      }
      
      console.log(`Inserted ${categoriesArray.length} categories\n`);
    } else {
      console.log('Step 4: No new categories to insert\n');
    }
    
    // Step 5: Insert ingredients (chunked)
    if (allIngredients.size > 0) {
      console.log('Step 5: Inserting ingredients...');
      const ingredientsArray = Array.from(allIngredients);
      
      for (let i = 0; i < ingredientsArray.length; i += 1000) {
        const chunk = ingredientsArray.slice(i, i + 1000);
        const ingValues = [];
        const ingParams = [];
        let idx = 1;
        
        for (const tag of chunk) {
          const normalized = normalizeIngredient(tag);
          const known = KNOWN_INGREDIENTS[tag] || {};
          
          ingValues.push(`($${idx}, $${idx+1}, $${idx+2}, $${idx+3}, $${idx+4}, $${idx+5}, $${idx+6})`);
          ingParams.push(
            tag,
            normalized,
            known.vegan || 0,
            known.not_vegan || 0,
            known.vegetarian || 0,
            known.not_vegetarian || 0,
            '{}'
          );
          idx += 7;
        }
        
        await pool.query(
          `INSERT INTO ingredients (name, normalized_name, vegan_confidence, not_vegan_confidence, vegetarian_confidence, not_vegetarian_confidence, allergen_tags) 
           VALUES ${ingValues.join(', ')} ON CONFLICT (name) DO NOTHING`,
          ingParams
        );
        
        if ((i + 1000) % 10000 === 0) {
          console.log(`  Inserted ${Math.min(i + 1000, ingredientsArray.length)}/${ingredientsArray.length}...`);
        }
      }
      
      // Reload cache
      const allIngs = await pool.query('SELECT id, name FROM ingredients');
      ingredientCache.clear();
      allIngs.rows.forEach(row => ingredientCache.set(row.name, row.id));
      
      console.log(`Inserted ${ingredientsArray.length} ingredients\n`);
    } else {
      console.log('Step 5: No new ingredients to insert\n');
    }
    
    // Step 6: Insert products (chunked)
    console.log('Step 6: Inserting products...');
    
    for (let i = 0; i < products.length; i += 1000) {
      const chunk = products.slice(i, i + 1000);
      const prodValues = [];
      const prodParams = [];
      let idx = 1;
      
      for (const p of chunk) {
        prodValues.push(`($${idx}, $${idx+1}, $${idx+2}, $${idx+3}, $${idx+4}, $${idx+5}, $${idx+6}, $${idx+7})`);
        prodParams.push(p.barcode, p.name, p.brand, p.imageUrl, p.is_vegan, p.is_vegetarian, p.is_gluten_free, p.is_dairy_free);
        idx += 8;
      }
      
      await pool.query(
        `INSERT INTO products (barcode, name, brand, image_url, is_vegan, is_vegetarian, is_gluten_free, is_dairy_free) 
         VALUES ${prodValues.join(', ')} ON CONFLICT (barcode) DO NOTHING`,
        prodParams
      );
      
      if ((i + 1000) % 10000 === 0) {
        console.log(`  Inserted ${Math.min(i + 1000, products.length)}/${products.length}...`);
      }
    }
    
    console.log(`Inserted ${products.length} products\n`);
    
    // Step 7: Insert product-category links (chunked)
    console.log('Step 7: Inserting product-category links...');
    const validCatLinks = productCategoryLinks.filter(link => 
      categoryCache.has(link.category)
    );
    
    for (let i = 0; i < validCatLinks.length; i += 1000) {
      const chunk = validCatLinks.slice(i, i + 1000);
      const values = [];
      const params = [];
      let idx = 1;
      
      for (const link of chunk) {
        const catId = categoryCache.get(link.category);
        values.push(`($${idx}, $${idx+1})`);
        params.push(link.barcode, catId);
        idx += 2;
      }
      
      await pool.query(
        `INSERT INTO product_categories (product_barcode, category_id) VALUES ${values.join(', ')} ON CONFLICT DO NOTHING`,
        params
      );
      
      if ((i + 1000) % 10000 === 0) {
        console.log(`  Inserted ${Math.min(i + 1000, validCatLinks.length)}/${validCatLinks.length}...`);
      }
    }
    
    console.log(`Inserted ${validCatLinks.length} product-category links\n`);
    
    // Step 8: Insert product-ingredient links (chunked)
    console.log('Step 8: Inserting product-ingredient links...');
    const validIngLinks = productIngredientLinks.filter(link => 
      ingredientCache.has(link.ingredient)
    );
    
    for (let i = 0; i < validIngLinks.length; i += 1000) {
      const chunk = validIngLinks.slice(i, i + 1000);
      const values = [];
      const params = [];
      let idx = 1;
      
      for (const link of chunk) {
        const ingId = ingredientCache.get(link.ingredient);
        values.push(`($${idx}, $${idx+1})`);
        params.push(link.barcode, ingId);
        idx += 2;
      }
      
      await pool.query(
        `INSERT INTO product_ingredients (product_barcode, ingredient_id) VALUES ${values.join(', ')} ON CONFLICT DO NOTHING`,
        params
      );
      
      if ((i + 1000) % 10000 === 0) {
        console.log(`  Inserted ${Math.min(i + 1000, validIngLinks.length)}/${validIngLinks.length}...`);
      }
    }
    
    console.log(`Inserted ${validIngLinks.length} product-ingredient links\n`);
    
    // Final stats
    const duration = ((Date.now() - startTime) / 1000 / 60).toFixed(2);
    console.log('=== Migration Complete ===');
    console.log(`Time taken: ${duration} minutes`);
    
    const stats = await pool.query(`
      SELECT 
        (SELECT COUNT(*) FROM products) as products,
        (SELECT COUNT(*) FROM categories) as categories,
        (SELECT COUNT(*) FROM ingredients) as ingredients,
        (SELECT COUNT(*) FROM product_categories) as prod_cats,
        (SELECT COUNT(*) FROM product_ingredients) as prod_ings
    `);
    
    console.log('\nDatabase totals:');
    console.log(`  Products: ${stats.rows[0].products}`);
    console.log(`  Categories: ${stats.rows[0].categories}`);
    console.log(`  Ingredients: ${stats.rows[0].ingredients}`);
    console.log(`  Product-Category links: ${stats.rows[0].prod_cats}`);
    console.log(`  Product-Ingredient links: ${stats.rows[0].prod_ings}`);
    
  } catch (err) {
    console.error('\nError:', err.message);
    console.error(err.stack);
  } finally {
    await pool.end();
  }
}

migrate100k();
