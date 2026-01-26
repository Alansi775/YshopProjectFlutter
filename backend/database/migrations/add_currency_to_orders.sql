-- Add currency column to orders table
ALTER TABLE orders ADD COLUMN currency VARCHAR(3) DEFAULT 'USD' AFTER total_price;

-- Update existing orders to get currency from their store's products
UPDATE orders o
SET o.currency = (
  SELECT COALESCE(p.currency, 'USD')
  FROM products p
  WHERE p.store_id = o.store_id
  LIMIT 1
)
WHERE o.currency = 'USD';
