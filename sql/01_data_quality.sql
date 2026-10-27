-- 01_data_quality.sql: Data Quality Checks for Olist Dataset

-- 1. Orphan order_items (order_id not in orders)
-- Checks for referential integrity violations where order_items reference non-existent orders.
SELECT COUNT(*) AS orphan_order_items
FROM order_items
WHERE order_id NOT IN (SELECT order_id FROM orders);

-- 2. Orphan order_items (product_id not in products)
-- Checks for referential integrity violations where order_items reference non-existent products.
SELECT COUNT(*) AS orphan_products_in_items
FROM order_items
WHERE product_id NOT IN (SELECT product_id FROM products);

-- 3. Orphan order_items (seller_id not in sellers)
-- Checks for referential integrity violations where order_items reference non-existent sellers.
SELECT COUNT(*) AS orphan_sellers_in_items
FROM order_items
WHERE seller_id NOT IN (SELECT seller_id FROM sellers);

-- 4. Orders with null delivery dates where status='delivered'
-- Validates consistency: delivered orders must have a delivery date.
SELECT COUNT(*) AS missing_delivery_date
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;

-- 5. Negative or zero prices in order_items
-- Validates business rules: product prices should be positive.
SELECT COUNT(*) AS invalid_prices
FROM order_items
WHERE price <= 0;

-- 6. Negative or zero freight values
-- Validates business rules: freight shouldn't be negative, though zero could be free shipping.
SELECT COUNT(*) AS negative_freight
FROM order_items
WHERE freight_value < 0;

-- 7. Duplicate order_ids in orders
-- Ensures primary key uniqueness in orders table.
SELECT order_id, COUNT(*)
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;

-- 8. Orders with purchase_timestamp after delivered date
-- Checks logical timeline progression: cannot deliver before purchase.
SELECT COUNT(*) AS illogical_timestamps
FROM orders
WHERE order_purchase_timestamp > order_delivered_customer_date;

-- 9. Review scores outside 1-5 range
-- Validates that review scores are strictly between 1 and 5.
SELECT COUNT(*) AS invalid_review_scores
FROM order_reviews
WHERE review_score < 1 OR review_score > 5;

-- 10. Summary counts table: total rows per table
-- Provides a high-level overview of dataset volume.
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL
SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL
SELECT 'geolocation', COUNT(*) FROM geolocation
UNION ALL
SELECT 'product_category_name_translation', COUNT(*) FROM product_category_name_translation;
