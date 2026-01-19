-- SQL Migration: Category Management System
-- Run these queries to set up the category system

USE yshop_db;

-- ============================================
-- 1. Create categories table
-- ============================================
CREATE TABLE IF NOT EXISTS categories (
    id INT PRIMARY KEY AUTO_INCREMENT,
    store_id INT NOT NULL,
    name VARCHAR(50) NOT NULL UNIQUE,
    display_name VARCHAR(100) NOT NULL,
    icon VARCHAR(10),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE,
    INDEX idx_store_categories (store_id, created_at)
);

-- ============================================
-- 2. Add category_id column to products table
-- ============================================
ALTER TABLE products 
ADD COLUMN category_id INT DEFAULT NULL,
ADD FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL,
ADD INDEX idx_product_category (category_id);

-- ============================================
-- 3. Verify store_type column exists
-- ============================================
-- If not, add it:
-- ALTER TABLE stores ADD COLUMN store_type VARCHAR(50) DEFAULT 'general';

-- ============================================
-- 4. Sample data (for testing)
-- ============================================
-- Uncomment to insert sample categories

-- INSERT INTO categories (store_id, name, display_name) VALUES
-- (1, 'fruits', 'Fruits 🍎'),
-- (1, 'vegetables', 'Vegetables 🥕'),
-- (1, 'beverages', 'Beverages 🥤'),
-- (1, 'meat', 'Meat 🥩'),
-- (1, 'chicken', 'Chicken 🍗'),
-- (1, 'bakery', 'Bakery 🍞'),
-- (1, 'canned_goods', 'Canned Goods 🥫'),
-- (1, 'cleaning', 'Cleaning Supplies 🧹'),
-- (1, 'dairy', 'Dairy 🧀'),
-- (1, 'frozen', 'Frozen Foods ❄️'),
-- (1, 'snacks', 'Snacks 🍿'),
-- (1, 'condiments', 'Condiments 🧂');

-- ============================================
-- 5. Verification queries
-- ============================================

-- Check categories table
-- SELECT * FROM categories;

-- Check products with categories
-- SELECT p.id, p.name, c.display_name 
-- FROM products p 
-- LEFT JOIN categories c ON p.category_id = c.id;

-- Count products per category
-- SELECT c.display_name, COUNT(p.id) as product_count
-- FROM categories c
-- LEFT JOIN products p ON c.id = p.category_id
-- GROUP BY c.id;
