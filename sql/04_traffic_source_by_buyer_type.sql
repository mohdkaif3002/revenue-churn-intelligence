-- ============================================================
-- 04. TRAFFIC SOURCE BY BUYER TYPE
-- Answers: which traffic sources bring high-value repeat customers
-- vs one-and-done buyers?
--
-- Note: uses each user's FIRST session, not the purchase event's own
-- traffic_source field (which is frequently blank/null on purchase
-- events — GA4 attributes acquisition channel to session_start instead).
-- ============================================================

WITH first_session AS (
  SELECT
    user_pseudo_id,
    traffic_source.source AS source,
    traffic_source.medium AS medium,
    ROW_NUMBER() OVER (PARTITION BY user_pseudo_id ORDER BY event_timestamp) AS session_rank
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'session_start'
)

SELECT
  ups.buyer_type,
  fs.source,
  fs.medium,
  COUNT(DISTINCT ups.user_pseudo_id) AS num_customers,
  ROUND(SUM(ups.total_revenue), 2) AS total_revenue
FROM `revenue-churn-analysis.ga4_analysis.user_purchase_summary` ups
JOIN first_session fs
  ON ups.user_pseudo_id = fs.user_pseudo_id
  AND fs.session_rank = 1
GROUP BY ups.buyer_type, fs.source, fs.medium
ORDER BY ups.buyer_type, total_revenue DESC;

-- Insight (repeat rate = repeat customers ÷ total customers, per channel):
--   shop.googlemerchandisestore.com / referral -> 14.8% repeat rate (highest)
--   google / cpc                                -> 10.2% repeat rate but
--                                                   highest $/customer ($224)
--                                                   — big-ticket, one-off channel
--
-- Caveat: "(data deleted)" shows the highest apparent repeat rate (~20%),
-- but this is GA4's privacy-redaction bucket (EU consent-restricted users),
-- not an actionable channel — noted, not used in recommendations.
