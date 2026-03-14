const fs = require('fs');
const readline = require('readline');

async function analyzeCoverage() {
  console.log('Analyzing product tag coverage...\n');
  
  const fileStream = fs.createReadStream('./openfoodfacts-products.jsonl');
  const rl = readline.createInterface({ input: fileStream, crlfDelay: Infinity });
  
  let total = 0;
  let hasVeganTag = 0;
  let hasVegetarianTag = 0;
  let hasGlutenFreeTag = 0;
  let hasIngredientTags = 0;
  let hasBothVeganAndIngredients = 0;
  let hasVeganButNoIngredients = 0;
  
  for await (const line of rl) {
    try {
      const product = JSON.parse(line);
      
      const vegan = product.labels_tags && (
        product.labels_tags.includes('en:vegan') || 
        product.labels_tags.includes('en:non-vegan')
      );
      const vegetarian = product.labels_tags && (
        product.labels_tags.includes('en:vegetarian') || 
        product.labels_tags.includes('en:non-vegetarian')
      );
      const glutenFree = product.labels_tags && (
        product.labels_tags.includes('en:gluten-free') || 
        product.labels_tags.includes('en:no-gluten')
      );
      const ingredients = product.ingredients_tags && 
        Array.isArray(product.ingredients_tags) && 
        product.ingredients_tags.length > 0;
      
      if (vegan) hasVeganTag++;
      if (vegetarian) hasVegetarianTag++;
      if (glutenFree) hasGlutenFreeTag++;
      if (ingredients) hasIngredientTags++;
      if (vegan && ingredients) hasBothVeganAndIngredients++;
      if (vegan && !ingredients) hasVeganButNoIngredients++;
      
      total++;
      if (total >= 100000) break; // Check first 100k
      
      if (total % 10000 === 0) {
        console.log(`  Processed ${total}...`);
      }
      
    } catch (err) {}
  }
  
  console.log(`\n=== Analysis of ${total} products ===\n`);
  
  console.log('Dietary Tags:');
  console.log(`  Vegan tag: ${hasVeganTag} (${(hasVeganTag/total*100).toFixed(2)}%)`);
  console.log(`  Vegetarian tag: ${hasVegetarianTag} (${(hasVegetarianTag/total*100).toFixed(2)}%)`);
  console.log(`  Gluten-free tag: ${hasGlutenFreeTag} (${(hasGlutenFreeTag/total*100).toFixed(2)}%)`);
  
  console.log('\nIngredients:');
  console.log(`  Has ingredient_tags: ${hasIngredientTags} (${(hasIngredientTags/total*100).toFixed(2)}%)`);
  
  console.log('\nOverlap:');
  console.log(`  Vegan tag AND ingredients: ${hasBothVeganAndIngredients} (${(hasBothVeganAndIngredients/total*100).toFixed(2)}%)`);
  console.log(`  Vegan tag but NO ingredients: ${hasVeganButNoIngredients} (${(hasVeganButNoIngredients/total*100).toFixed(2)}%)`);
  
  console.log('\n=== Usefulness Assessment ===');
  const confidenceUseful = hasVeganButNoIngredients;
  const confidenceTotal = hasVeganTag;
  console.log(`\nFor products WITH vegan tags (${hasVeganTag}):`);
  console.log(`  Have ingredients (confidence not needed): ${hasBothVeganAndIngredients} (${(hasBothVeganAndIngredients/hasVeganTag*100).toFixed(1)}%)`);
  console.log(`  Missing ingredients (confidence needed): ${hasVeganButNoIngredients} (${(hasVeganButNoIngredients/hasVeganTag*100).toFixed(1)}%)`);
  
  const noTagsAtAll = total - hasVeganTag - hasVegetarianTag;
  console.log(`\nProducts with NO dietary tags at all:`);
  console.log(`  ~${noTagsAtAll} products (${(noTagsAtAll/total*100).toFixed(1)}%) - confidence system WOULD be useful here`);
  
  fileStream.destroy();
}

analyzeCoverage();
