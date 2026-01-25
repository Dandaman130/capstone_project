const { Client } = require('pg');

const DATABASE_URL = "postgresql://postgres:cFGvTOMRZauZulyRoryYpJILFUszgorI@switchyard.proxy.rlwy.net:29111/railway";

async function testQueries() {
  const client = new Client({
    connectionString: DATABASE_URL,
  });

  try {
    await client.connect();
    console.log('✓ Connected to database\n');

    // Test 1: Get products with categories joined
    console.log('=== TEST 1: Get products with categories ===');
    const test1 = await client.query(`
      SELECT
        p.barcode,
        p.name,
        p.brand,
        p.image_url,
        p.is_vegan,
        p.is_vegetarian,
        p.is_gluten_free,
        p.is_dairy_free,
        STRING_AGG(DISTINCT c.name, ',') as categories
      FROM products p
      LEFT JOIN product_categories pc ON p.barcode = pc.product_barcode
      LEFT JOIN categories c ON pc.category_id = c.id
      GROUP BY p.barcode, p.name, p.brand, p.image_url, p.is_vegan, p.is_vegetarian, p.is_gluten_free, p.is_dairy_free
      LIMIT 3
    `);
    console.log('Results:', test1.rows.length);
    console.log(JSON.stringify(test1.rows, null, 2));

    // Test 2: Search by name
    console.log('\n=== TEST 2: Search by name (tea) ===');
    const test2 = await client.query(`
      SELECT
        p.barcode,
        p.name,
        p.brand,
        p.image_url,
        STRING_AGG(DISTINCT c.name, ',') as categories
      FROM products p
      LEFT JOIN product_categories pc ON p.barcode = pc.product_barcode
      LEFT JOIN categories c ON pc.category_id = c.id
      WHERE p.name ILIKE $1
      GROUP BY p.barcode, p.name, p.brand, p.image_url
      LIMIT 3
    `, ['%tea%']);
    console.log('Results:', test2.rows.length);
    console.log(JSON.stringify(test2.rows, null, 2));

    // Test 3: Get products by category (Snacks)
    console.log('\n=== TEST 3: Get products by category (Snacks) ===');
    const test3 = await client.query(`
      SELECT
        p.barcode,
        p.name,
        p.brand,
        p.image_url,
        STRING_AGG(DISTINCT c.name, ',') as categories
      FROM products p
      JOIN product_categories pc ON p.barcode = pc.product_barcode
      JOIN categories c ON pc.category_id = c.id
      WHERE EXISTS (
        SELECT 1 FROM product_categories pc2
        JOIN categories c2 ON pc2.category_id = c2.id
        WHERE pc2.product_barcode = p.barcode
        AND c2.name ILIKE $1
      )
      GROUP BY p.barcode, p.name, p.brand, p.image_url
      LIMIT 3
    `, ['%snack%']);
    console.log('Results:', test3.rows.length);
    console.log(JSON.stringify(test3.rows, null, 2));

    // Test 4: Get products by category (Beverages)
    console.log('\n=== TEST 4: Get products by category (Beverages) ===');
    const test4 = await client.query(`
      SELECT
        p.barcode,
        p.name,
        p.brand,
        p.image_url,
        STRING_AGG(DISTINCT c.name, ',') as categories
      FROM products p
      JOIN product_categories pc ON p.barcode = pc.product_barcode
      JOIN categories c ON pc.category_id = c.id
      WHERE EXISTS (
        SELECT 1 FROM product_categories pc2
        JOIN categories c2 ON pc2.category_id = c2.id
        WHERE pc2.product_barcode = p.barcode
        AND c2.name ILIKE $1
      )
      GROUP BY p.barcode, p.name, p.brand, p.image_url
      LIMIT 3
    `, ['%beverage%']);
    console.log('Results:', test4.rows.length);
    console.log(JSON.stringify(test4.rows, null, 2));

    // Test 5: See what categories exist
    console.log('\n=== TEST 5: Sample categories ===');
    const test5 = await client.query(`
      SELECT name, level FROM categories WHERE level <= 1 ORDER BY name LIMIT 20
    `);
    console.log('Sample categories:');
    test5.rows.forEach(row => console.log(`  - ${row.name} (level ${row.level})`));

  } catch (err) {
    console.error('Error:', err.message);
    console.error(err.stack);
  } finally {
    await client.end();
  }
}

testQueries();

