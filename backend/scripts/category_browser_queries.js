const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 100;

const CATEGORY_ROWS_QUERY = `
  WITH RECURSIVE row_categories AS (
    SELECT
      c.id,
      c.name,
      c.parent_id,
      c.level
    FROM categories c
    WHERE ($1::INT IS NULL AND c.parent_id IS NULL)
       OR c.parent_id = $1::INT
  ),
  category_tree AS (
    SELECT
      rc.id AS row_category_id,
      rc.id AS descendant_category_id,
      ARRAY[rc.id] AS path
    FROM row_categories rc

    UNION ALL

    SELECT
      ct.row_category_id,
      c.id AS descendant_category_id,
      ct.path || c.id
    FROM category_tree ct
    JOIN categories c ON c.parent_id = ct.descendant_category_id
    WHERE NOT (c.id = ANY(ct.path))
  ),
  distinct_products_base AS (
    SELECT DISTINCT
      ct.row_category_id,
      p.barcode,
      p.name,
      p.brand,
      p.image_url,
      p.is_vegan,
      p.is_vegetarian,
      p.is_gluten_free,
      p.is_dairy_free
    FROM category_tree ct
    JOIN product_categories pc ON pc.category_id = ct.descendant_category_id
    JOIN products p ON p.barcode = pc.product_barcode
  ),
  selected_barcodes AS (
    SELECT DISTINCT barcode
    FROM distinct_products_base
  ),
  product_category_strings AS (
    SELECT
      pc.product_barcode,
      STRING_AGG(DISTINCT c.name, ',' ORDER BY c.name) AS categories
    FROM product_categories pc
    JOIN categories c ON c.id = pc.category_id
    JOIN selected_barcodes sb ON sb.barcode = pc.product_barcode
    GROUP BY pc.product_barcode
  ),
  distinct_products AS (
    SELECT
      dpb.row_category_id,
      dpb.barcode,
      dpb.name,
      dpb.brand,
      dpb.image_url,
      dpb.is_vegan,
      dpb.is_vegetarian,
      dpb.is_gluten_free,
      dpb.is_dairy_free,
      COALESCE(pcs.categories, '') AS categories
    FROM distinct_products_base dpb
    LEFT JOIN product_category_strings pcs ON pcs.product_barcode = dpb.barcode
  ),
  ranked_products AS (
    SELECT
      dp.*,
      ROW_NUMBER() OVER (
        PARTITION BY dp.row_category_id
        ORDER BY dp.name NULLS LAST, dp.barcode
      ) AS rn
    FROM distinct_products dp
  ),
  products_by_row AS (
    SELECT
      rp.row_category_id,
      COUNT(*) AS total_products,
      COALESCE(
        JSON_AGG(
          JSON_BUILD_OBJECT(
            'barcode', rp.barcode,
            'name', rp.name,
            'brand', rp.brand,
            'image_url', rp.image_url,
            'is_vegan', rp.is_vegan,
            'is_vegetarian', rp.is_vegetarian,
            'is_gluten_free', rp.is_gluten_free,
            'is_dairy_free', rp.is_dairy_free,
            'categories', rp.categories
          )
          ORDER BY rp.rn
        ) FILTER (WHERE rp.rn <= $2::INT),
        '[]'::JSON
      ) AS products
    FROM ranked_products rp
    GROUP BY rp.row_category_id
  )
  SELECT
    rc.id AS category_id,
    rc.name AS category_name,
    rc.parent_id,
    rc.level,
    EXISTS(
      SELECT 1
      FROM categories child
      WHERE child.parent_id = rc.id
    ) AS has_children,
    COALESCE(pr.total_products, 0) AS total_products,
    COALESCE(pr.products, '[]'::JSON) AS products
  FROM row_categories rc
  LEFT JOIN products_by_row pr ON pr.row_category_id = rc.id
  ORDER BY rc.name;
`;

const CATEGORY_BREADCRUMB_QUERY = `
  WITH RECURSIVE ancestors AS (
    SELECT
      c.id,
      c.name,
      c.parent_id,
      c.level,
      0 AS depth
    FROM categories c
    WHERE c.id = $1::INT

    UNION ALL

    SELECT
      parent.id,
      parent.name,
      parent.parent_id,
      parent.level,
      a.depth + 1 AS depth
    FROM categories parent
    JOIN ancestors a ON a.parent_id = parent.id
  )
  SELECT
    id,
    name,
    parent_id,
    level
  FROM ancestors
  ORDER BY depth DESC;
`;

function parseParentCategoryId(rawParentCategoryId) {
  if (rawParentCategoryId === undefined || rawParentCategoryId === null || rawParentCategoryId === '') {
    return null;
  }

  const parsed = Number.parseInt(rawParentCategoryId, 10);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new Error('parent_id must be a positive integer when provided');
  }

  return parsed;
}

function parseLimit(rawLimit) {
  if (rawLimit === undefined || rawLimit === null || rawLimit === '') {
    return DEFAULT_LIMIT;
  }

  const parsed = Number.parseInt(rawLimit, 10);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new Error('limit must be a positive integer');
  }

  return Math.min(parsed, MAX_LIMIT);
}

async function getCategoryRows(pool, { parentCategoryId, limitPerCategory }) {
  const parsedParentCategoryId = parseParentCategoryId(parentCategoryId);
  const parsedLimit = parseLimit(limitPerCategory);

  const result = await pool.query(CATEGORY_ROWS_QUERY, [parsedParentCategoryId, parsedLimit]);
  return {
    parentCategoryId: parsedParentCategoryId,
    limitPerCategory: parsedLimit,
    rows: result.rows,
  };
}

async function getCategoryBreadcrumb(pool, categoryId) {
  const parsedCategoryId = parseParentCategoryId(categoryId);
  if (parsedCategoryId === null) {
    throw new Error('category id is required');
  }

  const result = await pool.query(CATEGORY_BREADCRUMB_QUERY, [parsedCategoryId]);
  return result.rows;
}

module.exports = {
  getCategoryRows,
  getCategoryBreadcrumb,
};
