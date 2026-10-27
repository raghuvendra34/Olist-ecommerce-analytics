-- sql/06_sellers.sql
-- Seller scorecard and performance analysis

-- 1 & 2. Revenue concentration: what % do top 10% sellers drive?
WITH seller_metrics AS (
    SELECT
        s.seller_id,
        SUM(oi.price + oi.freight_value) AS total_revenue,
        COUNT(DISTINCT o.order_id) AS order_count,
        AVG(r.review_score) AS avg_review_score,
        AVG(julianday(o.order_delivered_carrier_date) - julianday(o.order_purchase_timestamp)) AS avg_fulfillment_days,
        COUNT(DISTINCT o.customer_id) AS unique_customers
    FROM sellers s
    JOIN order_items oi ON s.seller_id = oi.seller_id
    JOIN orders o ON oi.order_id = o.order_id
    LEFT JOIN order_reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY s.seller_id
),
ranked_sellers AS (
    SELECT
        seller_id,
        total_revenue,
        PERCENT_RANK() OVER (ORDER BY total_revenue DESC) AS seller_percentile,
        SUM(total_revenue) OVER (ORDER BY total_revenue DESC) AS cumulative_revenue,
        SUM(total_revenue) OVER () AS total_platform_revenue
    FROM seller_metrics
)
SELECT
    CASE
        WHEN seller_percentile <= 0.10 THEN 'Top 10%'
        WHEN seller_percentile <= 0.20 THEN '11-20%'
        WHEN seller_percentile <= 0.50 THEN '21-50%'
        ELSE 'Bottom 50%'
    END AS seller_tier,
    COUNT(seller_id) AS seller_count,
    ROUND(SUM(total_revenue), 2) AS tier_revenue,
    ROUND(SUM(total_revenue) / MAX(total_platform_revenue) * 100, 2) AS pct_of_total_revenue
FROM ranked_sellers
GROUP BY seller_tier
ORDER BY 
    CASE seller_tier
        WHEN 'Top 10%' THEN 1
        WHEN '11-20%' THEN 2
        WHEN '21-50%' THEN 3
        ELSE 4
    END;

-- 3. Top 20 sellers leaderboard
WITH seller_metrics AS (
    SELECT
        s.seller_id,
        SUM(oi.price + oi.freight_value) AS total_revenue,
        COUNT(DISTINCT o.order_id) AS order_count,
        AVG(r.review_score) AS avg_review_score,
        AVG(julianday(o.order_delivered_carrier_date) - julianday(o.order_purchase_timestamp)) AS avg_fulfillment_days,
        COUNT(DISTINCT o.customer_id) AS unique_customers
    FROM sellers s
    JOIN order_items oi ON s.seller_id = oi.seller_id
    JOIN orders o ON oi.order_id = o.order_id
    LEFT JOIN order_reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY s.seller_id
)
SELECT
    seller_id,
    ROUND(total_revenue, 2) AS total_revenue,
    order_count,
    ROUND(avg_review_score, 2) AS avg_review_score,
    ROUND(avg_fulfillment_days, 2) AS avg_fulfillment_days
FROM seller_metrics
ORDER BY total_revenue DESC
LIMIT 20;

-- 4. Bottom 20 sellers by review score (min 10 orders)
WITH seller_metrics AS (
    SELECT
        s.seller_id,
        SUM(oi.price + oi.freight_value) AS total_revenue,
        COUNT(DISTINCT o.order_id) AS order_count,
        AVG(r.review_score) AS avg_review_score
    FROM sellers s
    JOIN order_items oi ON s.seller_id = oi.seller_id
    JOIN orders o ON oi.order_id = o.order_id
    LEFT JOIN order_reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY s.seller_id
)
SELECT
    seller_id,
    order_count,
    ROUND(avg_review_score, 2) AS avg_review_score,
    ROUND(total_revenue, 2) AS total_revenue
