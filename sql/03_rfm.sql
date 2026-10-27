-- 03_rfm.sql: RFM Segmentation Analysis

-- 1. Calculate per customer_unique_id: Recency, Frequency, Monetary
WITH customer_rfm_base AS (
    SELECT 
        c.customer_unique_id,
        CAST(julianday('2018-10-01') - julianday(MAX(o.order_purchase_timestamp)) AS INTEGER) AS recency_days,
        COUNT(DISTINCT o.order_id) AS frequency_count,
        SUM(oi.price + oi.freight_value) AS monetary_value
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),

-- 2. Score each dimension using NTILE(5)
rfm_scores AS (
    SELECT 
        customer_unique_id,
        recency_days,
        frequency_count,
        monetary_value,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency_count ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary_value ASC) AS m_score
    FROM customer_rfm_base
),

-- 3. Create combined RFM score and 4. Segment customers
rfm_segments AS (
    SELECT 
        customer_unique_id,
        recency_days,
        frequency_count,
        monetary_value,
        r_score,
        f_score,
        m_score,
        CAST(r_score AS TEXT) || CAST(f_score AS TEXT) || CAST(m_score AS TEXT) AS rfm_score,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
            WHEN f_score >= 3 AND m_score >= 3 THEN 'Loyal'
            WHEN r_score >= 4 AND f_score <= 2 THEN 'Potential Loyalists'
            WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
            WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2 THEN 'Hibernating'
            WHEN r_score = 1 AND f_score = 1 THEN 'Lost'
            ELSE 'Other'
        END AS rfm_segment
    FROM rfm_scores
)

-- 5. Summary: count and avg monetary per segment
SELECT 
    rfm_segment,
    COUNT(*) AS customer_count,
    AVG(monetary_value) AS avg_monetary_value,
    -- 6. Revenue share by segment
    SUM(monetary_value) AS total_segment_revenue,
    SUM(monetary_value) / (SELECT SUM(monetary_value) FROM rfm_segments) * 100 AS revenue_share_pct
FROM rfm_segments
GROUP BY rfm_segment
ORDER BY total_segment_revenue DESC;
