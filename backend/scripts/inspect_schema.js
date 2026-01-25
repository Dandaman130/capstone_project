const { Client } = require('pg');

const DATABASE_URL = "postgresql://postgres:cFGvTOMRZauZulyRoryYpJILFUszgorI@switchyard.proxy.rlwy.net:29111/railway";

async function inspectSchema() {
  const client = new Client({
    connectionString: DATABASE_URL,
  });

  try {
    await client.connect();
    console.log('✓ Connected to database\n');

    // Get all tables
    const tablesQuery = `
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = 'public'
      ORDER BY table_name;
    `;
    const tables = await client.query(tablesQuery);

    console.log('=== DATABASE TABLES ===');
    tables.rows.forEach(row => {
      console.log(`  - ${row.table_name}`);
    });
    console.log('');

    // Get schema for each table
    for (const table of tables.rows) {
      const tableName = table.table_name;

      console.log(`\n=== TABLE: ${tableName} ===`);

      // Get columns
      const columnsQuery = `
        SELECT
          column_name,
          data_type,
          is_nullable,
          column_default
        FROM information_schema.columns
        WHERE table_name = $1
        ORDER BY ordinal_position;
      `;
      const columns = await client.query(columnsQuery, [tableName]);

      console.log('Columns:');
      columns.rows.forEach(col => {
        console.log(`  - ${col.column_name}: ${col.data_type}${col.is_nullable === 'NO' ? ' NOT NULL' : ''}`);
      });

      // Get row count
      const countQuery = `SELECT COUNT(*) as count FROM ${tableName};`;
      const count = await client.query(countQuery);
      console.log(`\nRow Count: ${count.rows[0].count}`);

      // Get sample data (first 2 rows)
      const sampleQuery = `SELECT * FROM ${tableName} LIMIT 2;`;
      const sample = await client.query(sampleQuery);
      if (sample.rows.length > 0) {
        console.log('\nSample Data:');
        console.log(JSON.stringify(sample.rows, null, 2));
      }
    }

  } catch (err) {
    console.error('Error:', err.message);
  } finally {
    await client.end();
  }
}

inspectSchema();

