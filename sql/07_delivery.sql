-- sql/07_delivery.sql
-- Delivery and logistics analysis

-- 1. Estimated vs actual delivery gap distribution (histogram buckets)
SELECT
    CASE
        WHEN julianday(order_delivered_customer_date) - julianday(order_estimated_delivery_date) < -7 THEN 'More than 7 days early'
        WHEN julianday(order_delivered_customer_date) - julianday(order_estimated_delivery_date) BETWEEN -7 AND -3 THEN '3-7 days early'
        WHEN julianday(order_delivered_customer_date) - julianday(order_estimated_delivery_date) BETWEEN -3 AND 0 THEN '0-3 days early'
        WHEN julianday(order_delivered_customer_date) - julianday(order_estimated_delivery_date) BETWEEN 0 AND 3 THEN '0-3 days late'
        WHEN julianday(order_delivered_customer_date) - julianday(order_estimated_delivery_date) BETWEEN 3 AND 7 THEN '3-7 days late'
        ELSE 'More than 7 days late'
    END AS delivery_gap_bucket,
    COUNT(*) AS total_orders
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL
GROUP BY delivery_gap_bucket
ORDER BY 
    CASE delivery_gap_bucket
        WHEN 'More than 7 days early' THEN 1
        WHEN '3-7 days early' THEN 2
        WHEN '0-3 days early' THEN 3
        WHEN '0-3 days late' THEN 4
        WHEN '3-7 days late' THEN 5
        ELSE 6
    END;

-- 2. Avg delivery time by state
SELECT
    c.customer_state,
    COUNT(o.order_id) AS total_orders,
    ROUND(AVG(julianday(o.order_delivered_customer_date) - julianday(o.order_purchase_timestamp)), 2) AS avg_delivery_days
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY avg_delivery_days DESC;

-- 3. Freight as % of order value by state
WITH order_values AS (
    SELECT
        o.order_id,
        c.customer_state,
        SUM(oi.price) AS total_product_value,
        SUM(oi.freight_value) AS total_freight_value
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY o.order_id, c.customer_state
)
SELECT
    customer_state,
    COUNT(order_id) AS total_orders,
    ROUND(SUM(total_product_value), 2) AS sum_product_value,
    ROUND(SUM(total_freight_value), 2) AS sum_freight_value,
    ROUND(SUM(total_freight_value) / SUM(total_product_value + total_freight_value) * 100, 2) AS freight_pct_of_total
FROM order_values
GROUP BY customer_state
ORDER BY freight_pct_of_total DESC;

-- 4. Freight value distribution
SELECT
    CASE
        WHEN freight_value <= 10 THEN '0-10'
        WHEN freight_value <= 20 THEN '11-20'
        WHEN freight_value <= 30 THEN '21-30'
        WHEN freight_value <= 50 THEN '31-50'
        WHEN freight_value <= 100 THEN '51-100'
        ELSE '100+'
    END AS freight_bucket,
    COUNT(*) AS total_items
FROM order_items
GROUP BY freight_bucket
ORDER BY 
    CASE freight_bucket
        WHEN '0-10' THEN 1
        WHEN '11-20' THEN 2
        WHEN '21-30' THEN 3
        WHEN '31-50' THEN 4
        WHEN '51-100' THEN 5
        ELSE 6
    END;

-- 5. Carrier pickup time by seller state
SELECT
    s.seller_state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(AVG(julianday(o.order_delivered_carrier_date) - julianday(o.order_purchase_timestamp)), 2) AS avg_pickup_days
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN sellers s ON oi.seller_id = s.seller_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_carrier_date IS NOT NULL
GROUP BY s.seller_state
ORDER BY avg_pickup_days DESC;

-- 6. Delivery speed: days from carrier pickup to customer delivery, by customer state
SELECT
    c.customer_state,
    COUNT(o.order_id) AS total_orders,
    ROUND(AVG(julianday(o.order_delivered_customer_date) - julianday(o.order_delivered_carrier_date)), 2) AS avg_transit_days
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_delivered_carrier_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY avg_transit_days DESC;

-- 7. On-time delivery rate by month (trend)
SELECT
    strftime('%Y-%m', order_purchase_timestamp) AS order_month,
    COUNT(*) AS total_delivered_orders,
    SUM(CASE WHEN julianday(order_delivered_customer_date) <= julianday(order_estimated_delivery_date) THEN 1 ELSE 0 END) AS on_time_orders,
    ROUND(CAST(SUM(CASE WHEN julianday(order_delivered_customer_date) <= julianday(order_estimated_delivery_date) THEN 1 ELSE 0 END) AS REAL) / COUNT(*) * 100, 2) AS on_time_pct
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL
GROUP BY order_month
ORDER BY order_month;

-- 8. Orders by delivery status breakdown
SELECT
    order_status,
    COUNT(*) AS total_orders,
    ROUND(CAST(COUNT(*) AS REAL) / (SELECT COUNT(*) FROM orders) * 100, 2) AS pct_of_total
FROM orders
GROUP BY order_status
ORDER BY total_orders DESC;