FROM seller_metrics
WHERE order_count >= 10
ORDER BY avg_review_score ASC
LIMIT 20;

-- 5. Seller fulfillment speed vs avg rating (binned)
WITH seller_metrics AS (
    SELECT
        s.seller_id,
        AVG(r.review_score) AS avg_review_score,
        AVG(julianday(o.order_delivered_carrier_date) - julianday(o.order_purchase_timestamp)) AS avg_fulfillment_days
    FROM sellers s
    JOIN order_items oi ON s.seller_id = oi.seller_id
    JOIN orders o ON oi.order_id = o.order_id
    LEFT JOIN order_reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY s.seller_id
)
SELECT
    CASE 
        WHEN avg_fulfillment_days <= 1 THEN '0-1 days'
        WHEN avg_fulfillment_days <= 2 THEN '1-2 days'
        WHEN avg_fulfillment_days <= 4 THEN '3-4 days'
        WHEN avg_fulfillment_days <= 7 THEN '5-7 days'
        ELSE '8+ days'
    END AS fulfillment_speed_bucket,
    COUNT(seller_id) AS seller_count,
    ROUND(AVG(avg_review_score), 2) AS overall_avg_score
FROM seller_metrics
WHERE avg_fulfillment_days IS NOT NULL
GROUP BY fulfillment_speed_bucket
ORDER BY 
    CASE fulfillment_speed_bucket
        WHEN '0-1 days' THEN 1
        WHEN '1-2 days' THEN 2
        WHEN '3-4 days' THEN 3
        WHEN '5-7 days' THEN 4
        ELSE 5
    END;

-- 6. Delist candidates: avg_score < 3 AND > 5 orders
WITH seller_metrics AS (
    SELECT
        s.seller_id,
        SUM(oi.price + oi.freight_value) AS total_revenue,
        COUNT(DISTINCT o.order_id) AS order_count,
        AVG(r.review_score) AS avg_review_score
    FROM sellers s
    JOIN order_items oi ON s.seller_id = oi.seller_id
    JOIN orders o ON oi.order_id = o.order_id
    LEFT JOIN order_reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY s.seller_id
)
SELECT
    seller_id,
    order_count,
    ROUND(avg_review_score, 2) AS avg_review_score,
    ROUND(total_revenue, 2) AS total_revenue
FROM seller_metrics
WHERE avg_review_score < 3 AND order_count > 5
ORDER BY avg_review_score ASC;

-- 7. Promote candidates: avg_score >= 4.5, > 20 orders, fast fulfillment
WITH seller_metrics AS (
    SELECT
        s.seller_id,
        SUM(oi.price + oi.freight_value) AS total_revenue,
        COUNT(DISTINCT o.order_id) AS order_count,
        AVG(r.review_score) AS avg_review_score,
        AVG(julianday(o.order_delivered_carrier_date) - julianday(o.order_purchase_timestamp)) AS avg_fulfillment_days
    FROM sellers s
    JOIN order_items oi ON s.seller_id = oi.seller_id
    JOIN orders o ON oi.order_id = o.order_id
    LEFT JOIN order_reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY s.seller_id
)
SELECT
    seller_id,
    order_count,
    ROUND(avg_review_score, 2) AS avg_review_score,
    ROUND(avg_fulfillment_days, 2) AS avg_fulfillment_days,
    ROUND(total_revenue, 2) AS total_revenue
FROM seller_metrics
WHERE avg_review_score >= 4.5 
  AND order_count > 20 
  AND avg_fulfillment_days < 3
ORDER BY total_revenue DESC;

-- 8. Seller state distribution
SELECT
    seller_state,
    COUNT(seller_id) AS total_sellers,
    ROUND(CAST(COUNT(seller_id) AS REAL) / (SELECT COUNT(*) FROM sellers) * 100, 2) AS pct_of_sellers
FROM sellers
GROUP BY seller_state
ORDER BY total_sellers DESC;
