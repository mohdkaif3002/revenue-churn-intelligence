-- ============================================================
-- 02. RETENTION DROP-OFF PATTERN (30/60/90-day windows)
-- Answers: at what point do users stop returning?
--
-- NOTE: this query went through 3 iterations before landing on the correct
-- logic. Documenting all 3 here because the debugging story matters:
--
-- Attempt 1 (WRONG): compared event_date (calendar date) with a plain '>'
-- between first and second purchase. BUG: two purchases made on the same
-- calendar day were invisible to the join (`>` on dates, not timestamps),
-- so same-day repeat purchases were silently excluded. Only captured
-- 327 of 502 known repeat buyers.
--
-- Attempt 2 (WRONG): switched to comparing raw event TIMESTAMPS instead of
-- dates. BUG: overcounted (771 vs expected 502) because GA4 can fire the
-- same 'purchase' event more than once for the same transaction_id (e.g.
-- a page reload double-logs the hit). Comparing raw events treated a
-- duplicate log of the SAME purchase as a second, separate purchase.
--
-- Attempt 3 (CORRECT, below): dedup to one row per transaction_id FIRST,
-- then rank each user's transactions chronologically and compare rank 1
-- to rank 2. This is the only version that reconciles exactly to 502.
-- ============================================================

WITH transactions AS (
  SELECT
    user_pseudo_id,
    ecommerce.transaction_id,
    MIN(TIMESTAMP_MICROS(event_timestamp)) AS transaction_ts
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
    AND ecommerce.transaction_id IS NOT NULL
  GROUP BY user_pseudo_id, ecommerce.transaction_id   -- dedup: one row per real transaction
),

ranked AS (
  SELECT
    user_pseudo_id,
    transaction_id,
    transaction_ts,
    ROW_NUMBER() OVER (PARTITION BY user_pseudo_id ORDER BY transaction_ts) AS txn_rank
  FROM transactions
),

first_txn AS (
  SELECT user_pseudo_id, transaction_ts AS first_purchase_ts FROM ranked WHERE txn_rank = 1
),

second_txn AS (
  SELECT user_pseudo_id, transaction_ts AS second_purchase_ts FROM ranked WHERE txn_rank = 2
)

SELECT
  CASE
    WHEN s.user_pseudo_id IS NULL THEN 'never_returned'
    WHEN TIMESTAMP_DIFF(s.second_purchase_ts, f.first_purchase_ts, DAY) <= 30 THEN 'returned_0_30'
    WHEN TIMESTAMP_DIFF(s.second_purchase_ts, f.first_purchase_ts, DAY) <= 60 THEN 'returned_31_60'
    WHEN TIMESTAMP_DIFF(s.second_purchase_ts, f.first_purchase_ts, DAY) <= 90 THEN 'returned_61_90'
    ELSE 'returned_90_plus'
  END AS status,
  COUNT(*) AS num_customers
FROM first_txn f
LEFT JOIN second_txn s USING (user_pseudo_id)
GROUP BY status
ORDER BY status;

-- Result (validated: sums to exactly 4,400):
--   never_returned    : 3,898  (88.6%)
--   returned_0_30     :   456
--   returned_31_60    :    44
--   returned_61_90    :     2
--
-- Insight: among the 502 who DO return, 91% do so within 30 days.
-- Almost no "slow burn" repeat pattern — re-engagement has to happen early.
