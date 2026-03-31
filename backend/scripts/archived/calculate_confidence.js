const { Pool } = require('pg');

const DATABASE_URL = process.env.DATABASE_URL || 'postgresql://postgres:cFGvTOMRZauZulyRoryYpJILFUszgorI@switchyard.proxy.rlwy.net:29111/railway';

const pool = new Pool({
  connectionString: DATABASE_URL,
});

// Known static ingredients that don't get updated
const STATIC_INGREDIENTS = new Set([
  'en:water', 'en:sugar', 'en:salt', 'en:carbon-dioxide', 'en:carbonated-water',
  'en:fructose', 'en:glucose', 'en:rice', 'en:corn', 'en:soy',
  'en:milk', 'en:cream', 'en:butter', 'en:cheese', 'en:whey',
  'en:egg', 'en:honey', 'en:gelatin', 'en:gelatine',
  'en:wheat', 'en:barley', 'en:rye', 'en:wheat-flour'
]);

const INITIAL_CONFIDENCE = 20;
const CONFIDENCE_INCREMENT = 5;
const PASS2_THRESHOLD = 70; // For classifying unknown products

async function calculateConfidence() {
  console.log('Starting confidence calculation...\n');
  
  try {
    // 1. Add confidence columns to ingredients table
    console.log('Adding confidence columns to ingredients table...');
    await pool.query(`
      ALTER TABLE ingredients 
      ADD COLUMN IF NOT EXISTS vegan_confidence INTEGER DEFAULT 0,
      ADD COLUMN IF NOT EXISTS not_vegan_confidence INTEGER DEFAULT 0,
      ADD COLUMN IF NOT EXISTS vegetarian_confidence INTEGER DEFAULT 0,
      ADD COLUMN IF NOT EXISTS not_vegetarian_confidence INTEGER DEFAULT 0,
      ADD COLUMN IF NOT EXISTS gluten_free_confidence INTEGER DEFAULT 0,
      ADD COLUMN IF NOT EXISTS contains_gluten_confidence INTEGER DEFAULT 0
    `);
    console.log('✓ Columns added\n');
    
    // 2. PASS 1: Process products with known dietary tags
    console.log('=== PASS 1: Processing Known Products ===\n');
    
    const dietTypes = [
      { column: 'is_vegan', positive: 'vegan_confidence', negative: 'not_vegan_confidence', name: 'vegan' },
      { column: 'is_vegetarian', positive: 'vegetarian_confidence', negative: 'not_vegetarian_confidence', name: 'vegetarian' },
      { column: 'is_gluten_free', positive: 'gluten_free_confidence', negative: 'contains_gluten_confidence', name: 'gluten_free' }
    ];
    
    for (const diet of dietTypes) {
      console.log(`Processing ${diet.name}...`);
      
      // Get products with positive tag (e.g., is_vegan = 1)
      const positiveProducts = await pool.query(`
        SELECT p.barcode, i.id as ingredient_id, i.name as ingredient_name
        FROM products p
        JOIN product_ingredients pi ON p.barcode = pi.product_barcode
        JOIN ingredients i ON pi.ingredient_id = i.id
        WHERE p.${diet.column} = 1
      `);
      
      // Count occurrences per ingredient
      const ingredientCounts = new Map();
      for (const row of positiveProducts.rows) {
        if (!STATIC_INGREDIENTS.has(row.ingredient_name)) {
          const count = ingredientCounts.get(row.ingredient_id) || 0;
          ingredientCounts.set(row.ingredient_id, count + 1);
        }
      }
      
      // Update confidence scores
      for (const [ingredientId, count] of ingredientCounts) {
        const confidence = INITIAL_CONFIDENCE + (count - 1) * CONFIDENCE_INCREMENT;
        await pool.query(`
          UPDATE ingredients 
          SET ${diet.positive} = $1 
          WHERE id = $2
        `, [confidence, ingredientId]);
      }
      
      console.log(`  ✓ Positive: Updated ${ingredientCounts.size} ingredients`);
      
      // Get products with negative tag (e.g., is_vegan = 0)
      console.log(`  Fetching negative products...`);
      const negativeProducts = await pool.query(`
        SELECT p.barcode, i.id as ingredient_id, i.name as ingredient_name
        FROM products p
        JOIN product_ingredients pi ON p.barcode = pi.product_barcode
        JOIN ingredients i ON pi.ingredient_id = i.id
        WHERE p.${diet.column} = 0
      `);
      console.log(`  Found ${negativeProducts.rows.length} ingredient-product pairs`);
      
      // Count occurrences per ingredient
      const negativeIngredientCounts = new Map();
      for (const row of negativeProducts.rows) {
        if (!STATIC_INGREDIENTS.has(row.ingredient_name)) {
          const count = negativeIngredientCounts.get(row.ingredient_id) || 0;
          negativeIngredientCounts.set(row.ingredient_id, count + 1);
        }
      }
      
      // Update confidence scores
      for (const [ingredientId, count] of negativeIngredientCounts) {
        const confidence = INITIAL_CONFIDENCE + (count - 1) * CONFIDENCE_INCREMENT;
        await pool.query(`
          UPDATE ingredients 
          SET ${diet.negative} = $1 
          WHERE id = $2
        `, [confidence, ingredientId]);
      }
      
      console.log(`  ✓ Negative: Updated ${negativeIngredientCounts.size} ingredients\n`);
    }
    
    // 3. PASS 2: Process unknown products
    console.log('=== PASS 2: Classifying Unknown Products ===\n');
    
    for (const diet of dietTypes) {
      console.log(`Processing unknown ${diet.name} products...`);
      
      // Get products with unknown tag (e.g., is_vegan = -1)
      const unknownProducts = await pool.query(`
        SELECT p.barcode
        FROM products p
        WHERE p.${diet.column} = -1
      `);
      
      let reclassified = 0;
      
      for (const product of unknownProducts.rows) {
        // Get all ingredients for this product
        const ingredients = await pool.query(`
          SELECT i.${diet.positive} as positive_conf, i.${diet.negative} as negative_conf
          FROM product_ingredients pi
          JOIN ingredients i ON pi.ingredient_id = i.id
          WHERE pi.product_barcode = $1
        `, [product.barcode]);
        
        if (ingredients.rows.length === 0) continue;
        
        // Calculate average confidence
        let avgPositive = 0;
        let avgNegative = 0;
        let count = 0;
        
        for (const ing of ingredients.rows) {
          avgPositive += ing.positive_conf || 0;
          avgNegative += ing.negative_conf || 0;
          count++;
        }
        
        avgPositive = avgPositive / count;
        avgNegative = avgNegative / count;
        
        // Classify based on threshold
        if (avgPositive >= PASS2_THRESHOLD && avgPositive > avgNegative) {
          await pool.query(`UPDATE products SET ${diet.column} = 1 WHERE barcode = $1`, [product.barcode]);
          reclassified++;
          
          // Update ingredient confidences with this new product
          const productIngredients = await pool.query(`
            SELECT i.id, i.name
            FROM product_ingredients pi
            JOIN ingredients i ON pi.ingredient_id = i.id
            WHERE pi.product_barcode = $1
          `, [product.barcode]);
          
          for (const ing of productIngredients.rows) {
            if (!STATIC_INGREDIENTS.has(ing.name)) {
              await pool.query(`
                UPDATE ingredients 
                SET ${diet.positive} = ${diet.positive} + $1 
                WHERE id = $2
              `, [CONFIDENCE_INCREMENT, ing.id]);
            }
          }
        } else if (avgNegative >= PASS2_THRESHOLD && avgNegative > avgPositive) {
          await pool.query(`UPDATE products SET ${diet.column} = 0 WHERE barcode = $1`, [product.barcode]);
          reclassified++;
          
          // Update ingredient confidences with this new product
          const productIngredients = await pool.query(`
            SELECT i.id, i.name
            FROM product_ingredients pi
            JOIN ingredients i ON pi.ingredient_id = i.id
            WHERE pi.product_barcode = $1
          `, [product.barcode]);
          
          for (const ing of productIngredients.rows) {
            if (!STATIC_INGREDIENTS.has(ing.name)) {
              await pool.query(`
                UPDATE ingredients 
                SET ${diet.negative} = ${diet.negative} + $1 
                WHERE id = $2
              `, [CONFIDENCE_INCREMENT, ing.id]);
            }
          }
        }
      }
      
      console.log(`  ✓ Reclassified ${reclassified} products\n`);
    }
    
    // 4. Print summary statistics
    console.log('=== Summary ===\n');
    
    const stats = await pool.query(`
      SELECT 
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE vegan_confidence > 0) as has_vegan_conf,
        COUNT(*) FILTER (WHERE vegetarian_confidence > 0) as has_veg_conf,
        COUNT(*) FILTER (WHERE gluten_free_confidence > 0) as has_gf_conf,
        AVG(vegan_confidence) FILTER (WHERE vegan_confidence > 0) as avg_vegan_conf,
        AVG(vegetarian_confidence) FILTER (WHERE vegetarian_confidence > 0) as avg_veg_conf,
        AVG(gluten_free_confidence) FILTER (WHERE gluten_free_confidence > 0) as avg_gf_conf
      FROM ingredients
    `);
    
    console.log('Ingredients:');
    console.log(`  Total: ${stats.rows[0].total}`);
    console.log(`  With vegan confidence: ${stats.rows[0].has_vegan_conf} (avg: ${Math.round(stats.rows[0].avg_vegan_conf || 0)}%)`);
    console.log(`  With vegetarian confidence: ${stats.rows[0].has_veg_conf} (avg: ${Math.round(stats.rows[0].avg_veg_conf || 0)}%)`);
    console.log(`  With gluten-free confidence: ${stats.rows[0].has_gf_conf} (avg: ${Math.round(stats.rows[0].avg_gf_conf || 0)}%)`);
    
    const productStats = await pool.query(`
      SELECT 
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE is_vegan = 1) as vegan,
        COUNT(*) FILTER (WHERE is_vegan = 0) as not_vegan,
        COUNT(*) FILTER (WHERE is_vegan = -1) as unknown_vegan,
        COUNT(*) FILTER (WHERE is_vegetarian = 1) as vegetarian,
        COUNT(*) FILTER (WHERE is_gluten_free = 1) as gluten_free
      FROM products
    `);
    
    console.log('\nProducts:');
    console.log(`  Total: ${productStats.rows[0].total}`);
    console.log(`  Vegan: ${productStats.rows[0].vegan}`);
    console.log(`  Not vegan: ${productStats.rows[0].not_vegan}`);
    console.log(`  Unknown vegan: ${productStats.rows[0].unknown_vegan}`);
    console.log(`  Vegetarian: ${productStats.rows[0].vegetarian}`);
    console.log(`  Gluten-free: ${productStats.rows[0].gluten_free}`);
    
    // Show top confident ingredients
    console.log('\nTop Confident Vegan Ingredients:');
    const topVegan = await pool.query(`
      SELECT name, normalized_name, vegan_confidence
      FROM ingredients
      WHERE vegan_confidence > 0
      ORDER BY vegan_confidence DESC
      LIMIT 10
    `);
    topVegan.rows.forEach(i => {
      console.log(`  ${i.normalized_name}: ${i.vegan_confidence}%`);
    });
    
    console.log('\n✓ Confidence calculation completed!');
    
  } catch (err) {
    console.error('Error:', err);
    throw err;
  } finally {
    await pool.end();
  }
}

calculateConfidence().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
