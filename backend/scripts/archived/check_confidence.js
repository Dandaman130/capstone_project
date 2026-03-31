const { Pool } = require('pg');

const DATABASE_URL = process.env.DATABASE_URL || 'postgresql://postgres:cFGvTOMRZauZulyRoryYpJILFUszgorI@switchyard.proxy.rlwy.net:29111/railway';

const pool = new Pool({
  connectionString: DATABASE_URL,
});

async function checkConfidence() {
  try {
    console.log('Checking confidence calculation status...\n');
    
    // Check if columns exist
    const columns = await pool.query(`
      SELECT column_name 
      FROM information_schema.columns 
      WHERE table_name = 'ingredients' 
      AND column_name LIKE '%confidence%'
      ORDER BY column_name
    `);
    
    console.log('Confidence columns:');
    columns.rows.forEach(col => console.log(`  - ${col.column_name}`));
    
    // Check sample data
    const sample = await pool.query(`
      SELECT name, normalized_name, 
             vegan_confidence, not_vegan_confidence,
             vegetarian_confidence, not_vegetarian_confidence,
             gluten_free_confidence, contains_gluten_confidence
      FROM ingredients 
      WHERE vegan_confidence > 0 OR vegetarian_confidence > 0 OR gluten_free_confidence > 0
      LIMIT 10
    `);
    
    console.log(`\nIngredients with confidence (${sample.rows.length} found):`);
    sample.rows.forEach(i => {
      console.log(`  ${i.normalized_name}:`);
      if (i.vegan_confidence > 0) console.log(`    Vegan: ${i.vegan_confidence}%`);
      if (i.not_vegan_confidence > 0) console.log(`    Not vegan: ${i.not_vegan_confidence}%`);
      if (i.vegetarian_confidence > 0) console.log(`    Vegetarian: ${i.vegetarian_confidence}%`);
      if (i.gluten_free_confidence > 0) console.log(`    Gluten-free: ${i.gluten_free_confidence}%`);
    });
    
    // Check stats
    const stats = await pool.query(`
      SELECT 
        COUNT(*) FILTER (WHERE vegan_confidence > 0) as has_vegan,
        COUNT(*) FILTER (WHERE vegetarian_confidence > 0) as has_veg,
        COUNT(*) FILTER (WHERE gluten_free_confidence > 0) as has_gf
      FROM ingredients
    `);
    
    console.log(`\nStats:`);
    console.log(`  Ingredients with vegan confidence: ${stats.rows[0].has_vegan}`);
    console.log(`  Ingredients with vegetarian confidence: ${stats.rows[0].has_veg}`);
    console.log(`  Ingredients with gluten-free confidence: ${stats.rows[0].has_gf}`);
    
  } catch (err) {
    console.error('Error:', err.message);
  } finally {
    await pool.end();
  }
}

checkConfidence();
