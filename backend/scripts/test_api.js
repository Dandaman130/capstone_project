// Test script to verify Railway deployment API endpoints
const https = require('https');
const http = require('http');

const BASE_URL = 'https://capstoneproject-production-fb1c.up.railway.app';

function makeRequest(path) {
  return new Promise((resolve, reject) => {
    const url = `${BASE_URL}${path}`;
    console.log(`\nTesting: ${url}`);

    https.get(url, (res) => {
      let data = '';

      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          console.log(`✓ Status: ${res.statusCode}`);
          console.log(`✓ Response:`, JSON.stringify(parsed, null, 2).substring(0, 500));
          resolve(parsed);
        } catch (e) {
          console.log(`✓ Status: ${res.statusCode}`);
          console.log(`✓ Response (text):`, data.substring(0, 200));
          resolve(data);
        }
      });
    }).on('error', (err) => {
      console.error(`✗ Error: ${err.message}`);
      reject(err);
    });
  });
}

async function testAPI() {
  console.log('=== Testing Railway API Endpoints ===\n');

  try {
    // Test 1: Root endpoint
    console.log('\n--- Test 1: Health Check ---');
    await makeRequest('/');

    // Test 2: Get products
    console.log('\n--- Test 2: Get Products ---');
    await makeRequest('/api/products?limit=2');

    // Test 3: Search
    console.log('\n--- Test 3: Search (tea) ---');
    await makeRequest('/api/search?q=tea');

    // Test 4: Get by category
    console.log('\n--- Test 4: Get Products by Category (Snacks) ---');
    await makeRequest('/api/categories/Snacks?limit=3');

    // Test 5: Batch categories
    console.log('\n--- Test 5: Batch Categories (Snacks, Beverages) ---');
    await makeRequest('/api/categories-batch?categories=Snacks,Beverages&limit=2');

    // Test 6: Get by barcodes
    console.log('\n--- Test 6: Get by Barcodes ---');
    await makeRequest('/api/products-by-barcodes?barcodes=0000209024937,0000141013129');

    console.log('\n\n=== All tests complete ===');
  } catch (err) {
    console.error('Test failed:', err);
  }
}

testAPI();

