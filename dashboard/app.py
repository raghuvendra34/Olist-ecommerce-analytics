import streamlit as st
import sqlite3
import pandas as pd
import plotly.express as px
from pathlib import Path

# --- Configuration ---
DB_PATH = Path(__file__).resolve().parent.parent / "olist.db"
st.set_page_config(page_title='Olist Analytics', layout='wide')

# --- Helper Functions ---
@st.cache_data(ttl=600)
def load_data(query: str, params=()) -> pd.DataFrame:
    try:
        conn = sqlite3.connect(DB_PATH)
        df = pd.read_sql_query(query, conn, params=params)
        conn.close()
        return df
    except sqlite3.Error as e:
        st.error(f"Database error: {e}")
        return pd.DataFrame()

# --- Page Layout ---
st.sidebar.title("Navigation")
page = st.sidebar.radio("Go to", ["Overview", "Customers", "Sellers", "Logistics", "Reviews"])

# --- Page 1: Overview ---
if page == "Overview":
    st.title("E-commerce Overview")
    st.info("High-level KPIs and trends for Olist E-commerce")

    # KPIs
    kpi_query = """
    SELECT 
        SUM(p.payment_value) as total_revenue,
        COUNT(DISTINCT o.order_id) as total_orders,
        SUM(p.payment_value) / COUNT(DISTINCT o.order_id) as aov,
        AVG(r.review_score) as avg_review_score
    FROM orders o
    LEFT JOIN order_payments p ON o.order_id = p.order_id
    LEFT JOIN order_reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
    """
    kpi_df = load_data(kpi_query)
    
    if not kpi_df.empty:
        col1, col2, col3, col4 = st.columns(4)
        col1.metric("Total Revenue", f"R$ {kpi_df['total_revenue'].iloc[0]:,.2f}")
        col2.metric("Total Orders", f"{kpi_df['total_orders'].iloc[0]:,}")
        col3.metric("Average Order Value (AOV)", f"R$ {kpi_df['aov'].iloc[0]:.2f}")
        col4.metric("Avg Review Score", f"{kpi_df['avg_review_score'].iloc[0]:.2f} / 5.0")

    col1, col2 = st.columns(2)
    
    with col1:
        st.subheader("Monthly Revenue Trend")
        rev_query = """
        SELECT 
            strftime('%Y-%m', o.order_purchase_timestamp) as month,
            SUM(p.payment_value) as revenue
        FROM orders o
        JOIN order_payments p ON o.order_id = p.order_id
        WHERE o.order_status = 'delivered' AND o.order_purchase_timestamp IS NOT NULL
        GROUP BY month
        ORDER BY month
        """
        rev_df = load_data(rev_query)
        if not rev_df.empty:
            fig = px.line(rev_df, x='month', y='revenue', title='Revenue over Time')
            st.plotly_chart(fig, use_container_width=True)
            
    with col2:
        st.subheader("Payment Type Distribution")
        pay_query = """
        SELECT payment_type, COUNT(*) as count, SUM(payment_value) as total_value
        FROM order_payments
        GROUP BY payment_type
        ORDER BY total_value DESC
        """
        pay_df = load_data(pay_query)
        if not pay_df.empty:
            fig = px.pie(pay_df, names='payment_type', values='total_value', title='Revenue by Payment Type')
            st.plotly_chart(fig, use_container_width=True)
            
    st.subheader("Top 10 Categories by Revenue")
    cat_query = """
    SELECT 
        COALESCE(t.product_category_name_english, p.product_category_name) as category,
        SUM(oi.price) as revenue
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    LEFT JOIN product_category_name_translation t ON p.product_category_name = t.product_category_name
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY category
    ORDER BY revenue DESC
    LIMIT 10
    """
    cat_df = load_data(cat_query)
    if not cat_df.empty:
        fig = px.bar(cat_df, x='category', y='revenue', title='Top 10 Categories')
        st.plotly_chart(fig, use_container_width=True)

