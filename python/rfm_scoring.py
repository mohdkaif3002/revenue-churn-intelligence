"""
Revenue & Churn Intelligence — Rule-Based RFM Scoring
Run in Google Colab, connected to BigQuery.

Deliberately rule-based (no classifier/model training) — this is meant to
read as Data Analyst work, not Data Scientist work. Every customer is
sorted into a segment using simple, explainable if/else logic instead of
a trained model with probabilities.
"""

from google.colab import auth
auth.authenticate_user()

from google.cloud import bigquery
import pandas as pd

client = bigquery.Client(project='revenue-churn-analysis')

query = '''
SELECT *
FROM `revenue-churn-analysis.ga4_analysis.user_purchase_summary`
'''
df = client.query(query).to_dataframe()
# Result: (4400, 8)

# ------------------------------------------------------------------
# Score each customer 1-5 on Recency, Frequency, Monetary
# ------------------------------------------------------------------

# Recency: LOWER days_since_last_purchase = better, so labels are reversed
# (5 = most recently active). qcut splits into 5 equal-sized quintiles.
df['R_score'] = pd.qcut(df['days_since_last_purchase'], 5, labels=[5, 4, 3, 2, 1]).astype(int)

# Frequency: higher total_transactions = better. Many customers tie at
# exactly 1 transaction (3,898 of them), and qcut needs unique bin edges
# to split cleanly — .rank(method='first') breaks ties by giving each
# customer a unique position, letting qcut proceed without erroring.
df['F_score'] = pd.qcut(df['total_transactions'].rank(method='first'), 5, labels=[1, 2, 3, 4, 5]).astype(int)

# Monetary: higher total_revenue = better, straightforward quintiles
df['M_score'] = pd.qcut(df['total_revenue'], 5, labels=[1, 2, 3, 4, 5]).astype(int)

df['RFM_score'] = df['R_score'].astype(str) + df['F_score'].astype(str) + df['M_score'].astype(str)

# ------------------------------------------------------------------
# Translate the 3 scores into a plain-English segment label.
#
# Rule order matters: Python checks top-to-bottom and stops at the
# first match. "At Risk - High Value" is deliberately checked BEFORE
# plain "At Risk" — a customer with low recency but historically high
# frequency/spend is the more urgent, more specific case and should win
# the label, not the generic one.
#
# Debugging note: the first version of this function left a gap for
# customers with high recency + high frequency but MEDIUM monetary
# (r>=4, f>=4, m=3) — they matched nothing and fell into a lazy "Other"
# catch-all, which became the single BIGGEST segment (997 of 4,400).
# Adding the explicit "Loyal Low-Spender" rule below closed that gap;
# after the fix, "Other" dropped to exactly 0 — every customer is now
# covered by an intentional rule.
# ------------------------------------------------------------------

def rfm_segment(row):
    r, f, m = row['R_score'], row['F_score'], row['M_score']

    if r >= 4 and f >= 4 and m >= 4:
        return 'Champion'
    elif r >= 4 and f >= 4 and m < 4:
        return 'Loyal Low-Spender'
    elif r >= 4 and f == 3:
        return 'Promising'
    elif r >= 4 and f <= 2:
        return 'New Customer'
    elif r <= 2 and f >= 4 and m >= 4:
        return 'At Risk - High Value'
    elif r <= 2 and f >= 3:
        return 'At Risk'
    elif r <= 2 and f <= 2:
        return 'Lost'
    elif r == 3:
        return 'Needs Attention'
    else:
        return 'Other'   # should be unreachable — verified 0 rows land here

df['segment'] = df.apply(rfm_segment, axis=1)

# Final segment counts (verified: sums to exactly 4,400, zero in "Other"):
#   Needs Attention        : 884
#   At Risk                : 815
#   Lost                   : 781
#   Loyal Low-Spender      : 689
#   New Customer           : 630
#   Promising              : 308
#   Champion               : 179
#   At Risk - High Value   : 114

# ------------------------------------------------------------------
# Push the scored table back to BigQuery so Excel/Power BI can use it
# ------------------------------------------------------------------

table_id = 'revenue-churn-analysis.ga4_analysis.rfm_segments'
job = client.load_table_from_dataframe(df, table_id)
job.result()
print(f"Loaded {job.output_rows} rows into {table_id}")
