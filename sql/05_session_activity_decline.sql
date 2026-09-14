-- ============================================================
-- 05. LEADING CHURN INDICATORS
-- Answers: what leading indicators (before a customer is gone) can be
-- flagged — declining session frequency, cart abandonment?
-- ============================================================

-- ---- 5a. Cart abandonment rate by buyer type ----------------
-- Result: repeat 11.7% vs one-time 12.2% abandonment — NOT a meaningful
-- population-level differentiator. Documented as an honest null result
-- rather than forced into a false narrative. (Not saved as a BigQuery
-- table — no reusable output, just a documented finding.)

WITH checkout_events AS (
  SELECT
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    event_name,
    event_timestamp
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name IN ('begin_checkout', 'purchase')
),
session_outcomes AS (
  SELECT
    user_pseudo_id,
    session_id,
    LOGICAL_OR(event_name = 'begin_checkout') AS started_checkout,
    LOGICAL_OR(event_name = 'purchase') AS completed_purchase
  FROM checkout_events
  GROUP BY user_pseudo_id, session_id
)
SELECT
  ups.buyer_type,
  COUNTIF(so.started_checkout AND NOT so.completed_purchase) AS abandoned_sessions,
  COUNTIF(so.started_checkout AND so.completed_purchase) AS completed_sessions,
  ROUND(
    COUNTIF(so.started_checkout AND NOT so.completed_purchase) * 100.0 /
    NULLIF(COUNTIF(so.started_checkout), 0), 1
  ) AS abandonment_rate_pct
FROM session_outcomes so
JOIN `revenue-churn-analysis.ga4_analysis.user_purchase_summary` ups
  ON so.user_pseudo_id = ups.user_pseudo_id
WHERE so.started_checkout
GROUP BY ups.buyer_type;


-- ---- 5b. Declining session frequency (saved as session_activity_decline) ----
-- Splits the 3-month window into two halves and compares session counts.
-- This IS a strong leading indicator: 221 of 502 repeat buyers (44%) went
-- completely silent in the second half of the window.

WITH sessions AS (
  SELECT
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    PARSE_DATE('%Y%m%d', event_date) AS session_date
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'session_start'
),
period_counts AS (
  SELECT
    user_pseudo_id,
    COUNTIF(session_date BETWEEN '2020-11-01' AND '2020-12-15') AS sessions_early,
    COUNTIF(session_date BETWEEN '2020-12-16' AND '2021-01-31') AS sessions_late
  FROM sessions
  GROUP BY user_pseudo_id
)
SELECT
  ups.buyer_type,
  ROUND(AVG(pc.sessions_early), 2) AS avg_sessions_early_period,
  ROUND(AVG(pc.sessions_late), 2) AS avg_sessions_late_period,
  COUNTIF(pc.sessions_early > 0 AND pc.sessions_late = 0) AS went_silent_count
FROM period_counts pc
JOIN `revenue-churn-analysis.ga4_analysis.user_purchase_summary` ups
  ON pc.user_pseudo_id = ups.user_pseudo_id
GROUP BY ups.buyer_type;

-- Result:
--   one_time: avg 2.05 -> 1.25 sessions, 2,063 went silent
--   repeat:   avg 3.51 -> 1.85 sessions,   221 went silent (44% of all repeat buyers)
