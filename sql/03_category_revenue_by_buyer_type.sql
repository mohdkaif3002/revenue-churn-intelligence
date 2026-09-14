-- ============================================================
-- 03. CATEGORY REVENUE BY BUYER TYPE
-- Answers: which product categories bring high-value repeat customers
-- vs one-and-done buyers?
--
-- Note: items is a repeated/nested field in GA4's schema — a single
-- purchase event can contain multiple line items, so UNNEST(items) is
-- required to get category-level revenue.
-- ============================================================

WITH purchase_events AS (
  SELECT
    user_pseudo_id,
    ecommerce.transaction_id,
    item.item_category,
    item.item_revenue_in_usd
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
    UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
    AND ecommerce.transaction_id IS NOT NULL
)

SELECT
  ups.buyer_type,
  pe.item_category,
  COUNT(DISTINCT pe.user_pseudo_id) AS num_customers,
  ROUND(SUM(pe.item_revenue_in_usd), 2) AS category_revenue
FROM purchase_events pe
JOIN `revenue-churn-analysis.ga4_analysis.user_purchase_summary` ups
  ON pe.user_pseudo_id = ups.user_pseudo_id
GROUP BY ups.buyer_type, pe.item_category
ORDER BY ups.buyer_type, category_revenue DESC;

-- Insight (computed post-query, revenue ÷ customers per category):
-- Apparel and Bags show the strongest repeat-customer spend multiplier
-- (~1.9x and ~2.2x respectively) — repeat buyers spend nearly 2x more
-- per person in these categories than one-time buyers do.
--
-- Data quality note: a "(not set)" category appears with NULL revenue —
-- a GA4 line-item attribution gap in the source data, not a query bug.
