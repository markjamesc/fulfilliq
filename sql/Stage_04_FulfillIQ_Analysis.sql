-- =============================================================================
-- FulfillIQ Stage 4 — agreed MySQL 8.0 read-only analysis script
-- File: Stage_04_FulfillIQ_Analysis.sql
-- Schema: fulfilliq
--
-- THIS SCRIPT WAS NOT EXECUTED against a live fulfilliq instance.
-- Merge of three independent Stage 4 drafts (Grok, ChatGPT, DeepSeek)
-- resolved against Stage_03_Measurement_Design.md (controlling spec) and
-- ROUND12_INSTRUCTIONS.md. Disagreements were not resolved by majority vote.
-- See MERGE_NOTES.md in this folder.
--
-- Engine target: MySQL Community Server 8.0.x (context package: 8.0.46).
-- Read-only: SELECT / WITH / INFORMATION_SCHEMA only.
-- No data-changing statements. No USE. All raw objects are fulfilliq-qualified.
-- No passwords, credentials, or connection strings.
--
-- Controlling spec (do not reopen):
--   Decision / framing question / population / grain / KPI / decision rules
--   locked in Stage_03_Measurement_Design.md
-- Working lateness (Stage 3 default, not a Maya lock):
--   DATE(order_delivered_customer_date) > DATE(order_estimated_delivery_date)
-- Timestamp twin is computed on every seller-order and rolled to seller-window.
-- Volume floor: usable denominator >= 30 AFTER exclusions (provisional).
-- Primary-path tables: raw_orders, raw_order_items, raw_sellers ONLY.
-- Payments and reviews are pre-aggregated then LEFT UNJOINED; products,
-- categories, geolocation, and customers are not joined to seller grain.
-- No 95 percent SLA. No 8.11 percent cut. No padding a 20-name roster.
-- P95 of seller LFR is printed as a distribution statistic only.
-- Percentile method (n>=30 cohort): nearest-rank rn = CEIL(p * n) on LFR
--   sorted ascending with seller_id tie-break (discrete, documented).
-- If critical QA fails, or if date vs timestamp enroll sets differ, do not
-- treat the enroll list as authorized. Rows are still returned for review.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 2) Environment / schema checks
-- -----------------------------------------------------------------------------
SELECT
    VERSION()                                              AS mysql_version,
    @@version_comment                                      AS version_comment,
    DATABASE()                                             AS current_database,
    @@SESSION.sql_mode                                     AS session_sql_mode,
    @@GLOBAL.sql_mode                                      AS global_sql_mode,
    @@SESSION.time_zone                                    AS session_time_zone,
    @@GLOBAL.time_zone                                     AS global_time_zone,
    @@character_set_database                               AS character_set_database,
    @@collation_database                                   AS collation_database;

SELECT
    table_schema,
    table_name,
    table_rows AS info_schema_table_rows_estimate
FROM information_schema.tables
WHERE table_schema = 'fulfilliq'
ORDER BY table_name;

SELECT
    table_name,
    ordinal_position,
    column_name,
    column_type,
    is_nullable,
    column_key
FROM information_schema.columns
WHERE table_schema = 'fulfilliq'
  AND table_name IN ('raw_orders', 'raw_order_items', 'raw_sellers',
                     'raw_payments', 'raw_reviews')
ORDER BY table_name, ordinal_position;

SELECT
    s.schema_name,
    s.default_character_set_name,
    s.default_collation_name
FROM information_schema.schemata AS s
WHERE s.schema_name = 'fulfilliq';
-- Expected: exactly one row for fulfilliq.

WITH expected_tables AS (
    SELECT 'raw_orders' AS table_name
    UNION ALL SELECT 'raw_order_items'
    UNION ALL SELECT 'raw_sellers'
    UNION ALL SELECT 'raw_customers'
    UNION ALL SELECT 'raw_products'
    UNION ALL SELECT 'raw_payments'
    UNION ALL SELECT 'raw_reviews'
    UNION ALL SELECT 'raw_category_translation'
    UNION ALL SELECT 'raw_geolocation'
)
SELECT
    e.table_name,
    CASE WHEN t.table_name IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS table_exists_status
FROM expected_tables AS e
LEFT JOIN information_schema.tables AS t
    ON t.table_schema = 'fulfilliq'
   AND t.table_name = e.table_name
ORDER BY e.table_name;
-- Expected: PASS for all nine.

-- -----------------------------------------------------------------------------
-- 3) Source-table row-count reconciliation vs profile
--    Expected:
--      raw_orders 99441 | raw_order_items 112650 | raw_sellers 3095
--      raw_customers 99441 | raw_products 32951 | raw_payments 103886
--      raw_reviews 99224 | raw_category_translation 71 | raw_geolocation 1000163
--      nine-table sum 1550922
--    Context package grand total 1450922 is an arithmetic error; do not use it.
-- -----------------------------------------------------------------------------
SELECT
    t.table_name,
    t.rows_n,
    t.expected_n,
    (t.rows_n - t.expected_n) AS delta_vs_profile,
    CASE WHEN t.rows_n = t.expected_n THEN 'PASS' ELSE 'FAIL' END AS recon_status
FROM (
    SELECT 'raw_orders' AS table_name, COUNT(*) AS rows_n, 99441 AS expected_n
    FROM fulfilliq.raw_orders
    UNION ALL
    SELECT 'raw_order_items', COUNT(*), 112650 FROM fulfilliq.raw_order_items
    UNION ALL
    SELECT 'raw_sellers', COUNT(*), 3095 FROM fulfilliq.raw_sellers
    UNION ALL
    SELECT 'raw_customers', COUNT(*), 99441 FROM fulfilliq.raw_customers
    UNION ALL
    SELECT 'raw_products', COUNT(*), 32951 FROM fulfilliq.raw_products
    UNION ALL
    SELECT 'raw_payments', COUNT(*), 103886 FROM fulfilliq.raw_payments
    UNION ALL
    SELECT 'raw_reviews', COUNT(*), 99224 FROM fulfilliq.raw_reviews
    UNION ALL
    SELECT 'raw_category_translation', COUNT(*), 71 FROM fulfilliq.raw_category_translation
    UNION ALL
    SELECT 'raw_geolocation', COUNT(*), 1000163 FROM fulfilliq.raw_geolocation
) t
ORDER BY t.table_name;

SELECT
    SUM(t.rows_n) AS nine_table_sum,
    1550922 AS expected_sum,
    CASE WHEN SUM(t.rows_n) = 1550922 THEN 'PASS' ELSE 'FAIL' END AS sum_status
FROM (
    SELECT COUNT(*) AS rows_n FROM fulfilliq.raw_orders
    UNION ALL SELECT COUNT(*) FROM fulfilliq.raw_order_items
    UNION ALL SELECT COUNT(*) FROM fulfilliq.raw_sellers
    UNION ALL SELECT COUNT(*) FROM fulfilliq.raw_customers
    UNION ALL SELECT COUNT(*) FROM fulfilliq.raw_products
    UNION ALL SELECT COUNT(*) FROM fulfilliq.raw_payments
    UNION ALL SELECT COUNT(*) FROM fulfilliq.raw_reviews
    UNION ALL SELECT COUNT(*) FROM fulfilliq.raw_category_translation
    UNION ALL SELECT COUNT(*) FROM fulfilliq.raw_geolocation
) t;

-- -----------------------------------------------------------------------------
-- 4) Eligible base population (order grain) plus exclusion funnel
--    Print every exclusion count. Do not hide rows.
-- -----------------------------------------------------------------------------
SELECT 'funnel_all_orders' AS step_name, COUNT(*) AS n
FROM fulfilliq.raw_orders AS o
UNION ALL
SELECT 'funnel_delivered', COUNT(*)
FROM fulfilliq.raw_orders AS o
WHERE o.order_status = 'delivered'
UNION ALL
SELECT 'funnel_delivered_in_window', COUNT(*)
FROM fulfilliq.raw_orders AS o
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2018-01-01 00:00:00'
  AND o.order_purchase_timestamp <  '2018-09-01 00:00:00'
UNION ALL
SELECT 'funnel_window_missing_actual', COUNT(*)
FROM fulfilliq.raw_orders AS o
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2018-01-01 00:00:00'
  AND o.order_purchase_timestamp <  '2018-09-01 00:00:00'
  AND o.order_delivered_customer_date IS NULL
UNION ALL
SELECT 'funnel_window_missing_estimate', COUNT(*)
FROM fulfilliq.raw_orders AS o
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2018-01-01 00:00:00'
  AND o.order_purchase_timestamp <  '2018-09-01 00:00:00'
  AND o.order_estimated_delivery_date IS NULL
UNION ALL
SELECT 'funnel_eligible_both_timestamps', COUNT(*)
FROM fulfilliq.raw_orders AS o
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2018-01-01 00:00:00'
  AND o.order_purchase_timestamp <  '2018-09-01 00:00:00'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
UNION ALL
SELECT 'funnel_eligible_with_at_least_one_item', COUNT(*)
FROM fulfilliq.raw_orders AS o
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2018-01-01 00:00:00'
  AND o.order_purchase_timestamp <  '2018-09-01 00:00:00'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
  AND EXISTS (
        SELECT 1
        FROM fulfilliq.raw_order_items AS oi
        WHERE oi.order_id = o.order_id
  );
-- Profile anchors (full extract, not the Jan-Aug window): 8 delivered missing
-- customer-delivery date; 775 orders with no items. Live window counts will differ.

