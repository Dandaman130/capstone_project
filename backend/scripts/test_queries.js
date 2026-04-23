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
        p.is_vegan,
        p.is_vegetarian,
        p.is_gluten_free,
        p.is_dairy_free,
        STRING_AGG(DISTINCT c.name, ',') as categories
      FROM products p
      LEFT JOIN product_categories pc ON p.id = pc.product_id
      LEFT JOIN categories c ON pc.category_id = c.id
      GROUP BY p.barcode, p.name, p.brand, p.is_vegan, p.is_vegetarian, p.is_gluten_free, p.is_dairy_free
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
        STRING_AGG(DISTINCT c.name, ',') as categories
      FROM products p
      LEFT JOIN product_categories pc ON p.id = pc.product_id
      LEFT JOIN categories c ON pc.category_id = c.id
      WHERE p.name ILIKE $1
      GROUP BY p.barcode, p.name, p.brand
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
        STRING_AGG(DISTINCT c.name, ',') as categories
      FROM products p
      JOIN product_categories pc ON p.id = pc.product_id
      JOIN categories c ON pc.category_id = c.id
      WHERE EXISTS (
        SELECT 1 FROM product_categories pc2
        JOIN categories c2 ON pc2.category_id = c2.id
        WHERE pc2.product_id = p.id
        AND c2.name ILIKE $1
      )
      GROUP BY p.barcode, p.name, p.brand
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
        STRING_AGG(DISTINCT c.name, ',') as categories
      FROM products p
      JOIN product_categories pc ON p.id = pc.product_id
      JOIN categories c ON pc.category_id = c.id
      WHERE EXISTS (
        SELECT 1 FROM product_categories pc2
        JOIN categories c2 ON pc2.category_id = c2.id
        WHERE pc2.product_id = p.id
        AND c2.name ILIKE $1
      )
      GROUP BY p.barcode, p.name, p.brand
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

    // Test 6: Get root categories (most populated) - for the new getRootCategories API
    console.log('\n=== TEST 6: Root categories (most populated) ===');
    const test6 = await client.query(`
      WITH RECURSIVE root_categories AS (
        SELECT c.id, c.name
        FROM categories c
        WHERE c.parent_id IS NULL
      ),
      tree AS (
        SELECT rc.id AS root_id, rc.id AS category_id
        FROM root_categories rc

        UNION ALL

        SELECT t.root_id, c.id AS category_id
        FROM tree t
        JOIN categories c ON c.parent_id = t.category_id
      ),
      root_product_counts AS (
        SELECT
          t.root_id,
          COUNT(DISTINCT p.barcode) AS product_count
        FROM tree t
        LEFT JOIN product_categories pc ON pc.category_id = t.category_id
        LEFT JOIN products p ON p.id = pc.product_id
        GROUP BY t.root_id
      )
      SELECT
        rc.name,
        COALESCE(rpc.product_count, 0) AS product_count
      FROM root_categories rc
      LEFT JOIN root_product_counts rpc ON rpc.root_id = rc.id
      ORDER BY COALESCE(rpc.product_count, 0) DESC, rc.name ASC
      LIMIT 10
    `);
    console.log('Root categories (top 10):');
    test6.rows.forEach(row => console.log(`  - ${row.name} (${row.product_count} products)`));
    console.log(`Returned: ${test6.rows.length}`);

    // Test 7: Get products by multiple root categories at once
    console.log('\n=== TEST 7: Products from multiple root categories ===');
    const categoryNames = test6.rows.slice(0, 3).map(row => row.name);
    console.log(`Fetching products from: ${categoryNames.join(', ')}`);
    const test7 = await client.query(`
      SELECT DISTINCT
        p.barcode,
        p.name,
        p.brand,
        STRING_AGG(DISTINCT c.name, ',') as categories
      FROM products p
      LEFT JOIN product_categories pc ON p.id = pc.product_id
      LEFT JOIN categories c ON pc.category_id = c.id
      WHERE EXISTS (
        SELECT 1 FROM product_categories pc2
        JOIN categories c2 ON pc2.category_id = c2.id
        WHERE pc2.product_id = p.id
        AND c2.name = ANY($1)
      )
      GROUP BY p.barcode, p.name, p.brand
      LIMIT 5
    `, [categoryNames]);
    console.log('Results:', test7.rows.length);
    console.log(JSON.stringify(test7.rows.slice(0, 2), null, 2));

  } catch (err) {
    console.error('Error:', err.message);
    console.error(err.stack);
  } finally {
    await client.end();
  }
}

testQueries();
