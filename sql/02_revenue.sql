-- 02_revenue.sql: Revenue Analysis Queries

-- 1. Monthly revenue trend with MoM growth using LAG() window function
WITH monthly_revenue AS (
    SELECT 
        strftime('%Y-%m', o.order_purchase_timestamp) AS purchase_month,
        SUM(oi.price + oi.freight_value) AS revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY purchase_month
)
SELECT 
    purchase_month,
    revenue,
    LAG(revenue) OVER (ORDER BY purchase_month) AS prev_month_revenue,
    (revenue - LAG(revenue) OVER (ORDER BY purchase_month)) / LAG(revenue) OVER (ORDER BY purchase_month) * 100 AS mom_growth_pct
FROM monthly_revenue;

-- 2. Quarterly revenue summary
SELECT 
    strftime('%Y', o.order_purchase_timestamp) || '-Q' || 
    ((CAST(strftime('%m', o.order_purchase_timestamp) AS INTEGER) - 1) / 3 + 1) AS purchase_quarter,
    SUM(oi.price + oi.freight_value) AS revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY purchase_quarter
ORDER BY purchase_quarter;

-- 3. Top 20 categories by revenue
SELECT 
    COALESCE(pct.product_category_name_english, p.product_category_name, 'Unknown') AS category_name,
    SUM(oi.price + oi.freight_value) AS revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation pct ON p.product_category_name = pct.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY category_name
ORDER BY revenue DESC
LIMIT 20;

-- 4. Top 10 states by revenue
SELECT 
    c.customer_state,
    SUM(oi.price + oi.freight_value) AS revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY revenue DESC
LIMIT 10;

-- 5. AOV (Average Order Value) by payment_type
SELECT 
    op.payment_type,
    SUM(oi.price + oi.freight_value) / COUNT(DISTINCT o.order_id) AS avg_order_value
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN order_payments op ON o.order_id = op.order_id
WHERE o.order_status = 'delivered'
GROUP BY op.payment_type
ORDER BY avg_order_value DESC;

-- 6. Revenue by day-of-week
SELECT 
    CASE CAST(strftime('%w', o.order_purchase_timestamp) AS INTEGER)
        WHEN 0 THEN 'Sunday'
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END AS day_of_week,
    SUM(oi.price + oi.freight_value) AS revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY strftime('%w', o.order_purchase_timestamp)
ORDER BY strftime('%w', o.order_purchase_timestamp);

-- 7. Cumulative revenue over time using SUM() OVER()
WITH daily_revenue AS (
    SELECT 
        strftime('%Y-%m-%d', o.order_purchase_timestamp) AS purchase_date,
        SUM(oi.price + oi.freight_value) AS revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY purchase_date
)
SELECT 
    purchase_date,
    revenue,
    SUM(revenue) OVER (ORDER BY purchase_date) AS cumulative_revenue
FROM daily_revenue;

-- 8. Payment type distribution (count and value)
SELECT 
    op.payment_type,
    COUNT(op.order_id) AS payment_count,
    SUM(op.payment_value) AS total_payment_value
FROM order_payments op
JOIN orders o ON op.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY op.payment_type
ORDER BY total_payment_value DESC;
