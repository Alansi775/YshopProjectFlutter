import express from 'express';
import pool from '../config/database.js';

const router = express.Router();

/**
 * Helper function to get display name from category name
 */
function getDisplayName(categoryName) {
  const categoryMap = {
    fruits: 'Fruits 🍎',
    vegetables: 'Vegetables 🥕',
    beverages: 'Beverages 🥤',
    meat: 'Meat 🥩',
    chicken: 'Chicken 🍗',
    bakery: 'Bakery 🍞',
    canned_goods: 'Canned Goods 🥫',
    cleaning: 'Cleaning Supplies 🧹',
    dairy: 'Dairy 🧀',
    frozen: 'Frozen Foods ❄️',
    snacks: 'Snacks 🍿',
    condiments: 'Condiments 🧂',
  };

  return categoryMap[categoryName?.toLowerCase()] || categoryName;
}

// ============================================
// GET /stores/:storeId/categories
// Get all categories for a store
// ============================================
router.get('/:storeId/categories', async (req, res) => {
  const { storeId } = req.params;

  try {
    const query = `
      SELECT 
        id,
        store_id,
        name,
        display_name,
        icon,
        created_at,
        updated_at
      FROM categories
      WHERE store_id = ?
      ORDER BY created_at DESC
    `;

    const [categories] = await pool.query(query, [storeId]);

    // Count products in each category
    const result = await Promise.all(
      categories.map(async (cat) => {
        const [products] = await pool.query(
          'SELECT name FROM products WHERE category_id = ? ORDER BY updated_at DESC LIMIT 1',
          [cat.id]
        );
        return {
          ...cat,
          productCount: (await pool.query('SELECT COUNT(*) as count FROM products WHERE category_id = ?', [cat.id]))[0][0]?.count || 0,
          lastProductName: products.length > 0 ? products[0].name : '',
        };
      })
    );

    res.json({ data: result });
  } catch (error) {
    console.error('❌ Error fetching categories:', error);
    res.status(500).json({ error: 'Failed to fetch categories' });
  }
});

// ============================================
// POST /stores/:storeId/categories
// Create a new category
// ============================================
router.post('/:storeId/categories', async (req, res) => {
  const { storeId } = req.params;
  const { name } = req.body;

  // Validation
  if (!name || name.trim() === '') {
    return res.status(400).json({ error: 'Category name is required' });
  }

  try {
    const displayName = getDisplayName(name);

    const query = `
      INSERT INTO categories (store_id, name, display_name, created_at, updated_at)
      VALUES (?, ?, ?, NOW(), NOW())
    `;

    const [result] = await pool.query(query, [storeId, name, displayName]);

    res.json({
      data: {
        id: result.insertId,
        store_id: parseInt(storeId),
        name,
        display_name: displayName,
        created_at: new Date(),
        updated_at: new Date(),
      },
    });
  } catch (error) {
    console.error('❌ Error creating category:', error);
    if (error.code === 'ER_DUP_ENTRY') {
      return res.status(400).json({ error: 'Category already exists' });
    }
    res.status(500).json({ error: 'Failed to create category' });
  }
});

// ============================================
// DELETE /stores/:storeId/categories/:categoryId
// Delete a category (move products out)
// ============================================
router.delete('/:storeId/categories/:categoryId', async (req, res) => {
  const { storeId, categoryId } = req.params;

  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    // Remove category_id from all products
    await connection.query(
      'UPDATE products SET category_id = NULL WHERE category_id = ?',
      [categoryId]
    );

    // Delete the category
    await connection.query(
      'DELETE FROM categories WHERE id = ? AND store_id = ?',
      [categoryId, storeId]
    );

    await connection.commit();
    res.json({ success: true });
  } catch (error) {
    await connection.rollback();
    console.error('❌ Error deleting category:', error);
    res.status(500).json({ error: 'Failed to delete category' });
  } finally {
    connection.release();
  }
});

// ============================================
// GET /categories/:categoryId/products
// Get all products in a category
// ============================================
router.get('/categories/:categoryId/products', async (req, res) => {
  const { categoryId } = req.params;

  try {
    const query = `
      SELECT 
        id,
        name,
        price,
        currency,
        description,
        image_url,
        status,
        stock,
        category_id
      FROM products
      WHERE category_id = ?
      ORDER BY updated_at DESC
    `;

    const [products] = await pool.query(query, [categoryId]);
    res.json({ data: products });
  } catch (error) {
    console.error('❌ Error fetching category products:', error);
    res.status(500).json({ error: 'Failed to fetch products' });
  }
});

// ============================================
// PUT /products/:productId/category
// Assign or remove product from category
// ============================================
router.put('/products/:productId/category', async (req, res) => {
  const { productId } = req.params;
  const { category_id } = req.body;

  try {
    if (category_id === null) {
      // Remove from category
      await pool.query(
        'UPDATE products SET category_id = NULL WHERE id = ?',
        [productId]
      );
    } else {
      // Assign to category
      await pool.query(
        'UPDATE products SET category_id = ? WHERE id = ?',
        [category_id, productId]
      );
    }

    res.json({ success: true });
  } catch (error) {
    console.error('❌ Error updating product category:', error);
    res.status(500).json({ error: 'Failed to update category' });
  }
});

export default router;
