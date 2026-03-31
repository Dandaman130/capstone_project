const fs = require('fs');
const readline = require('readline');

async function checkIngredientsFormat() {
  console.log('Checking ingredients_text format...\n');
  
  const fileStream = fs.createReadStream('./openfoodfacts-products.jsonl');
  const rl = readline.createInterface({ input: fileStream, crlfDelay: Infinity });
  
  const samples = [];
  let lineCount = 0;
  let hasIngredientsText = 0;
  let hasIngredientsTags = 0;
  let hasBoth = 0;
  
  for await (const line of rl) {
    try {
      const product = JSON.parse(line);
      
      const hasText = product.ingredients_text && product.ingredients_text.trim().length > 0;
      const hasTags = product.ingredients_tags && Array.isArray(product.ingredients_tags) && product.ingredients_tags.length > 0;
      
      if (hasText) hasIngredientsText++;
      if (hasTags) hasIngredientsTags++;
      if (hasText && hasTags) hasBoth++;
      
      // Collect samples
      if (samples.length < 20 && hasText) {
        samples.push({
          name: product.product_name,
          text: product.ingredients_text,
          tags: hasTags ? product.ingredients_tags.slice(0, 5) : null,
          language: product.lang
        });
      }
      
      lineCount++;
      if (lineCount >= 10000) break; // Check first 10k products
      
    } catch (err) {}
  }
  
  console.log(`Checked ${lineCount} products:\n`);
  console.log(`  Has ingredients_text: ${hasIngredientsText} (${(hasIngredientsText/lineCount*100).toFixed(1)}%)`);
  console.log(`  Has ingredients_tags: ${hasIngredientsTags} (${(hasIngredientsTags/lineCount*100).toFixed(1)}%)`);
  console.log(`  Has BOTH: ${hasBoth} (${(hasBoth/lineCount*100).toFixed(1)}%)`);
  
  console.log('\n\nSample ingredients_text formats:\n');
  samples.forEach((s, i) => {
    console.log(`${i+1}. ${s.name} (${s.language})`);
    console.log(`   Text: ${s.text.substring(0, 150)}${s.text.length > 150 ? '...' : ''}`);
    if (s.tags) {
      console.log(`   Tags: ${s.tags.join(', ')}`);
    }
    console.log('');
  });
  
  fileStream.destroy();
}

checkIngredientsFormat();
