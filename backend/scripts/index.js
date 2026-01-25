// Railway API Server v2.4.0 - Normalized Database Schema
// Updated: January 25, 2026
const express = require('express');
const { Pool } = require('pg');

const app = express();
const port = process.env.PORT || 3000;

console.log('=== Server Initialization v2.4.0 - DEPLOYMENT ID: 2026-01-25-FIX ===');
console.log('PORT:', port);
console.log('DATABASE_URL:', process.env.DATABASE_URL ? 'Set' : 'Not set');
console.log('NODE_ENV:', process.env.NODE_ENV || 'development');
console.log('SCHEMA: Normalized with categories JOIN');

// Connect to Railway Postgres
let pool = null;
if (process.env.DATABASE_URL) {
  try {
    pool = new Pool({
      connectionString: process.env.DATABASE_URL,
      // Don't wait for connection on startup
      connectionTimeoutMillis: 5000,
      idleTimeoutMillis: 30000,
    });
    console.log('✓ Database pool created (will connect on first query)');

    // Test connection in background (non-blocking)
    pool.query('SELECT NOW()')
      .then(() => console.log('✓ Database connection verified'))
      .catch((err) => console.error('✗ Database connection test failed:', err.message));
  } catch (err) {
    console.error('✗ Database pool creation failed:', err);
  }
} else {
  console.warn('WARNING: DATABASE_URL not set');
}

// Middleware
app.use(express.json());

// CORS headers for all requests
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  // Handle preflight
  if (req.method === 'OPTIONS') {
    return res.sendStatus(200);
  }

  next();
});

// Request logging - BEFORE routes
app.use((req, res, next) => {
  console.log(`[REQUEST] ${req.method} ${req.url} from ${req.ip}`);
  next();
});

// Railway health check endpoint (they might check /health instead of /)
app.get('/health', (req, res) => {
  console.log('>>> /health endpoint hit <<<');
  res.status(200).send('OK');
});

// Root health check
app.get('/', (req, res) => {
  console.log('>>> / endpoint hit <<<');
  res.status(200).json({
    status: 'running',
    timestamp: new Date().toISOString(),
    database: pool ? 'connected' : 'not configured',
    port: port
  });
});

// Get all products with their categories
app.get('/api/products', async (req, res) => {
  if (!pool) {
    return res.status(503).json({ error: 'Database not configured' });
  }
  try {
    const limit = req.query.limit || 100;
    // Get products with their categories joined
    const result = await pool.query(`
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
      LIMIT $1
    `, [limit]);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Database error' });
  }
});

// Get product by barcode with categories
app.get('/api/products/:barcode', async (req, res) => {
  if (!pool) {
    return res.status(503).json({ error: 'Database not configured' });
  }
  try {
    const { barcode } = req.params;
    const result = await pool.query(`
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
      WHERE p.barcode = $1
      GROUP BY p.barcode, p.name, p.brand, p.image_url, p.is_vegan, p.is_vegetarian, p.is_gluten_free, p.is_dairy_free
    `, [barcode]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Product not found' });
    }
    
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Database error' });
  }
});

// Search products by name with categories
app.get('/api/search', async (req, res) => {
  if (!pool) {
    return res.status(503).json({ error: 'Database not configured' });
  }
  try {
    const { q } = req.query;
    const result = await pool.query(`
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
      WHERE p.name ILIKE $1
      GROUP BY p.barcode, p.name, p.brand, p.image_url, p.is_vegan, p.is_vegetarian, p.is_gluten_free, p.is_dairy_free
      LIMIT 20
    `, [`%${q}%`]);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Database error' });
  }
});

// Get products by category (now using normalized category table)
app.get('/api/categories/:category', async (req, res) => {
  if (!pool) {
    return res.status(503).json({ error: 'Database not configured' });
  }
  try {
    const { category } = req.params;
    const limit = req.query.limit || 20;

    console.log(`Fetching products for category: ${category}`);

    // Query products that have this category (match by category name pattern)
    const result = await pool.query(`
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
      JOIN product_categories pc ON p.barcode = pc.product_barcode
      JOIN categories c ON pc.category_id = c.id
      WHERE EXISTS (
        SELECT 1 FROM product_categories pc2
        JOIN categories c2 ON pc2.category_id = c2.id
        WHERE pc2.product_barcode = p.barcode
        AND c2.name ILIKE $1
      )
      GROUP BY p.barcode, p.name, p.brand, p.image_url, p.is_vegan, p.is_vegetarian, p.is_gluten_free, p.is_dairy_free
      LIMIT $2
    `, [`%${category}%`, limit]);

    console.log(`Found ${result.rows.length} products for category: ${category}`);
    res.json(result.rows);
  } catch (err) {
    console.error('Error in /api/categories/:category:', err);
    res.status(500).json({ error: 'Database error' });
  }
});

