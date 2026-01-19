// Backend API Implementation - Category Management
// FILE: backend/src/routes/categories.js

const express = require('express');
const router = express.Router();
const db = require('../config/database'); // مثال: استخدام connection pool

// ============================================
// GET /stores/:storeId/categories
// Get all categories for a store
// ============================================
router.get('/stores/:storeId/categories', async (req, res) => {
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

    const [categories] = await db.query(query, [storeId]);

    // عد المنتجات في كل فئة
    const result = await Promise.all(
      categories.map(async (cat) => {
        const [products] = await db.query(
          'SELECT name FROM products WHERE category_id = ? ORDER BY updated_at DESC LIMIT 1',
          [cat.id]
        );
        return {
          ...cat,
          lastProductName: products.length > 0 ? products[0].name : '',
        };
      })
    );

    res.json({ data: result });
  } catch (error) {
    console.error('Error fetching categories:', error);
    res.status(500).json({ error: 'Failed to fetch categories' });
  }
});

// ============================================
// POST /stores/:storeId/categories
// Create a new category
// ============================================
router.post('/stores/:storeId/categories', async (req, res) => {
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

    const [result] = await db.query(query, [storeId, name, displayName]);

    res.json({
      data: {
        id: result.insertId,
        store_id: storeId,
        name,
        display_name: displayName,
        created_at: new Date(),
        updated_at: new Date(),
      },
    });
  } catch (error) {
    console.error('Error creating category:', error);
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
router.delete('/stores/:storeId/categories/:categoryId', async (req, res) => {
  const { storeId, categoryId } = req.params;

  try {
    const connection = await db.getConnection();
    await connection.beginTransaction();

    try {
      // تحديث جميع المنتجات في هذه الفئة (حذف الربط)
      await connection.query(
        'UPDATE products SET category_id = NULL WHERE category_id = ?',
        [categoryId]
      );

      // حذف الفئة
      await connection.query(
        'DELETE FROM categories WHERE id = ? AND store_id = ?',
        [categoryId, storeId]
      );

      await connection.commit();
      res.json({ success: true });
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  } catch (error) {
    console.error('Error deleting category:', error);
    res.status(500).json({ error: 'Failed to delete category' });
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

    const [products] = await db.query(query, [categoryId]);
    res.json({ data: products });
  } catch (error) {
    console.error('Error fetching category products:', error);
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
      await db.query(
        'UPDATE products SET category_id = NULL WHERE id = ?',
        [productId]
      );
    } else {
      // Assign to category
      await db.query(
        'UPDATE products SET category_id = ? WHERE id = ?',
        [category_id, productId]
      );
    }

    res.json({ success: true });
  } catch (error) {
    console.error('Error updating product category:', error);
    res.status(500).json({ error: 'Failed to update category' });
  }
});

// ============================================
// Helper function: Get display name from category name
// ============================================
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

  return categoryMap[categoryName.toLowerCase()] || categoryName;
}

module.exports = router;

// ============================================
// في server.js أضف:
// ============================================
// const categoryRoutes = require('./routes/categories');
// app.use('/api/v1', categoryRoutes);
