-- ============================================================
-- 01. USER PURCHASE SUMMARY (base table)
-- One row per customer. Feeds every other query/table in this project.
-- Answers: foundation for repeat-vs-one-time split, RFM inputs, revenue-at-risk.
-- ============================================================

WITH purchases AS (
  SELECT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS event_date,   -- event_date is a STRING in GA4's schema; must parse before date math
    TIMESTAMP_MICROS(event_timestamp) AS event_ts,
    ecommerce.transaction_id,
    ecommerce.purchase_revenue_in_usd
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
    AND ecommerce.transaction_id IS NOT NULL
),

user_purchase_summary AS (
  SELECT
    user_pseudo_id,
    COUNT(DISTINCT transaction_id) AS total_transactions,
    SUM(purchase_revenue_in_usd) AS total_revenue,
    MIN(event_ts) AS first_purchase_ts,
    MAX(event_ts) AS last_purchase_ts,
    DATE_DIFF(MAX(event_date), MIN(event_date), DAY) AS customer_lifespan_days,
    MAX(event_date) AS last_purchase_date
  FROM purchases
  GROUP BY user_pseudo_id
)

SELECT
  user_pseudo_id,
  total_transactions,
  ROUND(total_revenue, 2) AS total_revenue,
  first_purchase_ts,
  last_purchase_ts,
  customer_lifespan_days,
  CASE WHEN total_transactions >= 2 THEN 'repeat' ELSE 'one_time' END AS buyer_type,
  DATE_DIFF(DATE('2021-01-31'), last_purchase_date, DAY) AS days_since_last_purchase
FROM user_purchase_summary
ORDER BY total_revenue DESC;

-- Result: 4,400 total customers (3,898 one-time / 502 repeat)
