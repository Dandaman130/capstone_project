/**
 * import_recipes_csv.js
 *
 * Phase-1 recipe import for capstone demo.
 * Streams a recipe CSV and fills recipe + ingredient tables.
 *
 * Usage (PowerShell):
 *   $env:DATABASE_URL = "postgresql://..."
 *   $env:RECIPES_CSV = "D:\\path\\to\\recipes.csv"
 *   $env:RECIPE_LIMIT = "50000"   # optional, default 50000
 *   node import_recipes_csv.js
 */

'use strict';

const fs = require('fs');
const { Pool } = require('pg');
const csv = require('csv-parser');

const DATABASE_URL = process.env.DATABASE_URL;
const RECIPES_CSV = process.env.RECIPES_CSV;
const RECIPE_LIMIT = Number(process.env.RECIPE_LIMIT || 50000);
const START_ROW = Number(process.env.START_ROW || 1);
const LOG_EVERY_ROWS = Number(process.env.LOG_EVERY_ROWS || 50);
const HEARTBEAT_SECONDS = Number(process.env.HEARTBEAT_SECONDS || 10);

if (!DATABASE_URL) {
  console.error('DATABASE_URL is required.');
  process.exit(1);
}

if (!RECIPES_CSV) {
  console.error('RECIPES_CSV is required.');
  process.exit(1);
}

const pool = new Pool({ connectionString: DATABASE_URL });