# --- Page 2: Customers ---
elif page == "Customers":
    st.title("Customer Analysis")
    st.info("Insights into customer behavior, segments, and retention.")
    
    st.subheader("RFM Segment Distribution")
    # Simplified RFM proxy for visualization: group by number of orders and avg value
    rfm_query = """
    WITH customer_metrics AS (
        SELECT 
            c.customer_unique_id,
            COUNT(DISTINCT o.order_id) as order_count,
            SUM(p.payment_value) as total_spent
        FROM customers c
        JOIN orders o ON c.customer_id = o.customer_id
        JOIN order_payments p ON o.order_id = p.order_id
        WHERE o.order_status = 'delivered'
        GROUP BY c.customer_unique_id
    )
    SELECT 
        CASE 
            WHEN order_count > 1 AND total_spent > 500 THEN 'VIP'
            WHEN order_count > 1 THEN 'Returning'
            WHEN total_spent > 500 THEN 'High Value New'
            ELSE 'Typical New'
        END as segment,
        COUNT(*) as customer_count,
        AVG(total_spent) as avg_spent
    FROM customer_metrics
    GROUP BY segment
    """
    rfm_df = load_data(rfm_query)
    if not rfm_df.empty:
        fig = px.treemap(rfm_df, path=['segment'], values='customer_count', 
                         color='avg_spent', title='Customer Segments (Size=Count, Color=Avg Spent)')
        st.plotly_chart(fig, use_container_width=True)
        st.dataframe(rfm_df)
        
    st.subheader("Cohort Retention (Proxy)")
    st.write("Monthly cohorts based on first purchase.")
    cohort_query = """
    WITH first_purchase AS (
        SELECT 
            c.customer_unique_id,
            MIN(strftime('%Y-%m', o.order_purchase_timestamp)) as cohort_month
        FROM customers c
        JOIN orders o ON c.customer_id = o.customer_id
        WHERE o.order_status = 'delivered'
        GROUP BY c.customer_unique_id
    ),
    purchases AS (
        SELECT 
            c.customer_unique_id,
            strftime('%Y-%m', o.order_purchase_timestamp) as purchase_month
        FROM customers c
        JOIN orders o ON c.customer_id = o.customer_id
        WHERE o.order_status = 'delivered'
    )
    SELECT 
        f.cohort_month,
        CAST((julianday(p.purchase_month || '-01') - julianday(f.cohort_month || '-01'))/30 AS INTEGER) as month_offset,
        COUNT(DISTINCT p.customer_unique_id) as active_customers
    FROM first_purchase f
    JOIN purchases p ON f.customer_unique_id = p.customer_unique_id
    GROUP BY f.cohort_month, month_offset
    HAVING cohort_month >= '2017-01'
    """
    cohort_df = load_data(cohort_query)
    if not cohort_df.empty:
        cohort_pivot = cohort_df.pivot(index='cohort_month', columns='month_offset', values='active_customers')
        # Normalize to percentage
        cohort_pct = cohort_pivot.divide(cohort_pivot[0], axis=0) * 100
        fig = px.imshow(cohort_pct, text_auto=".1f", aspect="auto", 
                        title="Cohort Retention (%)",
                        labels=dict(x="Months Since First Purchase", y="Cohort Month", color="Retention %"))
        st.plotly_chart(fig, use_container_width=True)

# --- Page 3: Sellers ---
elif page == "Sellers":
    st.title("Seller Performance")
    st.info("Analysis of seller revenue, fulfillment speed, and customer satisfaction.")
    
    st.subheader("Seller Leaderboard (Top 20)")
    seller_query = """
    SELECT 
        s.seller_id,
        SUM(oi.price) as revenue,
        COUNT(DISTINCT oi.order_id) as orders,
        AVG(r.review_score) as avg_review_score,
        AVG(julianday(o.order_delivered_carrier_date) - julianday(o.order_purchase_timestamp)) as avg_fulfillment_days
    FROM sellers s
    JOIN order_items oi ON s.seller_id = oi.seller_id
    JOIN orders o ON oi.order_id = o.order_id
    LEFT JOIN order_reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY s.seller_id
    HAVING orders > 10
    ORDER BY revenue DESC
    LIMIT 20
    """
    seller_df = load_data(seller_query)
    if not seller_df.empty:
        st.dataframe(seller_df)
        
    st.subheader("Fulfillment vs Satisfaction")
    scatter_query = """
    SELECT 
        s.seller_id,
        SUM(oi.price) as revenue,
        AVG(r.review_score) as avg_review_score,
        AVG(julianday(o.order_delivered_carrier_date) - julianday(o.order_purchase_timestamp)) as avg_fulfillment_days
    FROM sellers s
    JOIN order_items oi ON s.seller_id = oi.seller_id
    JOIN orders o ON oi.order_id = o.order_id
    JOIN order_reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY s.seller_id
    HAVING COUNT(DISTINCT oi.order_id) > 20
    """
    scatter_df = load_data(scatter_query)
    if not scatter_df.empty:
        # Filter outliers for better visualization
        scatter_df = scatter_df[(scatter_df['avg_fulfillment_days'] >= 0) & (scatter_df['avg_fulfillment_days'] <= 20)]
        fig = px.scatter(scatter_df, x='avg_fulfillment_days', y='avg_review_score', size='revenue',
                         hover_name='seller_id', title="Avg Fulfillment Days vs Review Score")
        st.plotly_chart(fig, use_container_width=True)

