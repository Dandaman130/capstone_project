const { Pool } = require('pg');

const DATABASE_URL = process.env.DATABASE_URL || 'postgresql://postgres:cFGvTOMRZauZulyRoryYpJILFUszgorI@switchyard.proxy.rlwy.net:29111/railway';

const pool = new Pool({
  connectionString: DATABASE_URL,
});

async function checkDirectly() {
  try {
    console.log('Querying database directly...\n');
    
    // Check non-zero confidence values
    const result = await pool.query(`
      SELECT 
        name, 
        normalized_name,
        vegan_confidence,
        not_vegan_confidence,
        vegetarian_confidence,
        not_vegetarian_confidence,
        gluten_free_confidence,
        contains_gluten_confidence
      FROM ingredients
      WHERE vegan_confidence > 0 
         OR not_vegan_confidence > 0
         OR vegetarian_confidence > 0
         OR not_vegetarian_confidence > 0
         OR gluten_free_confidence > 0
         OR contains_gluten_confidence > 0
      ORDER BY GREATEST(vegan_confidence, not_vegan_confidence, vegetarian_confidence, not_vegetarian_confidence) DESC
      LIMIT 20
    `);
    
    console.log(`Found ${result.rows.length} ingredients with non-zero confidence:\n`);
    
    result.rows.forEach(row => {
      console.log(`${row.normalized_name}:`);
      if (row.vegan_confidence > 0) console.log(`  Vegan: ${row.vegan_confidence}%`);
      if (row.not_vegan_confidence > 0) console.log(`  Not Vegan: ${row.not_vegan_confidence}%`);
      if (row.vegetarian_confidence > 0) console.log(`  Vegetarian: ${row.vegetarian_confidence}%`);
      if (row.not_vegetarian_confidence > 0) console.log(`  Not Vegetarian: ${row.not_vegetarian_confidence}%`);
      if (row.gluten_free_confidence > 0) console.log(`  Gluten Free: ${row.gluten_free_confidence}%`);
      if (row.contains_gluten_confidence > 0) console.log(`  Contains Gluten: ${row.contains_gluten_confidence}%`);
    });
    
    // Count totals
    const stats = await pool.query(`
      SELECT 
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE vegan_confidence > 0) as vegan_pos,
        COUNT(*) FILTER (WHERE not_vegan_confidence > 0) as vegan_neg,
        COUNT(*) FILTER (WHERE vegetarian_confidence > 0) as veg_pos,
        COUNT(*) FILTER (WHERE not_vegetarian_confidence > 0) as veg_neg
      FROM ingredients
    `);
    
    console.log(`\nTotal stats:`);
    console.log(`  Total ingredients: ${stats.rows[0].total}`);
    console.log(`  With vegan_confidence: ${stats.rows[0].vegan_pos}`);
    console.log(`  With not_vegan_confidence: ${stats.rows[0].vegan_neg}`);
    console.log(`  With vegetarian_confidence: ${stats.rows[0].veg_pos}`);
    console.log(`  With not_vegetarian_confidence: ${stats.rows[0].veg_neg}`);
    
  } catch (err) {
    console.error('Error:', err.message);
  } finally {
    await pool.end();
  }
}

checkDirectly();
