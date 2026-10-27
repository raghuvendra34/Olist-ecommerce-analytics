-- sql/05_reviews.sql
-- Review driver analysis - Key insights into customer satisfaction

-- 1 & 2: Calculate delivery delay and create buckets
WITH delivery_stats AS (
    SELECT
        o.order_id,
        r.review_score,
        r.review_comment_message,
        -- Calculate delay in days
        julianday(o.order_delivered_customer_date) - julianday(o.order_estimated_delivery_date) AS delivery_delay_days,
        CASE
            WHEN julianday(o.order_delivered_customer_date) - julianday(o.order_estimated_delivery_date) < -3 THEN 'Early (>3 days)'
            WHEN julianday(o.order_delivered_customer_date) - julianday(o.order_estimated_delivery_date) BETWEEN -3 AND -1 THEN 'Early (1-3 days)'
            WHEN julianday(o.order_delivered_customer_date) - julianday(o.order_estimated_delivery_date) >= -1 AND julianday(o.order_delivered_customer_date) - julianday(o.order_estimated_delivery_date) <= 0 THEN 'On Time'
            WHEN julianday(o.order_delivered_customer_date) - julianday(o.order_estimated_delivery_date) > 0 AND julianday(o.order_delivered_customer_date) - julianday(o.order_estimated_delivery_date) <= 3 THEN 'Late (1-3 days)'
            WHEN julianday(o.order_delivered_customer_date) - julianday(o.order_estimated_delivery_date) > 3 AND julianday(o.order_delivered_customer_date) - julianday(o.order_estimated_delivery_date) <= 7 THEN 'Late (4-7 days)'
            ELSE 'Late (7+ days)'
        END AS delay_bucket
    FROM orders o
    JOIN order_reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
)

-- 3. Avg review score by delay bucket
SELECT
    delay_bucket,
    COUNT(*) AS total_reviews,
    ROUND(AVG(review_score), 2) AS avg_review_score
FROM delivery_stats
GROUP BY delay_bucket
ORDER BY 
    CASE delay_bucket
        WHEN 'Early (>3 days)' THEN 1
        WHEN 'Early (1-3 days)' THEN 2
        WHEN 'On Time' THEN 3
        WHEN 'Late (1-3 days)' THEN 4
        WHEN 'Late (4-7 days)' THEN 5
        WHEN 'Late (7+ days)' THEN 6
    END;

-- 4. Count and % of 1-star reviews by delay bucket
WITH delivery_stats AS (
    SELECT
        o.order_id,
        r.review_score,
        r.review_comment_message,
        julianday(o.order_delivered_customer_date) - julianday(o.order_estimated_delivery_date) AS delivery_delay_days,
        CASE
            WHEN julianday(o.order_delivered_customer_date) - julianday(o.order_estimated_delivery_date) < -3 THEN 'Early (>3 days)'
            WHEN julianday(o.order_delivered_customer_date) - julianday(o.order_estimated_delivery_date) BETWEEN -3 AND -1 THEN 'Early (1-3 days)'
            WHEN julianday(o.order_delivered_customer_date) - julianday(o.order_estimated_delivery_date) >= -1 AND julianday(o.order_delivered_customer_date) - julianday(o.order_estimated_delivery_date) <= 0 THEN 'On Time'
            WHEN julianday(o.order_delivered_customer_date) - julianday(o.order_estimated_delivery_date) > 0 AND julianday(o.order_delivered_customer_date) - julianday(o.order_estimated_delivery_date) <= 3 THEN 'Late (1-3 days)'
            WHEN julianday(o.order_delivered_customer_date) - julianday(o.order_estimated_delivery_date) > 3 AND julianday(o.order_delivered_customer_date) - julianday(o.order_estimated_delivery_date) <= 7 THEN 'Late (4-7 days)'
            ELSE 'Late (7+ days)'
        END AS delay_bucket
    FROM orders o
    JOIN order_reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
)
SELECT
    delay_bucket,
    COUNT(*) AS total_reviews,
    SUM(CASE WHEN review_score = 1 THEN 1 ELSE 0 END) AS one_star_reviews,
    ROUND(CAST(SUM(CASE WHEN review_score = 1 THEN 1 ELSE 0 END) AS REAL) / COUNT(*) * 100, 2) AS one_star_pct
FROM delivery_stats
GROUP BY delay_bucket
ORDER BY 
    CASE delay_bucket
        WHEN 'Early (>3 days)' THEN 1
        WHEN 'Early (1-3 days)' THEN 2
        WHEN 'On Time' THEN 3
        WHEN 'Late (1-3 days)' THEN 4
        WHEN 'Late (4-7 days)' THEN 5
        WHEN 'Late (7+ days)' THEN 6
    END;

-- 5. Freight cost vs review score
WITH freight_stats AS (
    SELECT
        r.review_score,
        oi.freight_value,
        NTILE(4) OVER (ORDER BY oi.freight_value) AS freight_quartile
    FROM orders o
    JOIN order_reviews r ON o.order_id = r.order_id
    JOIN order_items oi ON o.order_id = oi.order_id
)
SELECT
    freight_quartile,
    ROUND(MIN(freight_value), 2) AS min_freight,
    ROUND(MAX(freight_value), 2) AS max_freight,
    COUNT(*) AS total_reviews,
    ROUND(AVG(review_score), 2) AS avg_review_score
FROM freight_stats
GROUP BY freight_quartile
ORDER BY freight_quartile;

-- 6. Reviews WITH comments vs WITHOUT comments
SELECT
    CASE 
        WHEN review_comment_message IS NOT NULL AND review_comment_message != '' THEN 'With Comment'
        ELSE 'Without Comment'
    END AS comment_status,
    COUNT(*) AS total_reviews,
    ROUND(AVG(review_score), 2) AS avg_review_score
FROM order_reviews
GROUP BY comment_status;

-- 7. Review score distribution (1-5 histogram)
SELECT
    review_score,
    COUNT(*) AS total_reviews,
    ROUND(CAST(COUNT(*) AS REAL) / (SELECT COUNT(*) FROM order_reviews) * 100, 2) AS pct_of_total
FROM order_reviews
GROUP BY review_score
ORDER BY review_score;

-- 8. Avg review score by product category (top 20)
SELECT
    t.product_category_name_english AS category_name,
    COUNT(r.review_id) AS total_reviews,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM order_reviews r
JOIN order_items oi ON r.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
JOIN product_category_name_translation t ON p.product_category_name = t.product_category_name
GROUP BY category_name
ORDER BY total_reviews DESC
LIMIT 20;

-- 9. Monthly avg review score trend
SELECT
    strftime('%Y-%m', o.order_purchase_timestamp) AS purchase_month,
    COUNT(r.review_id) AS total_reviews,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY purchase_month
ORDER BY purchase_month;