-- -----------------------------------------------------------------------------
-- 5) Item pre-aggregation to (order_id, seller_id)
-- -----------------------------------------------------------------------------
WITH cte_item_to_seller_order AS (
    SELECT
        oi.order_id,
        oi.seller_id,
        COUNT(*) AS item_row_n,
        CAST(SUM(oi.price) AS DECIMAL(18, 6)) AS item_price_sum,
        CAST(SUM(oi.freight_value) AS DECIMAL(18, 6)) AS item_freight_sum,
        MIN(oi.shipping_limit_date) AS shipping_limit_date_min,
        MAX(oi.shipping_limit_date) AS shipping_limit_date_max,
        SUM(CASE WHEN oi.shipping_limit_date >= '2020-01-01 00:00:00' THEN 1 ELSE 0 END)
            AS ship_limit_2020_item_n
    FROM fulfilliq.raw_order_items AS oi
    GROUP BY oi.order_id, oi.seller_id
)
SELECT
    COUNT(*) AS seller_order_pair_n,
    COUNT(DISTINCT iso.order_id) AS represented_order_n,
    SUM(iso.item_row_n) AS reconciled_item_row_n,
    SUM(iso.ship_limit_2020_item_n) AS ship_limit_2020_item_n
FROM cte_item_to_seller_order AS iso;
-- Expected full-table: SUM(item_row_n) = 112650.
-- Profile: 4 item rows with 2020 shipping_limit_date (diagnostic only).

-- -----------------------------------------------------------------------------
-- 6) Payment pre-aggregation to order_id. Unused join.
--    Intentionally standalone. Never joined to seller-order.
-- -----------------------------------------------------------------------------
WITH cte_payments_order AS (
    SELECT
        p.order_id,
        COUNT(*) AS payment_row_n,
        CAST(SUM(p.payment_value) AS DECIMAL(18, 6)) AS payment_value_sum
    FROM fulfilliq.raw_payments AS p
    GROUP BY p.order_id
)
SELECT
    COUNT(*) AS reduced_payment_order_n,
    SUM(po.payment_row_n) AS reconciled_payment_row_n
FROM cte_payments_order AS po;
-- Expected (source profile): 99440 distinct payment orders; 103886 payment rows.
-- This result is not joined to the KPI path.

-- -----------------------------------------------------------------------------
-- 7) Review reduction to one row per order_id. Unused join.
--    Neither review_id nor order_id is unique. Documented one-row rule:
--    latest review_creation_date, then latest review_answer_timestamp,
--    then review_id DESC.
-- -----------------------------------------------------------------------------
WITH cte_reviews_ranked AS (
    SELECT
        r.review_id,
        r.order_id,
        ROW_NUMBER() OVER (
            PARTITION BY r.order_id
            ORDER BY
                r.review_creation_date DESC,
                r.review_answer_timestamp DESC,
                r.review_id DESC
        ) AS rn_review
    FROM fulfilliq.raw_reviews AS r
),
cte_reviews_order AS (
    SELECT rr.order_id, rr.review_id
    FROM cte_reviews_ranked AS rr
    WHERE rr.rn_review = 1
)
SELECT
    (SELECT COUNT(*) FROM fulfilliq.raw_reviews) AS source_review_row_n,
    (SELECT COUNT(DISTINCT r.review_id) FROM fulfilliq.raw_reviews AS r) AS distinct_review_id_n,
    (SELECT COUNT(DISTINCT r.order_id) FROM fulfilliq.raw_reviews AS r) AS distinct_reviewed_order_n,
    (SELECT COUNT(*) FROM cte_reviews_order) AS reduced_one_row_per_order_n;
-- Expected (source profile): 99224 rows, 98410 distinct review_id, 98673 distinct
-- reviewed orders; reduced_one_row_per_order_n = 98673.
-- This result is not joined to the KPI path.

-- -----------------------------------------------------------------------------
-- 8) Sellers — the only dimension on the KPI path
-- -----------------------------------------------------------------------------
SELECT
    COUNT(*) AS seller_row_n,
    COUNT(DISTINCT s.seller_id) AS distinct_seller_id_n
FROM fulfilliq.raw_sellers AS s;
-- Expected: 3095 rows and 3095 distinct seller_id values.

-- -----------------------------------------------------------------------------
-- 9) Analysis-ready seller-order then seller-window (grain preview)
-- -----------------------------------------------------------------------------
WITH cte_orders_eligible AS (
    SELECT o.order_id
    FROM fulfilliq.raw_orders AS o
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2018-01-01 00:00:00'
      AND o.order_purchase_timestamp <  '2018-09-01 00:00:00'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
),
cte_item_to_seller_order AS (
    SELECT oi.order_id, oi.seller_id
    FROM fulfilliq.raw_order_items AS oi
    GROUP BY oi.order_id, oi.seller_id
),
cte_seller_order AS (
    SELECT iso.seller_id, iso.order_id
    FROM cte_item_to_seller_order AS iso
    INNER JOIN cte_orders_eligible AS oe
        ON oe.order_id = iso.order_id
    INNER JOIN fulfilliq.raw_sellers AS s
        ON s.seller_id = iso.seller_id
),
cte_seller_window AS (
    SELECT so.seller_id, COUNT(*) AS eligible_n
    FROM cte_seller_order AS so
    GROUP BY so.seller_id
)
SELECT
    (SELECT COUNT(*) FROM cte_seller_order) AS seller_order_row_n,
    (SELECT COUNT(*) FROM cte_seller_window) AS seller_window_row_n,
    (SELECT COUNT(*) FROM cte_seller_window AS sw WHERE sw.eligible_n >= 30)
        AS seller_n_meeting_volume_floor;
-- Expected: seller-order uniqueness holds (also gated in V9).
-- Do not treat the full-extract 627 sellers at 30 orders as the Jan-Aug 2018 n.

-- -----------------------------------------------------------------------------
-- 10) KPI outputs (cohort + peer distribution + action mix)
--     MySQL CTEs do not persist across statements. This WITH tree is
--     self-contained. Section 12 repeats a trimmed tree for the seller export.
-- -----------------------------------------------------------------------------
WITH
-- Environment echo inside the analysis statement (audit trail).
cte_version_check AS (
    SELECT
        VERSION()                          AS mysql_version,
        DATABASE()                         AS current_database,
        @@SESSION.sql_mode                 AS session_sql_mode,
        @@SESSION.time_zone                AS session_time_zone
),

-- Delivered orders whose purchase timestamp falls in [2018-01-01, 2018-09-01).
-- Window membership is purchase time, not delivery time.
cte_orders_window AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.order_status,
        o.order_purchase_timestamp,
        o.order_approved_at,
        o.order_delivered_carrier_date,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date
    FROM fulfilliq.raw_orders AS o
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2018-01-01 00:00:00'
      AND o.order_purchase_timestamp <  '2018-09-01 00:00:00'
),

-- Eligible base: both customer-delivery and estimate timestamps present.
-- The 8 full-extract delivered rows with null customer delivery drop here.
cte_orders_eligible AS (
    SELECT
        w.order_id,
        w.customer_id,
        w.order_status,
        w.order_purchase_timestamp,
        w.order_approved_at,
        w.order_delivered_carrier_date,
        w.order_delivered_customer_date,
        w.order_estimated_delivery_date,
        CASE
            WHEN w.order_purchase_timestamp >= '2018-01-01 00:00:00'
             AND w.order_purchase_timestamp <  '2018-05-01 00:00:00'
            THEN 'jan_apr'
            ELSE 'may_aug'
        END AS purchase_half,
        CASE
            WHEN w.order_delivered_carrier_date IS NOT NULL
             AND w.order_delivered_carrier_date < w.order_purchase_timestamp
            THEN 1 ELSE 0
        END AS flag_carrier_before_purchase,
        CASE
            WHEN w.order_delivered_carrier_date IS NOT NULL
             AND w.order_delivered_customer_date < w.order_delivered_carrier_date
            THEN 1 ELSE 0
        END AS flag_delivery_before_carrier
    FROM cte_orders_window AS w
    WHERE w.order_delivered_customer_date IS NOT NULL
      AND w.order_estimated_delivery_date IS NOT NULL
),

-- Item collapse to seller-order grain (mandatory). Prevents item fan-out
-- from multiplying the shared order-level delivery clock.
cte_item_to_seller_order AS (
    SELECT
        oi.order_id,
        oi.seller_id,
        COUNT(*)                         AS item_row_n,
        SUM(oi.price)                    AS item_price_sum,
        SUM(oi.freight_value)            AS item_freight_sum,
        SUM(oi.price) + SUM(oi.freight_value) AS item_price_plus_freight_sum,
        MIN(oi.shipping_limit_date)      AS shipping_limit_date_min,
        MAX(oi.shipping_limit_date)      AS shipping_limit_date_max,
        SUM(CASE
                WHEN oi.shipping_limit_date >= '2019-01-01 00:00:00'
                THEN 1 ELSE 0
            END)                         AS ship_limit_2020ish_item_n
    FROM fulfilliq.raw_order_items AS oi
    GROUP BY
        oi.order_id,
        oi.seller_id
),

-- Distinct sellers per order — attribution / multi-seller flag source.
cte_order_n_sellers AS (
    SELECT
        iso.order_id,
        COUNT(DISTINCT iso.seller_id) AS seller_n_on_order
    FROM cte_item_to_seller_order AS iso
    GROUP BY iso.order_id
),