function normalizeIngredientName(value) {
  if (!value) return '';
  return String(value)
    .toLowerCase()
    .replace(/\([^)]*\)/g, ' ')
    .replace(/[^a-z0-9\s-]/g, ' ')
    .replace(/\b(chopped|diced|minced|fresh|optional|to taste|large|small|medium)\b/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function parseIngredientList(raw) {
  if (!raw) return [];
  const text = String(raw).trim();
  if (!text) return [];

  // Try JSON-like list first.
  if ((text.startsWith('[') && text.endsWith(']')) || (text.startsWith('{') && text.endsWith('}'))) {
    try {
      const parsed = JSON.parse(text.replace(/'/g, '"'));
      if (Array.isArray(parsed)) return parsed.map(String);
    } catch (_) {
      // Fall through to delimiter split.
    }
  }

  return text
    .split(/[|,;]+/)
    .map((s) => s.trim())
    .filter(Boolean);
}

function pickField(row, candidates) {
  for (const name of candidates) {
    if (row[name] != null && String(row[name]).trim() !== '') return row[name];
  }
  return '';
}

async function getOrCreateCanonicalId(normalizedName, cache) {
  const existing = cache.get(normalizedName);
  if (existing) return existing;

  const aliasHit = await pool.query(
    'SELECT canonical_ingredient_id FROM ingredient_aliases WHERE alias = $1',
    [normalizedName]
  );
  if (aliasHit.rows.length > 0) {
    const id = aliasHit.rows[0].canonical_ingredient_id;
    cache.set(normalizedName, id);
    return id;
  }

  const created = await pool.query(
    `INSERT INTO canonical_ingredients (name)
     VALUES ($1)
     ON CONFLICT (name) DO UPDATE SET name = EXCLUDED.name
     RETURNING id`,
    [normalizedName]
  );
  const id = created.rows[0].id;

  await pool.query(
    `INSERT INTO ingredient_aliases (alias, canonical_ingredient_id)
     VALUES ($1, $2)
     ON CONFLICT (alias) DO NOTHING`,
    [normalizedName, id]
  );

  cache.set(normalizedName, id);
  return id;
}

async function run() {
  console.log('=== Recipe CSV import starting ===');
  console.log(`File: ${RECIPES_CSV}`);
  console.log(`Start row: ${START_ROW.toLocaleString()}`);
  console.log(`Limit: ${RECIPE_LIMIT.toLocaleString()}`);
  console.log(`Log every rows: ${LOG_EVERY_ROWS.toLocaleString()}`);
  console.log(`Heartbeat seconds: ${HEARTBEAT_SECONDS.toLocaleString()}`);

  const canonicalCache = new Map();
  let readRows = 0;
  let insertedRecipes = 0;
  let skippedRows = 0;
  let reachedStartRow = START_ROW <= 1;

  let heartbeat = null;
  if (HEARTBEAT_SECONDS > 0) {
    heartbeat = setInterval(() => {
      console.log(
        `Heartbeat: read=${readRows.toLocaleString()} inserted=${insertedRecipes.toLocaleString()} skipped=${skippedRows.toLocaleString()}`
      );
    }, HEARTBEAT_SECONDS * 1000);
  }

  const stream = fs.createReadStream(RECIPES_CSV).pipe(csv());

  for await (const row of stream) {
    readRows++;
    if (!reachedStartRow && readRows >= START_ROW) {
      reachedStartRow = true;
      console.log(`Reached start row at read=${readRows.toLocaleString()}`);
    }

    if (readRows < START_ROW) {
      continue;
    }

    if (LOG_EVERY_ROWS > 0 && readRows % LOG_EVERY_ROWS === 0) {
      console.log(
        `Progress: read=${readRows.toLocaleString()} inserted=${insertedRecipes.toLocaleString()} skipped=${skippedRows.toLocaleString()}`
      );
    }

    if (insertedRecipes >= RECIPE_LIMIT) break;

    const title = String(pickField(row, ['title', 'Title'])).trim();
    if (!title) {
      skippedRows++;
      continue;
    }

    const rawIngredients = String(
      pickField(row, [
        'ingredients',
        'Ingredients',
        'ingredients_organized',
        'ingredients_organized_name',
        'NER',
      ])
    ).trim();

    const directions = String(pickField(row, ['directions', 'Directions', 'instructions'])).trim();
    const source = String(pickField(row, ['source', 'Source'])).trim();
    const sourceSite = String(pickField(row, ['site', 'Site'])).trim();
    const sourceLink = String(pickField(row, ['link', 'Link', 'url'])).trim();

    const ingredients = parseIngredientList(rawIngredients)
      .map(normalizeIngredientName)
      .filter(Boolean);

    if (ingredients.length === 0) {
      skippedRows++;
      continue;
    }

    const recipeInsert = await pool.query(
      `INSERT INTO recipes (title, directions, source, source_site, source_link, raw_ingredients)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id`,
      [title, directions, source, sourceSite, sourceLink, rawIngredients]
    );

    const recipeId = recipeInsert.rows[0].id;

    for (const ing of ingredients) {
      const canonicalId = await getOrCreateCanonicalId(ing, canonicalCache);

      await pool.query(
        `INSERT INTO recipe_ingredients (recipe_id, raw_name, normalized_name)
         VALUES ($1, $2, $3)
         ON CONFLICT (recipe_id, normalized_name) DO NOTHING`,
        [recipeId, ing, ing]
      );

      await pool.query(
        `INSERT INTO recipe_canonical_ingredients (recipe_id, canonical_ingredient_id)
         VALUES ($1, $2)
         ON CONFLICT (recipe_id, canonical_ingredient_id) DO NOTHING`,
        [recipeId, canonicalId]
      );
    }

    insertedRecipes++;
    if (insertedRecipes % 1000 === 0) {
      console.log(
        `Imported ${insertedRecipes.toLocaleString()} recipes (read ${readRows.toLocaleString()}, skipped ${skippedRows.toLocaleString()})...`
      );
    }
  }

  console.log('\n=== Import complete ===');
  console.log(`Rows read: ${readRows.toLocaleString()}`);
  console.log(`Recipes inserted: ${insertedRecipes.toLocaleString()}`);
  console.log(`Rows skipped: ${skippedRows.toLocaleString()}`);

  if (heartbeat) {
    clearInterval(heartbeat);
  }
}

run()
  .catch((err) => {
    console.error('Import failed:', err.message);
    console.error(err.stack);
    process.exitCode = 1;
  })
  .finally(async () => {
    await pool.end();
  });
