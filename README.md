# Olist E-Commerce Analytics

**End-to-end analytics on 100K+ Brazilian e-commerce orders — SQL analysis, RFM segmentation, cohort retention, and interactive Streamlit dashboard**

![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-4479A1?style=for-the-badge&logo=postgresql&logoColor=white)
![Streamlit](https://img.shields.io/badge/Streamlit-FF4B4B?style=for-the-badge&logo=streamlit&logoColor=white)
![SQLite](https://img.shields.io/badge/SQLite-003B57?style=for-the-badge&logo=sqlite&logoColor=white)

## Overview
This project provides an end-to-end data analytics pipeline and dashboard for the Olist Brazilian E-Commerce dataset. It covers data quality checks, revenue trend analysis, customer segmentation (RFM), cohort retention, and identifying key drivers for customer satisfaction and delivery performance.

**Dataset:** Olist Brazilian E-Commerce (Kaggle) — 100K orders, 2016–2018  
**Link to Kaggle dataset:** [https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)

## Key Findings
1. **Late Delivery Drives 1-Star Reviews** — [TODO: Insert exact numbers from 05_reviews.sql, e.g., 'Orders delivered 7+ days late had avg review score of X.X vs Y.Y for on-time']
   - **Recommendation:** Implement seller SLA penalties for late shipments; show honest ETAs at checkout
2. **Revenue Concentrated in Top Sellers** — [TODO: Insert numbers from 06_sellers.sql, e.g., 'Top 10% of sellers drive X% of revenue']
   - **Recommendation:** Build seller quality scorecard; diversify seller base
3. **RFM Segments Reveal Retention Opportunity** — [TODO: Insert numbers from 03_rfm.sql, e.g., 'X% of customers are At Risk or Lost, representing $Y in past revenue']
   - **Recommendation:** Targeted retention campaigns for At-Risk segment; loyalty program for Champions

## Project Structure
```
olist-ecommerce-analytics/
├── data/                  # Kaggle CSVs (not tracked)
├── sql/
│   ├── schema.sql         # Database schema (9 tables)
│   ├── 01_data_quality.sql
│   ├── 02_revenue.sql
│   ├── 03_rfm.sql
│   ├── 04_cohort_retention.sql
│   ├── 05_reviews.sql
│   ├── 06_sellers.sql
│   └── 07_delivery.sql
├── scripts/
│   ├── load_data.py       # CSV → SQLite loader
│   └── run_analysis.py    # SQL runner with formatted output
├── dashboard/
│   └── app.py             # 5-page Streamlit dashboard
├── notebooks/
│   └── eda.ipynb          # Exploratory data analysis
├── olist.db               # SQLite database (generated)
└── README.md
```

## Setup & Usage
1. Clone the repo
2. Download data from Kaggle into `data/`
3. Install dependencies: `pip install pandas streamlit plotly tabulate`
4. Load data: `python scripts/load_data.py`
5. Run analysis: `python scripts/run_analysis.py sql/05_reviews.sql`
6. Launch dashboard: `streamlit run dashboard/app.py`

## Analysis Deep Dives
Brief description of each SQL file and what business question it answers:
- **01 Data quality audit:** Identifies missing values, duplicates, and anomalies in the raw dataset.
- **02 Revenue trends and drivers:** Analyzes monthly revenue, average order value, and top product categories.
- **03 Customer segmentation (RFM):** Classifies customers based on Recency, Frequency, and Monetary value.
- **04 Cohort retention analysis:** Tracks user retention rates over time based on their first purchase month.
- **05 Review score drivers:** Investigates the impact of delivery times, product quality, and other factors on customer reviews.
- **06 Seller performance scorecard:** Evaluates top sellers by revenue, volume, and customer satisfaction.
- **07 Delivery and logistics economics:** Analyzes freight costs, delivery times vs. ETAs, and geographic bottlenecks.

## Tech Stack
- **SQL (SQLite):** Complex analytics queries with window functions
- **Python:** Data loading and automation
- **Streamlit + Plotly:** Interactive dashboard
- **Pandas:** Data manipulation

## Resume Bullet Points
- Analyzed 100K+ e-commerce orders using SQL window functions (LAG, NTILE, cumulative SUM); identified that delivery delays >7 days drove 1-star reviews, leading to recommended seller SLA framework
- Built RFM customer segmentation identifying X Champions and Y At-Risk customers; proposed targeted retention campaigns
- Developed 5-page Streamlit dashboard with Plotly visualizations for executive stakeholder review