-- Payment pre-aggregation to order_id. UNUSED on the primary path.
-- Built so a later sensitivity can join at order grain without fan-out.
-- Do NOT join this CTE to cte_seller_order.
cte_payments_order AS (
    SELECT
        p.order_id,
        COUNT(*)                         AS payment_row_n,
        SUM(p.payment_value)             AS payment_value_sum,
        MAX(p.payment_sequential)        AS payment_sequential_max,
        SUM(CASE WHEN p.payment_type = 'credit_card' THEN 1 ELSE 0 END) AS n_credit_card,
        SUM(CASE WHEN p.payment_type = 'boleto' THEN 1 ELSE 0 END)      AS n_boleto,
        SUM(CASE WHEN p.payment_type = 'voucher' THEN 1 ELSE 0 END)     AS n_voucher,
        SUM(CASE WHEN p.payment_value = 0 THEN 1 ELSE 0 END)            AS n_zero_payment
    FROM fulfilliq.raw_payments AS p
    GROUP BY p.order_id
),

-- Review reduction to one row per order_id. UNUSED on the primary path.
-- review_id and order_id are NOT unique in raw_reviews (profile).
-- Rule: latest review_creation_date, then latest review_answer_timestamp,
-- then review_id. Do NOT join this CTE to cte_seller_order.
cte_reviews_ranked AS (
    SELECT
        r.review_id,
        r.order_id,
        r.review_score,
        r.review_creation_date,
        r.review_answer_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY r.order_id
            ORDER BY
                r.review_creation_date DESC,
                r.review_answer_timestamp DESC,
                r.review_id DESC
        ) AS rn_review
    FROM fulfilliq.raw_reviews AS r
),
cte_reviews_order AS (
    SELECT
        rr.order_id,
        rr.review_id,
        rr.review_score,
        rr.review_creation_date,
        rr.review_answer_timestamp
    FROM cte_reviews_ranked AS rr
    WHERE rr.rn_review = 1
),

-- Working grain: one row per (seller_id, order_id) for eligible orders.
-- Sellers attached from raw_sellers only (no geo / customer / product).
-- Lateness twins and duration live here. Anomaly rows stay in LFR.
cte_seller_order AS (
    SELECT
        iso.seller_id,
        iso.order_id,
        s.seller_city,
        s.seller_state,
        s.seller_zip_code_prefix,
        oe.order_purchase_timestamp,
        oe.order_delivered_carrier_date,
        oe.order_delivered_customer_date,
        oe.order_estimated_delivery_date,
        oe.purchase_half,
        ns.seller_n_on_order,
        CASE WHEN ns.seller_n_on_order = 1 THEN 1 ELSE 0 END AS is_single_seller_order,
        CASE WHEN ns.seller_n_on_order > 1 THEN 1 ELSE 0 END AS is_multi_seller_order,
        iso.item_row_n,
        iso.item_price_sum,
        iso.item_freight_sum,
        iso.item_price_plus_freight_sum,
        iso.shipping_limit_date_min,
        iso.shipping_limit_date_max,
        iso.ship_limit_2020ish_item_n,
        oe.flag_carrier_before_purchase,
        oe.flag_delivery_before_carrier,
        CASE
            WHEN oe.flag_carrier_before_purchase = 1
              OR oe.flag_delivery_before_carrier = 1
            THEN 1 ELSE 0
        END AS is_sequence_anomaly,
        -- Working rule (calendar date).
        CASE
            WHEN DATE(oe.order_delivered_customer_date)
               > DATE(oe.order_estimated_delivery_date)
            THEN 1 ELSE 0
        END AS is_late_date,
        -- Timestamp twin.
        CASE
            WHEN oe.order_delivered_customer_date
               > oe.order_estimated_delivery_date
            THEN 1 ELSE 0
        END AS is_late_ts,
        DATEDIFF(
            DATE(oe.order_delivered_customer_date),
            DATE(oe.order_estimated_delivery_date)
        ) AS days_vs_estimate
        -- Intentionally no payment_* or review_* columns: unused-join contract.
    FROM cte_item_to_seller_order AS iso
    INNER JOIN cte_orders_eligible AS oe
        ON oe.order_id = iso.order_id
    INNER JOIN cte_order_n_sellers AS ns
        ON ns.order_id = iso.order_id
    INNER JOIN fulfilliq.raw_sellers AS s
        ON s.seller_id = iso.seller_id
),

-- Duration-eligible subset: sequence anomalies parked out of medians only.
cte_seller_order_duration AS (
    SELECT
        so.seller_id,
        so.order_id,
        so.days_vs_estimate,
        so.is_late_date
    FROM cte_seller_order AS so
    WHERE so.is_sequence_anomaly = 0
),

-- Median days vs estimate (all duration-eligible seller-orders).
cte_median_all AS (
    SELECT
        d.seller_id,
        AVG(d.days_vs_estimate) AS median_days_vs_estimate
    FROM (
        SELECT
            sod.seller_id,
            sod.days_vs_estimate,
            ROW_NUMBER() OVER (
                PARTITION BY sod.seller_id
                ORDER BY sod.days_vs_estimate
            ) AS rn,
            COUNT(*) OVER (PARTITION BY sod.seller_id) AS n
        FROM cte_seller_order_duration AS sod
    ) AS d
    WHERE d.rn IN (FLOOR((d.n + 1) / 2.0), CEIL((d.n + 1) / 2.0))
    GROUP BY d.seller_id
),

-- Median days late among date-late, duration-eligible seller-orders.
cte_median_late AS (
    SELECT
        d.seller_id,
        AVG(d.days_vs_estimate) AS median_days_late
    FROM (
        SELECT
            sod.seller_id,
            sod.days_vs_estimate,
            ROW_NUMBER() OVER (
                PARTITION BY sod.seller_id
                ORDER BY sod.days_vs_estimate
            ) AS rn,
            COUNT(*) OVER (PARTITION BY sod.seller_id) AS n
        FROM cte_seller_order_duration AS sod
        WHERE sod.is_late_date = 1
    ) AS d
    WHERE d.rn IN (FLOOR((d.n + 1) / 2.0), CEIL((d.n + 1) / 2.0))
    GROUP BY d.seller_id
),

-- Seller-window roll-up (decision grain).
cte_seller_window AS (
    SELECT
        so.seller_id,
        MIN(so.seller_state) AS seller_state,
        MIN(so.seller_city)  AS seller_city,
        COUNT(*)             AS eligible_n,
        SUM(so.is_late_date) AS late_n_date,
        SUM(1 - so.is_late_date) AS on_time_n_date,
        SUM(so.is_late_ts)   AS late_n_ts,
        SUM(CASE WHEN so.purchase_half = 'jan_apr' THEN 1 ELSE 0 END) AS eligible_n_jan_apr,
        SUM(CASE WHEN so.purchase_half = 'jan_apr' THEN so.is_late_date ELSE 0 END) AS late_n_jan_apr,
        SUM(CASE WHEN so.purchase_half = 'may_aug' THEN 1 ELSE 0 END) AS eligible_n_may_aug,
        SUM(CASE WHEN so.purchase_half = 'may_aug' THEN so.is_late_date ELSE 0 END) AS late_n_may_aug,
        SUM(so.is_single_seller_order) AS eligible_n_single,
        SUM(CASE WHEN so.is_single_seller_order = 1 THEN so.is_late_date ELSE 0 END) AS late_n_single,
        SUM(so.is_multi_seller_order) AS multi_seller_order_n,
        SUM(so.item_price_sum) AS item_revenue,
        SUM(so.item_price_plus_freight_sum) AS item_revenue_plus_freight,
        SUM(so.is_sequence_anomaly) AS anomaly_n,
        CAST(SUM(so.is_late_date) AS DECIMAL(18, 6))
            / NULLIF(CAST(COUNT(*) AS DECIMAL(18, 6)), 0) AS lfr_date,
        CAST(SUM(so.is_late_ts) AS DECIMAL(18, 6))
            / NULLIF(CAST(COUNT(*) AS DECIMAL(18, 6)), 0) AS lfr_timestamp,
        CAST(SUM(CASE WHEN so.purchase_half = 'jan_apr' THEN so.is_late_date ELSE 0 END) AS DECIMAL(18, 6))
            / NULLIF(CAST(SUM(CASE WHEN so.purchase_half = 'jan_apr' THEN 1 ELSE 0 END) AS DECIMAL(18, 6)), 0) AS lfr_jan_apr,
        CAST(SUM(CASE WHEN so.purchase_half = 'may_aug' THEN so.is_late_date ELSE 0 END) AS DECIMAL(18, 6))
            / NULLIF(CAST(SUM(CASE WHEN so.purchase_half = 'may_aug' THEN 1 ELSE 0 END) AS DECIMAL(18, 6)), 0) AS lfr_may_aug,
        CAST(SUM(CASE WHEN so.is_single_seller_order = 1 THEN so.is_late_date ELSE 0 END) AS DECIMAL(18, 6))
            / NULLIF(CAST(SUM(so.is_single_seller_order) AS DECIMAL(18, 6)), 0) AS lfr_single_seller,
        CAST(SUM(so.is_multi_seller_order) AS DECIMAL(18, 6))
            / NULLIF(CAST(COUNT(*) AS DECIMAL(18, 6)), 0) AS multi_seller_order_share,
        CAST(SUM(so.is_sequence_anomaly) AS DECIMAL(18, 6))
            / NULLIF(CAST(COUNT(*) AS DECIMAL(18, 6)), 0) AS anomaly_share
    FROM cte_seller_order AS so
    GROUP BY so.seller_id
),

