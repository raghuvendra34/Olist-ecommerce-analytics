-- sql/04_cohort_retention.sql
-- Cohort retention analysis

-- 1. Find each customer's first purchase month (cohort_month)
WITH customer_cohort AS (
    SELECT
        c.customer_unique_id,
        MIN(strftime('%Y-%m', o.order_purchase_timestamp)) AS cohort_month
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
-- 2. For each subsequent order, calculate months_since_first
customer_activity AS (
    SELECT
        c.customer_unique_id,
        strftime('%Y-%m', o.order_purchase_timestamp) AS order_month
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id, strftime('%Y-%m', o.order_purchase_timestamp)
),
cohort_activity AS (
    SELECT
        cc.customer_unique_id,
        cc.cohort_month,
        ca.order_month,
        -- Calculate difference in months
        (CAST(strftime('%Y', ca.order_month || '-01') AS INTEGER) - CAST(strftime('%Y', cc.cohort_month || '-01') AS INTEGER)) * 12 +
        (CAST(strftime('%m', ca.order_month || '-01') AS INTEGER) - CAST(strftime('%m', cc.cohort_month || '-01') AS INTEGER)) AS months_since_first
    FROM customer_cohort cc
    JOIN customer_activity ca ON cc.customer_unique_id = ca.customer_unique_id
),
-- 3. Build a cohort retention matrix
cohort_size AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_unique_id) AS initial_customers
    FROM customer_cohort
    GROUP BY cohort_month
),
retention_matrix AS (
    SELECT
        ca.cohort_month,
        cs.initial_customers,
        SUM(CASE WHEN ca.months_since_first = 0 THEN 1 ELSE 0 END) AS month_0,
        SUM(CASE WHEN ca.months_since_first = 1 THEN 1 ELSE 0 END) AS month_1,
        SUM(CASE WHEN ca.months_since_first = 2 THEN 1 ELSE 0 END) AS month_2,
        SUM(CASE WHEN ca.months_since_first = 3 THEN 1 ELSE 0 END) AS month_3,
        SUM(CASE WHEN ca.months_since_first = 4 THEN 1 ELSE 0 END) AS month_4,
        SUM(CASE WHEN ca.months_since_first = 5 THEN 1 ELSE 0 END) AS month_5,
        SUM(CASE WHEN ca.months_since_first = 6 THEN 1 ELSE 0 END) AS month_6,
        SUM(CASE WHEN ca.months_since_first = 7 THEN 1 ELSE 0 END) AS month_7,
        SUM(CASE WHEN ca.months_since_first = 8 THEN 1 ELSE 0 END) AS month_8,
        SUM(CASE WHEN ca.months_since_first = 9 THEN 1 ELSE 0 END) AS month_9,
        SUM(CASE WHEN ca.months_since_first = 10 THEN 1 ELSE 0 END) AS month_10,
        SUM(CASE WHEN ca.months_since_first = 11 THEN 1 ELSE 0 END) AS month_11,
        SUM(CASE WHEN ca.months_since_first = 12 THEN 1 ELSE 0 END) AS month_12
    FROM cohort_activity ca
    JOIN cohort_size cs ON ca.cohort_month = cs.cohort_month
    GROUP BY ca.cohort_month, cs.initial_customers
)

-- 4. Calculate retention RATE: % of cohort still active at each month offset
SELECT
    cohort_month,
    initial_customers,
    ROUND(CAST(month_0 AS REAL) / initial_customers * 100, 2) AS month_0_pct,
    ROUND(CAST(month_1 AS REAL) / initial_customers * 100, 2) AS month_1_pct,
    ROUND(CAST(month_2 AS REAL) / initial_customers * 100, 2) AS month_2_pct,
    ROUND(CAST(month_3 AS REAL) / initial_customers * 100, 2) AS month_3_pct,
    ROUND(CAST(month_4 AS REAL) / initial_customers * 100, 2) AS month_4_pct,
    ROUND(CAST(month_5 AS REAL) / initial_customers * 100, 2) AS month_5_pct,
    ROUND(CAST(month_6 AS REAL) / initial_customers * 100, 2) AS month_6_pct,
    ROUND(CAST(month_7 AS REAL) / initial_customers * 100, 2) AS month_7_pct,
    ROUND(CAST(month_8 AS REAL) / initial_customers * 100, 2) AS month_8_pct,
    ROUND(CAST(month_9 AS REAL) / initial_customers * 100, 2) AS month_9_pct,
    ROUND(CAST(month_10 AS REAL) / initial_customers * 100, 2) AS month_10_pct,
    ROUND(CAST(month_11 AS REAL) / initial_customers * 100, 2) AS month_11_pct,
    ROUND(CAST(month_12 AS REAL) / initial_customers * 100, 2) AS month_12_pct
FROM retention_matrix
ORDER BY cohort_month;

-- 5. Summary: overall avg retention at each month offset
WITH customer_cohort_s AS (
    SELECT
        c.customer_unique_id,
        MIN(strftime('%Y-%m', o.order_purchase_timestamp)) AS cohort_month
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
customer_activity_s AS (
    SELECT
        c.customer_unique_id,
        strftime('%Y-%m', o.order_purchase_timestamp) AS order_month
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id, strftime('%Y-%m', o.order_purchase_timestamp)
),
cohort_activity_s AS (
    SELECT
        cc.customer_unique_id,
        cc.cohort_month,
        ca.order_month,
        (CAST(strftime('%Y', ca.order_month || '-01') AS INTEGER) - CAST(strftime('%Y', cc.cohort_month || '-01') AS INTEGER)) * 12 +
        (CAST(strftime('%m', ca.order_month || '-01') AS INTEGER) - CAST(strftime('%m', cc.cohort_month || '-01') AS INTEGER)) AS months_since_first
    FROM customer_cohort_s cc
    JOIN customer_activity_s ca ON cc.customer_unique_id = ca.customer_unique_id
),
summary_activity AS (
    SELECT
        months_since_first,
        COUNT(DISTINCT customer_unique_id) AS active_customers
    FROM cohort_activity_s
    GROUP BY months_since_first
),
total_initial AS (
    SELECT COUNT(DISTINCT customer_unique_id) AS total_customers FROM customer_cohort_s
)
SELECT
    sa.months_since_first,
    sa.active_customers,
    ROUND(CAST(sa.active_customers AS REAL) / ti.total_customers * 100, 2) AS retention_pct
FROM summary_activity sa
CROSS JOIN total_initial ti
WHERE sa.months_since_first <= 12
ORDER BY sa.months_since_first;
