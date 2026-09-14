-- ============================================================
-- 06. REVENUE AT RISK
-- Answers: estimated revenue at risk from the churn-prone segment.
--
-- The 30-day threshold below is NOT an arbitrary round number — it is
-- derived directly from 02_retention_dropoff_summary.sql, which found
-- that 91% of repeat buyers who ever return do so within 30 days. Being
-- silent past that point is a genuine behavioral deviation, not just
-- "hasn't gotten around to it yet."
-- ============================================================

SELECT
  CASE
    WHEN days_since_last_purchase > 60 THEN 'high_risk_60plus_days_silent'
    WHEN days_since_last_purchase > 30 THEN 'moderate_risk_30_60_days_silent'
    ELSE 'active_recent_purchaser'
  END AS risk_segment,
  COUNT(*) AS num_customers,
  ROUND(SUM(total_revenue), 2) AS historical_revenue,
  ROUND(AVG(total_revenue), 2) AS avg_revenue_per_customer
FROM `revenue-churn-analysis.ga4_analysis.user_purchase_summary`
WHERE buyer_type = 'repeat'
GROUP BY risk_segment
ORDER BY risk_segment;

-- Result:
--   active_recent_purchaser         : 110 customers, $14,339
--   moderate_risk_30_60_days_silent : 282 customers, $55,527
--   high_risk_60plus_days_silent    : 110 customers, $21,467
--
-- Headline: $76,994 (moderate + high risk combined) = 84% of all
-- repeat-buyer revenue sits in customers silent 30+ days.
--
-- Caveat worth stating explicitly: "active_recent_purchaser" has the
-- LOWEST avg revenue/customer ($130) — not because they're worse
-- customers, but because they purchased near the end of the 3-month
-- data window and have had less time to accumulate a 2nd/3rd
-- transaction before the cutoff. A window-length artifact, not a real
-- behavioral difference.