// Get products from multiple categories (batch request)
app.get('/api/categories-batch', async (req, res) => {
  if (!pool) {
    return res.status(503).json({ error: 'Database not configured' });
  }
  try {
    const categories = req.query.categories?.split(',') || [];
    const limit = req.query.limit || 20;

    console.log(`Batch request for categories: ${categories.join(', ')}`);

    if (categories.length === 0) {
      return res.json({});
    }

    const results = {};

    // Fetch products for each category
    for (const category of categories) {
      const result = await pool.query(`
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
        JOIN product_categories pc ON p.barcode = pc.product_barcode
        JOIN categories c ON pc.category_id = c.id
        WHERE EXISTS (
          SELECT 1 FROM product_categories pc2
          JOIN categories c2 ON pc2.category_id = c2.id
          WHERE pc2.product_barcode = p.barcode
          AND c2.name ILIKE $1
        )
        GROUP BY p.barcode, p.name, p.brand, p.image_url, p.is_vegan, p.is_vegetarian, p.is_gluten_free, p.is_dairy_free
        LIMIT $2
      `, [`%${category}%`, limit]);

      results[category] = result.rows;
      console.log(`  ${category}: ${result.rows.length} products`);
    }

    console.log(`Batch request complete, returning ${Object.keys(results).length} categories`);
    res.json(results);
  } catch (err) {
    console.error('Error in /api/categories-batch:', err);
    res.status(500).json({ error: 'Database error' });
  }
});

// Get specific products by barcodes (for prioritized display) with categories
app.get('/api/products-by-barcodes', async (req, res) => {
  if (!pool) {
    return res.status(503).json({ error: 'Database not configured' });
  }
  try {
    const barcodes = req.query.barcodes?.split(',') || [];

    if (barcodes.length === 0) {
      return res.json([]);
    }

    console.log(`Fetching ${barcodes.length} products by barcodes`);

    // Create placeholders for parameterized query
    const placeholders = barcodes.map((_, i) => `$${i + 1}`).join(',');
    const query = `
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
      WHERE p.barcode IN (${placeholders})
      GROUP BY p.barcode, p.name, p.brand, p.image_url, p.is_vegan, p.is_vegetarian, p.is_gluten_free, p.is_dairy_free
    `;

    const result = await pool.query(query, barcodes);

    // Return products in the same order as requested barcodes
    const productsMap = {};
    result.rows.forEach(product => {
      productsMap[product.barcode] = product;
    });

    const orderedProducts = barcodes
      .map(barcode => productsMap[barcode])
      .filter(product => product !== undefined);

    console.log(`Found ${orderedProducts.length} products by barcodes`);
    res.json(orderedProducts);
  } catch (err) {
    console.error('Error in /api/products-by-barcodes:', err);
    res.status(500).json({ error: 'Database error' });
  }
});

// Debug endpoint: Get sample of categories from new schema
app.get('/api/debug/categories', async (req, res) => {
  if (!pool) {
    return res.status(503).json({ error: 'Database not configured' });
  }
  try {
    const result = await pool.query(
      'SELECT id, name, parent_id, level FROM categories ORDER BY name LIMIT 50'
    );
    res.json({
      count: result.rows.length,
      samples: result.rows
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Database error' });
  }
});

// Debug endpoint: Get database stats
app.get('/api/debug/stats', async (req, res) => {
  if (!pool) {
    return res.status(503).json({ error: 'Database not configured' });
  }
  try {
    const countResult = await pool.query('SELECT COUNT(*) FROM products');
    const categoryCountResult = await pool.query('SELECT COUNT(*) FROM categories');
    const sampleResult = await pool.query(`
      SELECT
        p.barcode,
        p.name,
        p.brand,
        p.image_url,
        STRING_AGG(DISTINCT c.name, ',') as categories
      FROM products p
      LEFT JOIN product_categories pc ON p.barcode = pc.product_barcode
      LEFT JOIN categories c ON pc.category_id = c.id
      GROUP BY p.barcode, p.name, p.brand, p.image_url
      LIMIT 5
    `);

    res.json({
      totalProducts: countResult.rows[0].count,
      totalCategories: categoryCountResult.rows[0].count,
      sampleProducts: sampleResult.rows
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Database error', message: err.message });
  }
});

// Catch-all route for debugging
app.use('*', (req, res) => {
  console.log('>>> Catch-all hit:', req.method, req.originalUrl);
  res.status(404).json({ error: 'Not found', path: req.originalUrl });
});

// Global error handler
app.use((err, req, res, next) => {
  console.error('!!! Global error:', err.message);
  console.error(err.stack);
  res.status(500).json({ error: 'Server error', message: err.message });
});

// Start server
const server = app.listen(port, '0.0.0.0', () => {
  console.log('=== Server Started ===');
  console.log(`✓ Listening on 0.0.0.0:${port}`);
  console.log(`✓ Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log('✓ Server ready to accept connections');
  console.log('======================');
});

// Handle server errors
server.on('error', (err) => {
  console.error('!!! Server error:', err);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, closing server...');
  server.close(() => {
    console.log('Server closed');
    if (pool) pool.end();
    process.exit(0);
  });
});