cte_seller_window_enriched AS (
    SELECT
        sw.*,
        ma.median_days_vs_estimate,
        ml.median_days_late,
        CASE WHEN sw.eligible_n >= 30 THEN 1 ELSE 0 END AS meets_volume_floor,
        CASE
            WHEN sw.eligible_n < 30 THEN 'below_floor'
            WHEN sw.eligible_n < 50 THEN '30_49'
            WHEN sw.eligible_n < 100 THEN '50_99'
            ELSE '100_plus'
        END AS volume_band
    FROM cte_seller_window AS sw
    LEFT JOIN cte_median_all AS ma
        ON ma.seller_id = sw.seller_id
    LEFT JOIN cte_median_late AS ml
        ON ml.seller_id = sw.seller_id
),

-- Enrollment-eligible cohort: usable n >= 30 after exclusions.
cte_floor_sellers AS (
    SELECT
        e.seller_id,
        e.eligible_n,
        e.late_n_date,
        e.late_n_ts,
        e.lfr_date,
        e.lfr_timestamp
    FROM cte_seller_window_enriched AS e
    WHERE e.eligible_n >= 30
),

-- Data-derived peer benchmarks among n>=30 (date LFR primary).
cte_peer_ranks_date AS (
    SELECT
        fs.seller_id,
        fs.lfr_date,
        ROW_NUMBER() OVER (ORDER BY fs.lfr_date ASC, fs.seller_id ASC) AS rn_asc,
        COUNT(*) OVER () AS n_floor_sellers
    FROM cte_floor_sellers AS fs
),
cte_peer_ranks_ts AS (
    SELECT
        fs.seller_id,
        fs.lfr_timestamp,
        ROW_NUMBER() OVER (ORDER BY fs.lfr_timestamp ASC, fs.seller_id ASC) AS rn_asc,
        COUNT(*) OVER () AS n_floor_sellers
    FROM cte_floor_sellers AS fs
),

-- One-row peer benchmark record. Nearest-rank: CEIL(p * n) on ascending LFR.
cte_peer_benchmarks AS (
    SELECT
        COUNT(*) AS n_floor_sellers,
        CAST(SUM(fs.late_n_date) AS DECIMAL(18, 6))
            / NULLIF(CAST(SUM(fs.eligible_n) AS DECIMAL(18, 6)), 0) AS peer_weighted_mkt_lfr,
        AVG(fs.lfr_date) AS peer_equal_wt_lfr,
        MIN(fs.lfr_date) AS peer_min_lfr,
        MAX(fs.lfr_date) AS peer_max_lfr,
        (SELECT pr.lfr_date
           FROM cte_peer_ranks_date AS pr
          WHERE pr.rn_asc = GREATEST(1, CEIL(0.25 * pr.n_floor_sellers))
          LIMIT 1) AS peer_p25_lfr,
        (SELECT pr.lfr_date
           FROM cte_peer_ranks_date AS pr
          WHERE pr.rn_asc = GREATEST(1, CEIL(0.50 * pr.n_floor_sellers))
          LIMIT 1) AS peer_median_lfr,
        (SELECT pr.lfr_date
           FROM cte_peer_ranks_date AS pr
          WHERE pr.rn_asc = GREATEST(1, CEIL(0.75 * pr.n_floor_sellers))
          LIMIT 1) AS peer_p75_lfr,
        (SELECT pr.lfr_date
           FROM cte_peer_ranks_date AS pr
          WHERE pr.rn_asc = GREATEST(1, CEIL(0.90 * pr.n_floor_sellers))
          LIMIT 1) AS peer_p90_lfr,
        (SELECT pr.lfr_date
           FROM cte_peer_ranks_date AS pr
          WHERE pr.rn_asc = GREATEST(1, CEIL(0.95 * pr.n_floor_sellers))
          LIMIT 1) AS peer_p95_lfr,
        CAST(SUM(fs.late_n_ts) AS DECIMAL(18, 6))
            / NULLIF(CAST(SUM(fs.eligible_n) AS DECIMAL(18, 6)), 0) AS peer_weighted_mkt_lfr_ts,
        (SELECT pr.lfr_timestamp
           FROM cte_peer_ranks_ts AS pr
          WHERE pr.rn_asc = GREATEST(1, CEIL(0.75 * pr.n_floor_sellers))
          LIMIT 1) AS peer_p75_lfr_ts,
        (SELECT pr.lfr_timestamp
           FROM cte_peer_ranks_ts AS pr
          WHERE pr.rn_asc = GREATEST(1, CEIL(0.90 * pr.n_floor_sellers))
          LIMIT 1) AS peer_p90_lfr_ts
    FROM cte_floor_sellers AS fs
),

-- Screen each seller against the working peer bar and guardrails.
cte_seller_screened AS (
    SELECT
        e.seller_id,
        e.seller_state,
        e.seller_city,
        e.eligible_n,
        e.late_n_date,
        e.on_time_n_date,
        e.lfr_date,
        e.late_n_ts,
        e.lfr_timestamp,
        e.median_days_vs_estimate,
        e.median_days_late,
        e.eligible_n_jan_apr,
        e.late_n_jan_apr,
        e.lfr_jan_apr,
        e.eligible_n_may_aug,
        e.late_n_may_aug,
        e.lfr_may_aug,
        e.eligible_n_single,
        e.late_n_single,
        e.lfr_single_seller,
        e.multi_seller_order_n,
        e.multi_seller_order_share,
        e.item_revenue,
        e.item_revenue_plus_freight,
        e.anomaly_n,
        e.anomaly_share,
        e.meets_volume_floor,
        e.volume_band,
        b.n_floor_sellers,
        b.peer_weighted_mkt_lfr,
        b.peer_equal_wt_lfr,
        b.peer_min_lfr,
        b.peer_p25_lfr,
        b.peer_median_lfr,
        b.peer_p75_lfr,
        b.peer_p90_lfr,
        b.peer_p95_lfr,
        b.peer_max_lfr,
        b.peer_weighted_mkt_lfr_ts,
        b.peer_p75_lfr_ts,
        b.peer_p90_lfr_ts,
        CASE
            WHEN e.meets_volume_floor = 1
             AND e.lfr_date >= b.peer_p75_lfr
             AND e.lfr_date >  b.peer_weighted_mkt_lfr
            THEN 1 ELSE 0
        END AS pass_p75,
        CASE
            WHEN e.meets_volume_floor = 1
             AND e.lfr_date >= b.peer_p90_lfr
             AND e.lfr_date >  b.peer_weighted_mkt_lfr
            THEN 1 ELSE 0
        END AS pass_p90,
        CASE
            WHEN e.meets_volume_floor = 1
             AND e.lfr_timestamp >= b.peer_p75_lfr_ts
             AND e.lfr_timestamp >  b.peer_weighted_mkt_lfr_ts
            THEN 1 ELSE 0
        END AS pass_p75_ts,
        -- Attribution: all-order would enroll on P75 bar but single-seller would not.
        CASE
            WHEN e.meets_volume_floor = 1
             AND e.lfr_date >= b.peer_p75_lfr
             AND e.lfr_date >  b.peer_weighted_mkt_lfr
             AND (
                    e.eligible_n_single = 0
                 OR e.lfr_single_seller IS NULL
                 OR NOT (
                        e.lfr_single_seller >= b.peer_p75_lfr
                    AND e.lfr_single_seller >  b.peer_weighted_mkt_lfr
                 )
             )
            THEN 1 ELSE 0
        END AS attribution_conflict,
        -- Precision: date P75 action differs from timestamp P75 action.
        CASE
            WHEN e.meets_volume_floor = 1
             AND (
                    (e.lfr_date >= b.peer_p75_lfr AND e.lfr_date > b.peer_weighted_mkt_lfr)
                 XOR
                    (e.lfr_timestamp >= b.peer_p75_lfr_ts AND e.lfr_timestamp > b.peer_weighted_mkt_lfr_ts)
             )
            THEN 1 ELSE 0
        END AS date_ts_action_conflict,
        -- Stability: only one half above the date peer bar and the other
        -- at or below the equal-seller median LFR of the n>=30 cohort.
        CASE
            WHEN e.meets_volume_floor = 1
             AND e.lfr_date >= b.peer_p75_lfr
             AND e.lfr_date >  b.peer_weighted_mkt_lfr
             AND e.eligible_n_jan_apr > 0
             AND e.eligible_n_may_aug > 0
             AND (
                    (
                        e.lfr_jan_apr >= b.peer_p75_lfr
                    AND e.lfr_jan_apr >  b.peer_weighted_mkt_lfr
                    AND (e.lfr_may_aug IS NULL OR e.lfr_may_aug <= b.peer_median_lfr)
                    )
                 OR (
                        e.lfr_may_aug >= b.peer_p75_lfr
                    AND e.lfr_may_aug >  b.peer_weighted_mkt_lfr
                    AND (e.lfr_jan_apr IS NULL OR e.lfr_jan_apr <= b.peer_median_lfr)
                    )
             )
            THEN 1 ELSE 0
        END AS split_window_unstable
    FROM cte_seller_window_enriched AS e
    CROSS JOIN cte_peer_benchmarks AS b
),

-- Count clean P75 passers (volume + peer + attribution + precision + stability).
-- If that set exceeds ~20, raise the operable enroll bar to P90.
cte_cap_stats AS (
    SELECT
        SUM(CASE
                WHEN s.pass_p75 = 1
                 AND s.attribution_conflict = 0
                 AND s.date_ts_action_conflict = 0
                 AND s.split_window_unstable = 0
                THEN 1 ELSE 0
            END) AS n_clean_p75,
        CASE
            WHEN SUM(CASE
                        WHEN s.pass_p75 = 1
                         AND s.attribution_conflict = 0
                         AND s.date_ts_action_conflict = 0
                         AND s.split_window_unstable = 0
                        THEN 1 ELSE 0
                     END) > 20
            THEN 1 ELSE 0
        END AS raise_bar_to_p90
    FROM cte_seller_screened AS s
),

