const express = require('express');
const { Pool } = require('pg');

const app = express();
const port = process.env.PORT || 3000;

// Connect to Railway Postgres
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

app.use(express.json());

// Health check endpoint
app.get('/', (req, res) => {
  res.json({ status: 'Server is running' });
});

// Get all products
app.get('/api/products', async (req, res) => {
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

app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