# --- Page 4: Logistics ---
elif page == "Logistics":
    st.title("Logistics & Delivery")
    st.info("Delivery performance and its impact on customer satisfaction.")
    
    st.subheader("Delivery Delay Impact on Reviews")
    st.success("Key Insight: Orders delivered late suffer a massive drop in review scores.")
    delay_query = """
    WITH delivery_data AS (
        SELECT 
            o.order_id,
            r.review_score,
            julianday(o.order_delivered_customer_date) - julianday(o.order_estimated_delivery_date) as delay_days
        FROM orders o
        JOIN order_reviews r ON o.order_id = r.order_id
        WHERE o.order_status = 'delivered' 
          AND o.order_delivered_customer_date IS NOT NULL
          AND o.order_estimated_delivery_date IS NOT NULL
    )
    SELECT 
        CASE 
            WHEN delay_days <= -5 THEN 'Early (>5 days)'
            WHEN delay_days <= 0 THEN 'On Time (0-5 days early)'
            WHEN delay_days <= 5 THEN 'Slightly Late (1-5 days)'
            WHEN delay_days <= 10 THEN 'Late (6-10 days)'
            ELSE 'Very Late (>10 days)'
        END as delay_bucket,
        AVG(review_score) as avg_score,
        COUNT(*) as order_count,
        CASE 
            WHEN delay_days <= -5 THEN 1
            WHEN delay_days <= 0 THEN 2
            WHEN delay_days <= 5 THEN 3
            WHEN delay_days <= 10 THEN 4
            ELSE 5
        END as sort_order
    FROM delivery_data
    GROUP BY delay_bucket, sort_order
    ORDER BY sort_order
    """
    delay_df = load_data(delay_query)
    if not delay_df.empty:
        fig = px.bar(delay_df, x='delay_bucket', y='avg_score', text_auto='.2f',
                     title="Avg Review Score by Delivery Delay Bucket")
        st.plotly_chart(fig, use_container_width=True)
        
    col1, col2 = st.columns(2)
    with col1:
        st.subheader("Delivery Time Distribution")
        time_query = """
        SELECT 
            julianday(order_delivered_customer_date) - julianday(order_purchase_timestamp) as delivery_days
        FROM orders
        WHERE order_status = 'delivered'
          AND order_delivered_customer_date IS NOT NULL
        """
        time_df = load_data(time_query)
        if not time_df.empty:
            time_df = time_df[(time_df['delivery_days'] >= 0) & (time_df['delivery_days'] <= 60)]
            fig = px.histogram(time_df, x='delivery_days', nbins=30, title="Delivery Days Distribution")
            st.plotly_chart(fig, use_container_width=True)

    with col2:
        st.subheader("Freight as % of Price by State")
        freight_query = """
        SELECT 
            c.customer_state as state,
            AVG(oi.freight_value / (oi.price + oi.freight_value) * 100) as freight_pct
        FROM order_items oi
        JOIN orders o ON oi.order_id = o.order_id
        JOIN customers c ON o.customer_id = c.customer_id
        WHERE o.order_status = 'delivered'
        GROUP BY state
        ORDER BY freight_pct DESC
        """
        freight_df = load_data(freight_query)
        if not freight_df.empty:
            fig = px.bar(freight_df, x='freight_pct', y='state', orientation='h', 
                         title="Avg Freight % of Total Cost by State")
            fig.update_layout(yaxis={'categoryorder':'total ascending'})
            st.plotly_chart(fig, use_container_width=True)

# --- Page 5: Reviews ---
elif page == "Reviews":
    st.title("Customer Reviews")
    st.info("Analysis of customer feedback and satisfaction.")
    
    col1, col2 = st.columns(2)
    with col1:
        st.subheader("Review Score Distribution")
        score_query = """
        SELECT review_score, COUNT(*) as count
        FROM order_reviews
        GROUP BY review_score
        ORDER BY review_score
        """
        score_df = load_data(score_query)
        if not score_df.empty:
            fig = px.bar(score_df, x='review_score', y='count', text_auto=True, 
                         title="Distribution of Review Scores (1-5)")
            st.plotly_chart(fig, use_container_width=True)

    with col2:
        st.subheader("Comment vs No Comment")
        comment_query = """
        SELECT 
            CASE 
                WHEN review_comment_message IS NOT NULL AND review_comment_message != '' THEN 'Has Comment'
                ELSE 'No Comment'
            END as comment_status,
            AVG(review_score) as avg_score,
            COUNT(*) as count
        FROM order_reviews
        GROUP BY comment_status
        """
        comment_df = load_data(comment_query)
        if not comment_df.empty:
            fig = px.bar(comment_df, x='comment_status', y='avg_score', text_auto='.2f',
                         title="Avg Score: Written Comment vs None")
            st.plotly_chart(fig, use_container_width=True)
            
    st.subheader("Top and Bottom Categories by Review Score")
    cat_score_query = """
    SELECT 
        COALESCE(t.product_category_name_english, p.product_category_name) as category,
        AVG(r.review_score) as avg_score,
        COUNT(r.review_id) as review_count
    FROM order_reviews r
    JOIN order_items oi ON r.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
    LEFT JOIN product_category_name_translation t ON p.product_category_name = t.product_category_name
    GROUP BY category
    HAVING review_count > 100
    ORDER BY avg_score DESC
    """
    cat_score_df = load_data(cat_score_query)
    if not cat_score_df.empty:
        col3, col4 = st.columns(2)
        with col3:
            st.write("Top 10 Categories")
            st.dataframe(cat_score_df.head(10))
        with col4:
            st.write("Bottom 10 Categories")
            st.dataframe(cat_score_df.tail(10).sort_values('avg_score'))