cte_seller_decided AS (
    SELECT
        s.*,
        c.n_clean_p75,
        c.raise_bar_to_p90,
        CASE
            WHEN s.pass_p75 = 1 THEN
                ROW_NUMBER() OVER (
                    PARTITION BY CASE WHEN s.pass_p75 = 1 THEN 1 ELSE 0 END
                    ORDER BY
                        s.lfr_date DESC,
                        s.late_n_date DESC,
                        s.eligible_n DESC,
                        s.seller_id ASC
                )
            ELSE NULL
        END AS rank_if_candidate,
        CASE
            WHEN s.meets_volume_floor = 0 THEN 'standard_terms'
            WHEN s.attribution_conflict = 1 OR s.date_ts_action_conflict = 1 THEN 'inconclusive'
            WHEN s.split_window_unstable = 1 THEN 'watch'
            WHEN c.raise_bar_to_p90 = 1 AND s.pass_p90 = 1 THEN 'enroll'
            WHEN c.raise_bar_to_p90 = 1 AND s.pass_p75 = 1 THEN 'watch'
            WHEN c.raise_bar_to_p90 = 0 AND s.pass_p75 = 1 THEN 'enroll'
            ELSE 'standard_terms'
        END AS action,
        CASE
            WHEN s.meets_volume_floor = 0
                THEN 'usable_n_lt_30'
            WHEN s.attribution_conflict = 1 AND s.date_ts_action_conflict = 1
                THEN 'attribution_and_precision_conflict'
            WHEN s.attribution_conflict = 1
                THEN 'single_seller_lfr_does_not_support_enroll'
            WHEN s.date_ts_action_conflict = 1
                THEN 'date_vs_timestamp_action_conflict'
            WHEN s.split_window_unstable = 1
                THEN 'split_window_unstable'
            WHEN c.raise_bar_to_p90 = 1 AND s.pass_p90 = 1
                THEN 'p90_and_above_weighted_after_cap'
            WHEN c.raise_bar_to_p90 = 1 AND s.pass_p75 = 1
                THEN 'p75_watch_band_after_cap'
            WHEN c.raise_bar_to_p90 = 0 AND s.pass_p75 = 1
                THEN 'p75_and_above_weighted'
            ELSE 'at_or_below_peer_bar'
        END AS action_reason
    FROM cte_seller_screened AS s
    CROSS JOIN cte_cap_stats AS c
)

SELECT
    'kpi_cohort' AS result_set,
    (SELECT COUNT(*) FROM cte_orders_window) AS delivered_orders_in_window,
    (SELECT COUNT(*) FROM cte_orders_eligible) AS eligible_orders_both_timestamps,
    (SELECT COUNT(*) FROM cte_seller_order) AS eligible_seller_orders,
    (SELECT COUNT(DISTINCT so.seller_id) FROM cte_seller_order AS so) AS sellers_in_window,
    (SELECT COUNT(*) FROM cte_floor_sellers) AS sellers_n_ge_30,
    (SELECT SUM(fs.eligible_n) FROM cte_floor_sellers AS fs) AS floor_seller_order_n,
    (SELECT SUM(fs.late_n_date) FROM cte_floor_sellers AS fs) AS floor_late_n_date,
    (SELECT COUNT(*) FROM cte_payments_order) AS unused_payment_order_n,
    (SELECT COUNT(*) FROM cte_reviews_order) AS unused_review_order_n,
    b.peer_weighted_mkt_lfr,
    b.peer_equal_wt_lfr,
    b.peer_min_lfr,
    b.peer_p25_lfr,
    b.peer_median_lfr,
    b.peer_p75_lfr,
    b.peer_p90_lfr,
    b.peer_p95_lfr,
    b.peer_max_lfr,
    b.peer_weighted_mkt_lfr_ts,
    b.peer_p75_lfr_ts,
    c.n_clean_p75,
    c.raise_bar_to_p90,
    (SELECT COUNT(*) FROM cte_seller_decided AS d WHERE d.action = 'enroll') AS n_enroll,
    (SELECT COUNT(*) FROM cte_seller_decided AS d WHERE d.action = 'watch') AS n_watch,
    (SELECT COUNT(*) FROM cte_seller_decided AS d WHERE d.action = 'inconclusive') AS n_inconclusive,
    (SELECT COUNT(*) FROM cte_seller_decided AS d WHERE d.action = 'standard_terms') AS n_standard_terms,
    (SELECT COUNT(*) FROM cte_seller_decided AS d WHERE d.date_ts_action_conflict = 1) AS n_date_ts_action_conflict
FROM cte_peer_benchmarks AS b
CROSS JOIN cte_cap_stats AS c;
-- unused_payment_order_n / unused_review_order_n prove those CTEs were built
-- and were not joined onto seller-order.
-- If n_date_ts_action_conflict > 0, those sellers are inconclusive; if the
-- enroll set would still differ after that overlay, stop and ask Maya.


-- Same WITH tree reused conceptually: validations are standalone so a
-- failed gate is visible even if a later SELECT is not run. Critical
-- gates below use the same filters as the analysis CTEs.

-- ---------------------------------------------------------------------------
-- 11) Validation queries (expected pass described in comments)
-- ---------------------------------------------------------------------------

-- V1 Critical: raw_orders.order_id uniqueness. Expected: 0 duplicate keys.
SELECT
    'v1_orders_pk' AS gate,
    COUNT(*) - COUNT(DISTINCT o.order_id) AS duplicate_keys,
    CASE WHEN COUNT(*) - COUNT(DISTINCT o.order_id) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM fulfilliq.raw_orders AS o;

-- V2 Critical: raw_order_items (order_id, order_item_id) uniqueness. Expected: 0.
SELECT
    'v2_items_pk' AS gate,
    COUNT(*) - COUNT(DISTINCT oi.order_id, oi.order_item_id) AS duplicate_keys,
    CASE WHEN COUNT(*) - COUNT(DISTINCT oi.order_id, oi.order_item_id) = 0
         THEN 'PASS' ELSE 'FAIL' END AS status
FROM fulfilliq.raw_order_items AS oi;

-- V3 Critical: raw_payments (order_id, payment_sequential) uniqueness. Expected: 0.
SELECT
    'v3_payments_pk' AS gate,
    COUNT(*) - COUNT(DISTINCT p.order_id, p.payment_sequential) AS duplicate_keys,
    CASE WHEN COUNT(*) - COUNT(DISTINCT p.order_id, p.payment_sequential) = 0
         THEN 'PASS' ELSE 'FAIL' END AS status
FROM fulfilliq.raw_payments AS p;

-- V4 Critical: six profiled orphan checks. Expected: 0 each.
SELECT 'v4a_items_orphan_order' AS gate, COUNT(*) AS orphan_rows,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM fulfilliq.raw_order_items AS oi
LEFT JOIN fulfilliq.raw_orders AS o ON o.order_id = oi.order_id
WHERE o.order_id IS NULL;

SELECT 'v4b_items_orphan_seller' AS gate, COUNT(*) AS orphan_rows,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM fulfilliq.raw_order_items AS oi
LEFT JOIN fulfilliq.raw_sellers AS s ON s.seller_id = oi.seller_id
WHERE s.seller_id IS NULL;

SELECT 'v4c_items_orphan_product' AS gate, COUNT(*) AS orphan_rows,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM fulfilliq.raw_order_items AS oi
LEFT JOIN fulfilliq.raw_products AS p ON p.product_id = oi.product_id
WHERE p.product_id IS NULL;

SELECT 'v4d_orders_orphan_customer' AS gate, COUNT(*) AS orphan_rows,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM fulfilliq.raw_orders AS o
LEFT JOIN fulfilliq.raw_customers AS c ON c.customer_id = o.customer_id
WHERE c.customer_id IS NULL;

SELECT 'v4e_payments_orphan_order' AS gate, COUNT(*) AS orphan_rows,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM fulfilliq.raw_payments AS p
LEFT JOIN fulfilliq.raw_orders AS o ON o.order_id = p.order_id
WHERE o.order_id IS NULL;

SELECT 'v4f_reviews_orphan_order' AS gate, COUNT(*) AS orphan_rows,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM fulfilliq.raw_reviews AS r
LEFT JOIN fulfilliq.raw_orders AS o ON o.order_id = r.order_id
WHERE o.order_id IS NULL;

-- V5 High: no negative price / freight / payment_value. Expected: 0.
SELECT 'v5a_negative_price' AS gate, COUNT(*) AS bad_rows,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM fulfilliq.raw_order_items AS oi
WHERE oi.price < 0;

SELECT 'v5b_negative_freight' AS gate, COUNT(*) AS bad_rows,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM fulfilliq.raw_order_items AS oi
WHERE oi.freight_value < 0;

SELECT 'v5c_negative_payment' AS gate, COUNT(*) AS bad_rows,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM fulfilliq.raw_payments AS p
WHERE p.payment_value < 0;

-- V6 Critical: LFR extract contains zero non-delivered rows.
SELECT
    'v6_non_delivered_in_lfr_extract' AS gate,
    SUM(CASE WHEN o.order_status <> 'delivered' THEN 1 ELSE 0 END) AS non_delivered_rows,
    CASE
        WHEN SUM(CASE WHEN o.order_status <> 'delivered' THEN 1 ELSE 0 END) = 0
        THEN 'PASS' ELSE 'FAIL'
    END AS status
FROM fulfilliq.raw_order_items AS oi
INNER JOIN fulfilliq.raw_orders AS o
    ON o.order_id = oi.order_id
