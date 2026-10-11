# Revenue & Churn Intelligence

**Which customers drive repeat revenue, which are about to churn, and what should the business do about it?**
SQL (BigQuery) · Python (rule-based RFM) · Excel · Power BI, on real e-commerce data from the Google Merchandise Store.

![Dashboard](screenshots/Dashboard%20Screenshot.png)

## Result in 30 seconds

- Repeat buyers are **11.4%** of customers but bring **25.3%** of revenue (about **2.6x** the revenue per customer of one-time buyers).
- **88.6%** of first-time buyers never buy again. Of those who do, **91%** return within 30 days.
- **44%** of previously repeat buyers went silent in the second half of the window. **$76,994** (84% of repeat-buyer revenue) sits with customers silent 30+ days.

## Recommendations

1. **Make the second-purchase offer inside the first 30 days.** 91% of returning buyers come back within 30 days, so after that the chance is low.
2. **Push Apparel and Bags in post-purchase emails and cross-sell.** Repeat buyers spend ~1.9–2.2x more per person in these categories.
3. **Run a win-back campaign on the 221 repeat buyers who went silent.** This is where the $76,994 at risk sits.
4. **Use inactivity (recency), not cart abandonment, as the churn signal.** Cart abandonment was the same for repeat and one-time buyers (see below).

## Business Question

Which customer segments and products drive repeat revenue, and which are at risk of churning, and what should the business do about it?

## Dataset

[`bigquery-public-data.ga4_obfuscated_sample_ecommerce`](https://console.cloud.google.com/marketplace/product/obfuscated-ga4-data/obfuscated-ga4-ecommerce-data): real GA4 event export from the Google Merchandise Store, Nov 2020 – Jan 2021 (~3 months), 4,400 purchasing customers.

**Known limitations, stated upfront**
- GA4 uses `user_pseudo_id`, a device/cookie-based identifier, not a verified customer ID. A person using multiple devices may be counted as more than one customer.
- The window is only ~3 months. "Silent" means silent within the window, so some of these customers may still return later.

## Sub-Questions Answered

1. Repeat buyers vs. one-time buyers: how much revenue does each group represent?
2. Drop-off pattern: at what point do users stop returning (30/60/90-day windows)?
3. Which product categories / traffic sources bring high-value repeat customers vs. one-and-done buyers?
4. Leading indicators of churn (declining session frequency, cart abandonment, time-since-last-purchase)?
5. Estimated revenue at risk from the churn-prone segment?

## Tools & Why

| Tool | Role |
|---|---|
| BigQuery (SQL) | Segmentation, cohort, and retention queries against the raw GA4 event data |
| Python / Pandas (Colab) | Rule-based RFM (Recency-Frequency-Monetary) scoring. Rules are transparent and explainable to business stakeholders, so no black-box model was needed |
| Excel | Stakeholder-style summary workbook with live formulas |
| Power BI | Final 4-visual dashboard, one visual per key finding |

## Key Findings

- Repeat buyers are only 11.4% of customers (502 of 4,400) but generate 25.3% of revenue, about 2.6x the revenue per customer of one-time buyers.
- 88.6% of first-time buyers never make a second purchase. Among the 11.4% who do return, 91% do so within 30 days, so there is almost no "slow burn" repeat pattern.
- Apparel and Bags are the categories most associated with repeat behavior: repeat buyers spend ~1.9–2.2x more per person in these categories than one-time buyers.
- 44% of previously repeat buyers (221 of 502) went completely silent in the second half of the observed window, the strongest single leading indicator of churn found.
- Cart abandonment does **not** differ meaningfully between repeat (11.7%) and one-time (12.2%) buyers. This is an honest null result, not a useful signal on its own.
- $76,994 (84% of all repeat-buyer revenue) sits in customers silent 30+ days. The threshold comes directly from the 30-day return-window finding above, not an arbitrary guess.

## Repository Structure

```
revenue-churn-intelligence/
├── README.md
├── sql/
│   ├── 01_user_purchase_summary.sql        (base table, feeds everything else)
│   ├── 02_retention_dropoff_summary.sql    (documents 3 debugging iterations)
│   ├── 03_category_revenue_by_buyer_type.sql
│   ├── 04_traffic_source_by_buyer_type.sql
│   ├── 05_session_activity_decline.sql     (+ cart abandonment null result)
│   └── 06_revenue_at_risk_by_segment.sql
├── python/
│   ├── rfm_scoring.py                      (rule-based RFM, annotated)
│   └── rfm_scoring.ipynb                   (Colab notebook)
├── excel/
│   └── revenue_churn_stakeholder_summary.xlsx
├── powerbi/
│   └── revenue_churn_dashboard.pbix        (open with Power BI Desktop)
└── screenshots/
    └── dashboard.png
```

## Methodology Notes Worth Reading

The retention drop-off query (`02_retention_dropoff_summary.sql`) took 3 attempts to get right. Comments in that file document each failure and why it happened (date vs. timestamp comparison, and GA4 logging duplicate `purchase` events for the same transaction). Left in deliberately, since debugging real data quality issues is a bigger signal of analyst skill than a clean first-try query.

The RFM segmentation logic (`python/rfm_scoring.py`) also documents a real bug: an early rule set left ~1,000 customers unclassified in a lazy "Other" bucket. The fix and the reasoning behind the rule ordering are commented directly in the script.

## Author

Mohammad Kaif · [LinkedIn](https://linkedin.com/in/mohammad-kaif-4b45b6290) · [GitHub](https://github.com/mohdkaif3002)
