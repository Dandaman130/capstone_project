const { Pool } = require('pg');

const DATABASE_URL = process.env.DATABASE_URL || 'postgresql://postgres:cFGvTOMRZauZulyRoryYpJILFUszgorI@switchyard.proxy.rlwy.net:29111/railway';

const pool = new Pool({
  connectionString: DATABASE_URL,
  connectionTimeoutMillis: 30000,
  query_timeout: 60000,
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

async function calculateConfidenceSimple() {
  console.log('Starting simplified confidence calculation...\n');
  
  try {
    // 1. Add confidence columns if not exist
    console.log('Ensuring confidence columns exist...');
    await pool.query(`
      ALTER TABLE ingredients 
      ADD COLUMN IF NOT EXISTS vegan_confidence INTEGER DEFAULT 0,
      ADD COLUMN IF NOT EXISTS not_vegan_confidence INTEGER DEFAULT 0,
      ADD COLUMN IF NOT EXISTS vegetarian_confidence INTEGER DEFAULT 0,
      ADD COLUMN IF NOT EXISTS not_vegetarian_confidence INTEGER DEFAULT 0,
      ADD COLUMN IF NOT EXISTS gluten_free_confidence INTEGER DEFAULT 0,
      ADD COLUMN IF NOT EXISTS contains_gluten_confidence INTEGER DEFAULT 0
    `);
    console.log('✓ Columns ready\n');
    
    // 2. Process each diet type
    const dietTypes = [
      { column: 'is_vegan', positive: 'vegan_confidence', negative: 'not_vegan_confidence', name: 'vegan' },
      { column: 'is_vegetarian', positive: 'vegetarian_confidence', negative: 'not_vegetarian_confidence', name: 'vegetarian' },
      { column: 'is_gluten_free', positive: 'gluten_free_confidence', negative: 'contains_gluten_confidence', name: 'gluten_free' }
    ];
    
    for (const diet of dietTypes) {
      console.log(`\n=== Processing ${diet.name} ===`);
      
      // POSITIVE (e.g., is_vegan = 1)
      console.log('Counting positive occurrences...');
      const positiveQuery = `
        SELECT i.id, i.name, COUNT(*) as product_count
        FROM ingredients i
        JOIN product_ingredients pi ON i.id = pi.ingredient_id
        JOIN products p ON pi.product_barcode = p.barcode
        WHERE p.${diet.column} = 1
        GROUP BY i.id, i.name
      `;
      
      const positiveResult = await pool.query(positiveQuery);
      console.log(`  Found ${positiveResult.rows.length} ingredients in positive products`);
      
      // Batch update using CASE statement
      const updateCases = [];
      const updateIds = [];
      for (const row of positiveResult.rows) {
        if (!STATIC_INGREDIENTS.has(row.name)) {
          const confidence = INITIAL_CONFIDENCE + (row.product_count - 1) * CONFIDENCE_INCREMENT;
          updateCases.push(`WHEN ${row.id} THEN ${confidence}`);
          updateIds.push(row.id);
        }
      }
      
      if (updateIds.length > 0) {
        await pool.query(`
          UPDATE ingredients 
          SET ${diet.positive} = CASE id 
            ${updateCases.join(' ')}
          END
          WHERE id IN (${updateIds.join(',')})
        `);
      }
      console.log(`  ✓ Updated ${updateIds.length} ingredients with positive confidence`);
      
      // NEGATIVE (e.g., is_vegan = 0)
      console.log('Counting negative occurrences...');
      const negativeQuery = `
        SELECT i.id, i.name, COUNT(*) as product_count
        FROM ingredients i
        JOIN product_ingredients pi ON i.id = pi.ingredient_id
        JOIN products p ON pi.product_barcode = p.barcode
        WHERE p.${diet.column} = 0
        GROUP BY i.id, i.name
      `;
      
      const negativeResult = await pool.query(negativeQuery);
      console.log(`  Found ${negativeResult.rows.length} ingredients in negative products`);
      
      // Batch update using CASE statement
      const negUpdateCases = [];
      const negUpdateIds = [];
      for (const row of negativeResult.rows) {
        if (!STATIC_INGREDIENTS.has(row.name)) {
          const confidence = INITIAL_CONFIDENCE + (row.product_count - 1) * CONFIDENCE_INCREMENT;
          negUpdateCases.push(`WHEN ${row.id} THEN ${confidence}`);
          negUpdateIds.push(row.id);
        }
      }
      
      if (negUpdateIds.length > 0) {
        await pool.query(`
          UPDATE ingredients 
          SET ${diet.negative} = CASE id 
            ${negUpdateCases.join(' ')}
          END
          WHERE id IN (${negUpdateIds.join(',')})
        `);
      }
      console.log(`  ✓ Updated ${negUpdateIds.length} ingredients with negative confidence`);
    }
    
    // 3. Show summary
    console.log('\n=== Summary ===\n');
    
    const stats = await pool.query(`
      SELECT 
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE vegan_confidence > 0) as has_vegan_conf,
        COUNT(*) FILTER (WHERE not_vegan_confidence > 0) as has_not_vegan_conf,
        COUNT(*) FILTER (WHERE vegetarian_confidence > 0) as has_veg_conf,
        COUNT(*) FILTER (WHERE not_vegetarian_confidence > 0) as has_not_veg_conf,
        COUNT(*) FILTER (WHERE gluten_free_confidence > 0) as has_gf_conf,
        COUNT(*) FILTER (WHERE contains_gluten_confidence > 0) as has_contains_gluten_conf
      FROM ingredients
    `);
    
    const s = stats.rows[0];
    console.log('Ingredients with confidence:');
    console.log(`  Vegan: ${s.has_vegan_conf} positive, ${s.has_not_vegan_conf} negative`);
    console.log(`  Vegetarian: ${s.has_veg_conf} positive, ${s.has_not_veg_conf} negative`);
    console.log(`  Gluten-free: ${s.has_gf_conf} positive, ${s.has_contains_gluten_conf} negative`);
    
    console.log('\nTop vegan confidence scores:');
    const topVegan = await pool.query(`
      SELECT name, normalized_name, vegan_confidence, not_vegan_confidence
      FROM ingredients
      WHERE vegan_confidence > 0 OR not_vegan_confidence > 0
      ORDER BY GREATEST(vegan_confidence, not_vegan_confidence) DESC
      LIMIT 10
    `);
    topVegan.rows.forEach(i => {
      const scores = [];
      if (i.vegan_confidence > 0) scores.push(`vegan: ${i.vegan_confidence}%`);
      if (i.not_vegan_confidence > 0) scores.push(`not vegan: ${i.not_vegan_confidence}%`);
      console.log(`  ${i.normalized_name}: ${scores.join(', ')}`);
    });
    
    console.log('\n✓ Confidence calculation completed!');
    
  } catch (err) {
    console.error('\n❌ Error:', err.message);
    console.error(err.stack);
  } finally {
    await pool.end();
  }
}

calculateConfidenceSimple();