INNER JOIN fulfilliq.raw_sellers AS s
    ON s.seller_id = oi.seller_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2018-01-01 00:00:00'
  AND o.order_purchase_timestamp <  '2018-09-01 00:00:00'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL;
-- The WHERE already restricts to delivered; the SUM documents the contract.

-- V7 High: delivered-in-window missing actual or estimate (QA count; excluded from LFR).
-- Full-extract profile had 8 delivered missing customer delivery (all years).
SELECT
    'v7_delivered_window_missing_delivery_ts' AS gate,
    SUM(CASE WHEN o.order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) AS missing_actual_n,
    SUM(CASE WHEN o.order_estimated_delivery_date IS NULL THEN 1 ELSE 0 END) AS missing_estimate_n,
    'informational — these rows are excluded from LFR' AS expected
FROM fulfilliq.raw_orders AS o
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2018-01-01 00:00:00'
  AND o.order_purchase_timestamp <  '2018-09-01 00:00:00';

-- V8 High: sequence-anomaly counts inside the eligible window (keep in LFR).
SELECT
    'v8_sequence_anomalies_in_eligible_orders' AS gate,
    SUM(CASE
            WHEN o.order_delivered_carrier_date IS NOT NULL
             AND o.order_delivered_carrier_date < o.order_purchase_timestamp
            THEN 1 ELSE 0
        END) AS carrier_before_purchase_n,
    SUM(CASE
            WHEN o.order_delivered_carrier_date IS NOT NULL
             AND o.order_delivered_customer_date IS NOT NULL
             AND o.order_delivered_customer_date < o.order_delivered_carrier_date
            THEN 1 ELSE 0
        END) AS delivery_before_carrier_n,
    'informational — flagged; retained in LFR; dropped from duration medians' AS expected
FROM fulfilliq.raw_orders AS o
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2018-01-01 00:00:00'
  AND o.order_purchase_timestamp <  '2018-09-01 00:00:00'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL;

-- V9 Critical: seller-order uniqueness and join-expansion reconciliation.
-- seller-order rows must equal distinct (order_id, seller_id) on items
-- whose parent order is eligible.
SELECT
    'v9_seller_order_grain' AS gate,
    so_n.seller_order_n,
    iso_n.item_pair_n,
    so_n.seller_order_n - iso_n.item_pair_n AS delta,
    CASE WHEN so_n.seller_order_n = iso_n.item_pair_n THEN 'PASS' ELSE 'FAIL' END AS status
FROM (
    SELECT COUNT(*) AS seller_order_n
    FROM (
        SELECT oi.seller_id, oi.order_id
        FROM fulfilliq.raw_order_items AS oi
        INNER JOIN fulfilliq.raw_orders AS o
            ON o.order_id = oi.order_id
        INNER JOIN fulfilliq.raw_sellers AS s
            ON s.seller_id = oi.seller_id
        WHERE o.order_status = 'delivered'
          AND o.order_purchase_timestamp >= '2018-01-01 00:00:00'
          AND o.order_purchase_timestamp <  '2018-09-01 00:00:00'
          AND o.order_delivered_customer_date IS NOT NULL
          AND o.order_estimated_delivery_date IS NOT NULL
        GROUP BY oi.seller_id, oi.order_id
    ) AS x
) AS so_n
CROSS JOIN (
    SELECT COUNT(*) AS item_pair_n
    FROM (
        SELECT oi.order_id, oi.seller_id
        FROM fulfilliq.raw_order_items AS oi
        INNER JOIN fulfilliq.raw_orders AS o
            ON o.order_id = oi.order_id
        INNER JOIN fulfilliq.raw_sellers AS s
            ON s.seller_id = oi.seller_id
        WHERE o.order_status = 'delivered'
          AND o.order_purchase_timestamp >= '2018-01-01 00:00:00'
          AND o.order_purchase_timestamp <  '2018-09-01 00:00:00'
          AND o.order_delivered_customer_date IS NOT NULL
          AND o.order_estimated_delivery_date IS NOT NULL
        GROUP BY oi.order_id, oi.seller_id
    ) AS y
) AS iso_n;

-- V10: payments / reviews pre-agg exist at order grain and are NOT required
-- for the seller-order count (contract check). Expected: pre-agg row counts
-- equal distinct order_id in each source; seller-order query does not
-- reference those tables.
SELECT
    'v10a_payments_preagg_grain' AS gate,
    COUNT(*) AS payment_rows,
    COUNT(DISTINCT p.order_id) AS distinct_orders,
    COUNT(*) - COUNT(DISTINCT p.order_id) AS extra_rows_beyond_one_per_order,
    'informational — extra rows prove why pre-agg is required; do not join raw' AS expected
FROM fulfilliq.raw_payments AS p;

SELECT
    'v10b_reviews_preagg_grain' AS gate,
    COUNT(*) AS review_rows,
    COUNT(DISTINCT r.review_id) AS distinct_review_id,
    COUNT(DISTINCT r.order_id) AS distinct_order_id,
    'informational — neither key is unique; reduction rule is latest review' AS expected
FROM fulfilliq.raw_reviews AS r;

SELECT
    'v10c_unused_join_contract' AS gate,
    'PASS_BY_CONSTRUCTION' AS status,
    'cte_seller_order selects no payment or review columns and has no JOIN to those CTEs' AS expected;

-- V11: LFR denominator has zero null actual/estimate and zero non-delivered.
-- Equivalent filter reconstruction.
SELECT
    'v11_lfr_denom_integrity' AS gate,
    SUM(CASE WHEN o.order_status <> 'delivered' THEN 1 ELSE 0 END) AS non_delivered_in_denom,
    SUM(CASE WHEN o.order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) AS null_actual_in_denom,
    SUM(CASE WHEN o.order_estimated_delivery_date IS NULL THEN 1 ELSE 0 END) AS null_estimate_in_denom,
    CASE
        WHEN SUM(CASE WHEN o.order_status <> 'delivered' THEN 1 ELSE 0 END) = 0
         AND SUM(CASE WHEN o.order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) = 0
         AND SUM(CASE WHEN o.order_estimated_delivery_date IS NULL THEN 1 ELSE 0 END) = 0
        THEN 'PASS' ELSE 'FAIL'
    END AS status
FROM fulfilliq.raw_order_items AS oi
INNER JOIN fulfilliq.raw_orders AS o
    ON o.order_id = oi.order_id
INNER JOIN fulfilliq.raw_sellers AS s
    ON s.seller_id = oi.seller_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2018-01-01 00:00:00'
  AND o.order_purchase_timestamp <  '2018-09-01 00:00:00'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL;

-- V12: no output uses 95 or 8.11 as a cut — enforced by construction
-- (peer bar is data-derived percentiles / weighted LFR).
SELECT
    'v12_forbidden_cuts' AS gate,
    'PASS_BY_CONSTRUCTION' AS status,
    'no 0.95 SLA predicate and no 0.0811 constant in action CASE; P95 is descriptive only' AS expected;

-- V13 High: 2020 shipping-limit item rows (diagnostic only). Profile: 4.
SELECT
    'v13_ship_limit_2020_items' AS gate,
    COUNT(*) AS item_rows_2020_ship_limit,
    'informational — keep parent order in LFR; exclude these item rows from ship-limit diagnostic only' AS expected
FROM fulfilliq.raw_order_items AS oi
WHERE oi.shipping_limit_date >= '2020-01-01 00:00:00';

