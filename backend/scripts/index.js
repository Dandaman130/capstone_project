const express = require('express');
const { Pool } = require('pg');

// Last updated: 2025-12-01 - Force Railway deployment

const app = express();
const port = process.env.PORT || 3000;

console.log('Starting server...');
console.log('PORT:', port);
console.log('DATABASE_URL:', process.env.DATABASE_URL ? 'Set' : 'Not set');

// Connect to Railway Postgres
let pool = null;
if (process.env.DATABASE_URL) {
  pool = new Pool({
    connectionString: process.env.DATABASE_URL,
  });
  console.log('Database pool created');
} else {
  console.warn('WARNING: DATABASE_URL not set - database queries will fail');
}

app.use(express.json());

// Add request logging
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// Health check endpoint
app.get('/', (req, res) => {
  console.log('Health check endpoint hit');
  res.json({
    status: 'Server is running',
    timestamp: new Date().toISOString(),
    database: process.env.DATABASE_URL ? 'connected' : 'not configured'
  });
});

// Get all products
app.get('/api/products', async (req, res) => {
  if (!pool) {
    return res.status(503).json({ error: 'Database not configured' });
  }
  try {
    const result = await pool.query('SELECT * FROM products LIMIT 100');
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Database error' });
  }
});

// Get product by barcode
app.get('/api/products/:barcode', async (req, res) => {
  if (!pool) {
    return res.status(503).json({ error: 'Database not configured' });
  }
  try {
    const { barcode } = req.params;
    const result = await pool.query('SELECT * FROM products WHERE barcode = $1', [barcode]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Product not found' });
    }
    
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Database error' });
  }
});

// Search products by name
app.get('/api/search', async (req, res) => {
  if (!pool) {
    return res.status(503).json({ error: 'Database not configured' });
  }
  try {
    const { q } = req.query;
    const result = await pool.query(
      'SELECT * FROM products WHERE name ILIKE $1 LIMIT 20',
      [`%${q}%`]
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Database error' });
  }
});

// Get products by category
app.get('/api/categories/:category', async (req, res) => {
  if (!pool) {
    return res.status(503).json({ error: 'Database not configured' });
  }
  try {
    const { category } = req.params;
    const limit = req.query.limit || 20;

    const result = await pool.query(
      'SELECT * FROM products WHERE categories ILIKE $1 LIMIT $2',
      [`%${category}%`, limit]
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Database error' });
  }
});

// Get products from multiple categories
app.get('/api/categories-batch', async (req, res) => {
  if (!pool) {
    return res.status(503).json({ error: 'Database not configured' });
  }
  try {
    const categories = req.query.categories?.split(',') || [];
    const limit = req.query.limit || 20;

    if (categories.length === 0) {
      return res.json({});
    }

    const results = {};

    for (const category of categories) {
      const result = await pool.query(
        'SELECT * FROM products WHERE categories ILIKE $1 LIMIT $2',
        [`%${category}%`, limit]
      );
      results[category] = result.rows;
    }

    res.json(results);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Database error' });
  }
});

app.listen(port, '0.0.0.0', () => {
  console.log(`Server running on port ${port}`);
  console.log(`Server is listening on 0.0.0.0:${port}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log('Ready to accept connections');
});