-- ---------------------------------------------------------------------------
-- 12) Final export: one row = one seller in the analysis window
--     Explicit column list. No SELECT *.
-- ---------------------------------------------------------------------------
WITH
cte_orders_window AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.order_status,
        o.order_purchase_timestamp,
        o.order_approved_at,
        o.order_delivered_carrier_date,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date
    FROM fulfilliq.raw_orders AS o
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2018-01-01 00:00:00'
      AND o.order_purchase_timestamp <  '2018-09-01 00:00:00'
),
cte_orders_eligible AS (
    SELECT
        w.order_id,
        w.customer_id,
        w.order_status,
        w.order_purchase_timestamp,
        w.order_approved_at,
        w.order_delivered_carrier_date,
        w.order_delivered_customer_date,
        w.order_estimated_delivery_date,
        CASE
            WHEN w.order_purchase_timestamp >= '2018-01-01 00:00:00'
             AND w.order_purchase_timestamp <  '2018-05-01 00:00:00'
            THEN 'jan_apr'
            ELSE 'may_aug'
        END AS purchase_half,
        CASE
            WHEN w.order_delivered_carrier_date IS NOT NULL
             AND w.order_delivered_carrier_date < w.order_purchase_timestamp
            THEN 1 ELSE 0
        END AS flag_carrier_before_purchase,
        CASE
            WHEN w.order_delivered_carrier_date IS NOT NULL
             AND w.order_delivered_customer_date < w.order_delivered_carrier_date
            THEN 1 ELSE 0
        END AS flag_delivery_before_carrier
    FROM cte_orders_window AS w
    WHERE w.order_delivered_customer_date IS NOT NULL
      AND w.order_estimated_delivery_date IS NOT NULL
),
cte_item_to_seller_order AS (
    SELECT
        oi.order_id,
        oi.seller_id,
        COUNT(*) AS item_row_n,
        SUM(oi.price) AS item_price_sum,
        SUM(oi.freight_value) AS item_freight_sum,
        SUM(oi.price) + SUM(oi.freight_value) AS item_price_plus_freight_sum,
        MIN(oi.shipping_limit_date) AS shipping_limit_date_min,
        MAX(oi.shipping_limit_date) AS shipping_limit_date_max
    FROM fulfilliq.raw_order_items AS oi
    GROUP BY oi.order_id, oi.seller_id
),
cte_order_n_sellers AS (
    SELECT
        iso.order_id,
        COUNT(DISTINCT iso.seller_id) AS seller_n_on_order
    FROM cte_item_to_seller_order AS iso
    GROUP BY iso.order_id
),
cte_seller_order AS (
    SELECT
        iso.seller_id,
        iso.order_id,
        s.seller_city,
        s.seller_state,
        oe.order_purchase_timestamp,
        oe.order_delivered_customer_date,
        oe.order_estimated_delivery_date,
        oe.purchase_half,
        ns.seller_n_on_order,
        CASE WHEN ns.seller_n_on_order = 1 THEN 1 ELSE 0 END AS is_single_seller_order,
        CASE WHEN ns.seller_n_on_order > 1 THEN 1 ELSE 0 END AS is_multi_seller_order,
        iso.item_price_sum,
        iso.item_price_plus_freight_sum,
        CASE
            WHEN oe.flag_carrier_before_purchase = 1
              OR oe.flag_delivery_before_carrier = 1
            THEN 1 ELSE 0
        END AS is_sequence_anomaly,
        CASE
            WHEN DATE(oe.order_delivered_customer_date)
               > DATE(oe.order_estimated_delivery_date)
            THEN 1 ELSE 0
        END AS is_late_date,
        CASE
            WHEN oe.order_delivered_customer_date
               > oe.order_estimated_delivery_date
            THEN 1 ELSE 0
        END AS is_late_ts,
        DATEDIFF(
            DATE(oe.order_delivered_customer_date),
            DATE(oe.order_estimated_delivery_date)
        ) AS days_vs_estimate,
        oe.flag_carrier_before_purchase,
        oe.flag_delivery_before_carrier
    FROM cte_item_to_seller_order AS iso
    INNER JOIN cte_orders_eligible AS oe
        ON oe.order_id = iso.order_id
    INNER JOIN cte_order_n_sellers AS ns
        ON ns.order_id = iso.order_id
    INNER JOIN fulfilliq.raw_sellers AS s
        ON s.seller_id = iso.seller_id
),
cte_seller_order_duration AS (
    SELECT so.seller_id, so.days_vs_estimate, so.is_late_date
    FROM cte_seller_order AS so
    WHERE so.is_sequence_anomaly = 0
),
cte_median_all AS (
    SELECT d.seller_id, AVG(d.days_vs_estimate) AS median_days_vs_estimate
    FROM (
        SELECT
            sod.seller_id,
            sod.days_vs_estimate,
            ROW_NUMBER() OVER (PARTITION BY sod.seller_id ORDER BY sod.days_vs_estimate) AS rn,
            COUNT(*) OVER (PARTITION BY sod.seller_id) AS n
        FROM cte_seller_order_duration AS sod
    ) AS d
    WHERE d.rn IN (FLOOR((d.n + 1) / 2.0), CEIL((d.n + 1) / 2.0))
    GROUP BY d.seller_id
),
cte_median_late AS (
    SELECT d.seller_id, AVG(d.days_vs_estimate) AS median_days_late
    FROM (
        SELECT
            sod.seller_id,
            sod.days_vs_estimate,
            ROW_NUMBER() OVER (PARTITION BY sod.seller_id ORDER BY sod.days_vs_estimate) AS rn,
            COUNT(*) OVER (PARTITION BY sod.seller_id) AS n
        FROM cte_seller_order_duration AS sod
        WHERE sod.is_late_date = 1
    ) AS d
    WHERE d.rn IN (FLOOR((d.n + 1) / 2.0), CEIL((d.n + 1) / 2.0))
    GROUP BY d.seller_id
),
cte_seller_window AS (
    SELECT
        so.seller_id,
        MIN(so.seller_state) AS seller_state,
        MIN(so.seller_city)  AS seller_city,
        COUNT(*) AS eligible_n,
        SUM(so.is_late_date) AS late_n_date,
        SUM(1 - so.is_late_date) AS on_time_n_date,
        SUM(so.is_late_ts) AS late_n_ts,
        SUM(CASE WHEN so.purchase_half = 'jan_apr' THEN 1 ELSE 0 END) AS eligible_n_jan_apr,
        SUM(CASE WHEN so.purchase_half = 'jan_apr' THEN so.is_late_date ELSE 0 END) AS late_n_jan_apr,
        SUM(CASE WHEN so.purchase_half = 'may_aug' THEN 1 ELSE 0 END) AS eligible_n_may_aug,
        SUM(CASE WHEN so.purchase_half = 'may_aug' THEN so.is_late_date ELSE 0 END) AS late_n_may_aug,
        SUM(so.is_single_seller_order) AS eligible_n_single,
        SUM(CASE WHEN so.is_single_seller_order = 1 THEN so.is_late_date ELSE 0 END) AS late_n_single,
        SUM(so.is_multi_seller_order) AS multi_seller_order_n,
        SUM(so.item_price_sum) AS item_revenue,
        SUM(so.item_price_plus_freight_sum) AS item_revenue_plus_freight,
        SUM(so.is_sequence_anomaly) AS anomaly_n,
        CAST(SUM(so.is_late_date) AS DECIMAL(18, 6))
            / NULLIF(CAST(COUNT(*) AS DECIMAL(18, 6)), 0) AS lfr_date,
        CAST(SUM(so.is_late_ts) AS DECIMAL(18, 6))
            / NULLIF(CAST(COUNT(*) AS DECIMAL(18, 6)), 0) AS lfr_timestamp,
        CAST(SUM(CASE WHEN so.purchase_half = 'jan_apr' THEN so.is_late_date ELSE 0 END) AS DECIMAL(18, 6))
            / NULLIF(CAST(SUM(CASE WHEN so.purchase_half = 'jan_apr' THEN 1 ELSE 0 END) AS DECIMAL(18, 6)), 0) AS lfr_jan_apr,
        CAST(SUM(CASE WHEN so.purchase_half = 'may_aug' THEN so.is_late_date ELSE 0 END) AS DECIMAL(18, 6))
            / NULLIF(CAST(SUM(CASE WHEN so.purchase_half = 'may_aug' THEN 1 ELSE 0 END) AS DECIMAL(18, 6)), 0) AS lfr_may_aug,
        CAST(SUM(CASE WHEN so.is_single_seller_order = 1 THEN so.is_late_date ELSE 0 END) AS DECIMAL(18, 6))
            / NULLIF(CAST(SUM(so.is_single_seller_order) AS DECIMAL(18, 6)), 0) AS lfr_single_seller,
        CAST(SUM(so.is_multi_seller_order) AS DECIMAL(18, 6))
            / NULLIF(CAST(COUNT(*) AS DECIMAL(18, 6)), 0) AS multi_seller_order_share
    FROM cte_seller_order AS so
    GROUP BY so.seller_id
),
cte_seller_window_enriched AS (
    SELECT
        sw.*,
        ma.median_days_vs_estimate,
        ml.median_days_late,
        CASE WHEN sw.eligible_n >= 30 THEN 1 ELSE 0 END AS meets_volume_floor,
        CASE
            WHEN sw.eligible_n < 30 THEN 'below_floor'
            WHEN sw.eligible_n < 50 THEN '30_49'
            WHEN sw.eligible_n < 100 THEN '50_99'
            ELSE '100_plus'
        END AS volume_band
    FROM cte_seller_window AS sw
    LEFT JOIN cte_median_all AS ma ON ma.seller_id = sw.seller_id
    LEFT JOIN cte_median_late AS ml ON ml.seller_id = sw.seller_id
),
cte_floor_sellers AS (
    SELECT
        e.seller_id,
        e.eligible_n,
        e.late_n_date,
        e.late_n_ts,
        e.lfr_date,
        e.lfr_timestamp
    FROM cte_seller_window_enriched AS e
    WHERE e.eligible_n >= 30
),
cte_peer_ranks_date AS (
    SELECT
        fs.seller_id,
        fs.lfr_date,
        ROW_NUMBER() OVER (ORDER BY fs.lfr_date ASC, fs.seller_id ASC) AS rn_asc,
        COUNT(*) OVER () AS n_floor_sellers
    FROM cte_floor_sellers AS fs
),
cte_peer_ranks_ts AS (
    SELECT
        fs.seller_id,
        fs.lfr_timestamp,
        ROW_NUMBER() OVER (ORDER BY fs.lfr_timestamp ASC, fs.seller_id ASC) AS rn_asc,
        COUNT(*) OVER () AS n_floor_sellers
    FROM cte_floor_sellers AS fs
),
cte_peer_benchmarks AS (
    SELECT
        COUNT(*) AS n_floor_sellers,
        CAST(SUM(fs.late_n_date) AS DECIMAL(18, 6))
            / NULLIF(CAST(SUM(fs.eligible_n) AS DECIMAL(18, 6)), 0) AS peer_weighted_mkt_lfr,
        AVG(fs.lfr_date) AS peer_equal_wt_lfr,
        MIN(fs.lfr_date) AS peer_min_lfr,
        MAX(fs.lfr_date) AS peer_max_lfr,
        (SELECT pr.lfr_date FROM cte_peer_ranks_date AS pr
          WHERE pr.rn_asc = GREATEST(1, CEIL(0.25 * pr.n_floor_sellers)) LIMIT 1) AS peer_p25_lfr,
        (SELECT pr.lfr_date FROM cte_peer_ranks_date AS pr
          WHERE pr.rn_asc = GREATEST(1, CEIL(0.50 * pr.n_floor_sellers)) LIMIT 1) AS peer_median_lfr,
        (SELECT pr.lfr_date FROM cte_peer_ranks_date AS pr
          WHERE pr.rn_asc = GREATEST(1, CEIL(0.75 * pr.n_floor_sellers)) LIMIT 1) AS peer_p75_lfr,
        (SELECT pr.lfr_date FROM cte_peer_ranks_date AS pr
          WHERE pr.rn_asc = GREATEST(1, CEIL(0.90 * pr.n_floor_sellers)) LIMIT 1) AS peer_p90_lfr,
        (SELECT pr.lfr_date FROM cte_peer_ranks_date AS pr
          WHERE pr.rn_asc = GREATEST(1, CEIL(0.95 * pr.n_floor_sellers)) LIMIT 1) AS peer_p95_lfr,
        CAST(SUM(fs.late_n_ts) AS DECIMAL(18, 6))
            / NULLIF(CAST(SUM(fs.eligible_n) AS DECIMAL(18, 6)), 0) AS peer_weighted_mkt_lfr_ts,
        (SELECT pr.lfr_timestamp FROM cte_peer_ranks_ts AS pr
          WHERE pr.rn_asc = GREATEST(1, CEIL(0.75 * pr.n_floor_sellers)) LIMIT 1) AS peer_p75_lfr_ts
    FROM cte_floor_sellers AS fs
),
cte_seller_screened AS (
    SELECT
        e.*,
        b.n_floor_sellers,
        b.peer_weighted_mkt_lfr,
        b.peer_equal_wt_lfr,
        b.peer_min_lfr,
        b.peer_p25_lfr,
        b.peer_median_lfr,
        b.peer_p75_lfr,
        b.peer_p90_lfr,
        b.peer_p95_lfr,
        b.peer_max_lfr,
        b.peer_weighted_mkt_lfr_ts,
        b.peer_p75_lfr_ts,
        CASE WHEN e.meets_volume_floor = 1
              AND e.lfr_date >= b.peer_p75_lfr
              AND e.lfr_date >  b.peer_weighted_mkt_lfr
             THEN 1 ELSE 0 END AS pass_p75,
        CASE WHEN e.meets_volume_floor = 1
              AND e.lfr_date >= b.peer_p90_lfr
              AND e.lfr_date >  b.peer_weighted_mkt_lfr
             THEN 1 ELSE 0 END AS pass_p90,
        CASE WHEN e.meets_volume_floor = 1
              AND e.lfr_date >= b.peer_p75_lfr
              AND e.lfr_date >  b.peer_weighted_mkt_lfr
              AND (
                    e.eligible_n_single = 0
                 OR e.lfr_single_seller IS NULL
                 OR NOT (e.lfr_single_seller >= b.peer_p75_lfr
                     AND e.lfr_single_seller >  b.peer_weighted_mkt_lfr)
                  )
             THEN 1 ELSE 0 END AS attribution_conflict,
        CASE WHEN e.meets_volume_floor = 1
              AND (
                    (e.lfr_date >= b.peer_p75_lfr AND e.lfr_date > b.peer_weighted_mkt_lfr)
                 XOR
                    (e.lfr_timestamp >= b.peer_p75_lfr_ts AND e.lfr_timestamp > b.peer_weighted_mkt_lfr_ts)
                  )
             THEN 1 ELSE 0 END AS date_ts_action_conflict,
        CASE WHEN e.meets_volume_floor = 1
              AND e.lfr_date >= b.peer_p75_lfr
              AND e.lfr_date >  b.peer_weighted_mkt_lfr
              AND e.eligible_n_jan_apr > 0
              AND e.eligible_n_may_aug > 0
              AND (
                    (e.lfr_jan_apr >= b.peer_p75_lfr
                     AND e.lfr_jan_apr > b.peer_weighted_mkt_lfr
                     AND (e.lfr_may_aug IS NULL OR e.lfr_may_aug <= b.peer_median_lfr))
                 OR (e.lfr_may_aug >= b.peer_p75_lfr
                     AND e.lfr_may_aug > b.peer_weighted_mkt_lfr
                     AND (e.lfr_jan_apr IS NULL OR e.lfr_jan_apr <= b.peer_median_lfr))
                  )
             THEN 1 ELSE 0 END AS split_window_unstable
    FROM cte_seller_window_enriched AS e
    CROSS JOIN cte_peer_benchmarks AS b
),
cte_cap_stats AS (
    SELECT
        SUM(CASE WHEN s.pass_p75 = 1
                  AND s.attribution_conflict = 0
                  AND s.date_ts_action_conflict = 0
                  AND s.split_window_unstable = 0
                 THEN 1 ELSE 0 END) AS n_clean_p75,
        CASE WHEN SUM(CASE WHEN s.pass_p75 = 1
                            AND s.attribution_conflict = 0
                            AND s.date_ts_action_conflict = 0
                            AND s.split_window_unstable = 0
                           THEN 1 ELSE 0 END) > 20
             THEN 1 ELSE 0 END AS raise_bar_to_p90
    FROM cte_seller_screened AS s
)
SELECT
    s.seller_id,
    s.seller_state,
    s.seller_city,
    s.eligible_n,
    s.late_n_date                                              AS late_n,
    s.on_time_n_date,
    s.lfr_date,
    ROUND(100 * s.lfr_date, 1)                                 AS lfr_date_pct,
    CONCAT(CAST(s.late_n_date AS CHAR), ' / ', CAST(s.eligible_n AS CHAR)) AS late_over_eligible,
    s.late_n_ts,
    s.lfr_timestamp,
    ROUND(100 * s.lfr_timestamp, 1)                            AS lfr_timestamp_pct,
    s.median_days_vs_estimate,
    s.median_days_late,
    s.eligible_n_jan_apr,
    s.late_n_jan_apr,
    s.lfr_jan_apr,
    s.eligible_n_may_aug,
    s.late_n_may_aug,
    s.lfr_may_aug,
    s.eligible_n_single,
    s.late_n_single,
    s.lfr_single_seller,
    s.multi_seller_order_n,
    s.multi_seller_order_share,
    s.item_revenue,
    s.item_revenue_plus_freight,
    s.anomaly_n,
    s.meets_volume_floor,
    s.volume_band,
    s.n_floor_sellers,
    s.peer_weighted_mkt_lfr,
    s.peer_equal_wt_lfr,
    s.peer_p25_lfr,
    s.peer_median_lfr,
    s.peer_p75_lfr,
    s.peer_p90_lfr,
    s.peer_p95_lfr,
    s.pass_p75,
    s.pass_p90,
    s.attribution_conflict,
    s.date_ts_action_conflict,
    s.split_window_unstable,
    c.raise_bar_to_p90,
    CASE
        WHEN s.pass_p75 = 1 THEN
            ROW_NUMBER() OVER (
                PARTITION BY CASE WHEN s.pass_p75 = 1 THEN 1 ELSE 0 END
                ORDER BY s.lfr_date DESC, s.late_n_date DESC, s.eligible_n DESC, s.seller_id ASC
            )
        ELSE NULL
    END                                                        AS rank_if_candidate,
    CASE
        WHEN s.meets_volume_floor = 0 THEN 'standard_terms'
        WHEN s.attribution_conflict = 1 OR s.date_ts_action_conflict = 1 THEN 'inconclusive'
        WHEN s.split_window_unstable = 1 THEN 'watch'
        WHEN c.raise_bar_to_p90 = 1 AND s.pass_p90 = 1 THEN 'enroll'
        WHEN c.raise_bar_to_p90 = 1 AND s.pass_p75 = 1 THEN 'watch'
        WHEN c.raise_bar_to_p90 = 0 AND s.pass_p75 = 1 THEN 'enroll'
        ELSE 'standard_terms'
    END                                                        AS action,
    CASE
        WHEN s.meets_volume_floor = 0 THEN 'usable_n_lt_30'
        WHEN s.attribution_conflict = 1 AND s.date_ts_action_conflict = 1
            THEN 'attribution_and_precision_conflict'
        WHEN s.attribution_conflict = 1 THEN 'single_seller_lfr_does_not_support_enroll'
        WHEN s.date_ts_action_conflict = 1 THEN 'date_vs_timestamp_action_conflict'
        WHEN s.split_window_unstable = 1 THEN 'split_window_unstable'
        WHEN c.raise_bar_to_p90 = 1 AND s.pass_p90 = 1 THEN 'p90_and_above_weighted_after_cap'
        WHEN c.raise_bar_to_p90 = 1 AND s.pass_p75 = 1 THEN 'p75_watch_band_after_cap'
        WHEN c.raise_bar_to_p90 = 0 AND s.pass_p75 = 1 THEN 'p75_and_above_weighted'
        ELSE 'at_or_below_peer_bar'
    END                                                        AS action_reason
FROM cte_seller_screened AS s
CROSS JOIN cte_cap_stats AS c
ORDER BY
    CASE
        WHEN s.meets_volume_floor = 0 THEN 'standard_terms'
        WHEN s.attribution_conflict = 1 OR s.date_ts_action_conflict = 1 THEN 'inconclusive'
        WHEN s.split_window_unstable = 1 THEN 'watch'
        WHEN c.raise_bar_to_p90 = 1 AND s.pass_p90 = 1 THEN 'enroll'
        WHEN c.raise_bar_to_p90 = 1 AND s.pass_p75 = 1 THEN 'watch'
        WHEN c.raise_bar_to_p90 = 0 AND s.pass_p75 = 1 THEN 'enroll'
        ELSE 'standard_terms'
    END ASC,
    s.lfr_date DESC,
    s.late_n_date DESC,
    s.eligible_n DESC,
    s.seller_id ASC;

-- End of Stage_04_FulfillIQ_Analysis.sql (not executed in this session).
