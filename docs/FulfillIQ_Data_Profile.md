# FulfillIQ — Data Profile

| Profile attribute | Value |
|---|---|
| Project | FulfillIQ |
| Data layer | Nine raw Brazilian Olist source tables |
| Profile date | 2026-09-02 |
| Intended use | Stage 3 measurement design and Stage 4 SQL/R execution planning |
| Evidence basis | Eight source CSV files, the cleaned order-reviews TSV, and the FulfillIQ Database Context Package |
| Live-database verification | Not performed; source-file results must be reconciled to MySQL before final analysis |
| Overall readiness | **Conditionally ready for Stage 3** |

## Purpose

This document profiles the actual Olist source files used to populate the `fulfilliq` MySQL database. It is the empirical companion to `database_context.md`: the database context describes what the database *is*, while this profile describes what values are actually present and what limitations matter for measurement design.

**Important scope note:** this profile was computed from nine uploaded source datasets—eight CSV files plus `olist_order_reviews_clean.tsv`—not by connecting directly to the live MySQL instance. The uploaded files match the row counts recorded in the Database Context Package. The database load converts blank values to SQL `NULL`. The clean review TSV has one physical line per review record and contains no embedded tabs or line breaks in either review-text field, making it the authoritative review import source for this project. ZIP prefixes were profiled as five-character text so leading zeros are preserved, matching the MySQL `VARCHAR` design.

## Evidence Boundary and Interpretation

This document is a **source-data profile**, not proof that every value in the live MySQL tables is identical to the source files. Its counts and distributions are appropriate for Stage 3 planning because the source-file row counts reconcile to the recorded table counts. Before a final KPI, model, or recommendation is published, the highest-risk results must be reproduced against the live `fulfilliq` database.

Interpret the evidence in three levels:

- **Verified from source files:** row counts, missingness, distinct counts, distributions, duplicate counts, date ranges, and cross-file key coverage reported below.
- **Recorded from the database build:** MySQL schema, table grains, load transformations, and final table counts documented in the Database Context Package.
- **Pending live-database confirmation:** value-level agreement after import, final warning status, SQL-mode effects, and repeatability of all Stage 4 KPI calculations.

No unreported number should be inferred from this profile. A measurement is not approved merely because the required columns exist; its population, grain, exclusions, aggregation rules, and guardrails must be fixed in `stage_03_measurement_design.md`.

## Context Consistency Check

- The Database Context Package lists the correct individual row counts for all nine tables, but its stated grand total of **1,450,922** is an arithmetic error. The nine verified table counts sum to **1,550,922** rows. No table-level count discrepancy was found.
- **Required companion-file correction:** replace `1,450,922` with `1,550,922` wherever the Database Context Package states the grand total. The individual table counts do not need correction.

## 1. Executive Summary

- **9 source tables** profiled, containing **1,550,922 total rows**.
- Order purchase coverage runs from **2016-09-04 21:15:19** to **2018-10-17 17:30:18**.
- `raw_orders`: **99,441 orders**; `order_id` and `customer_id` are both fully populated and unique.
- `raw_order_items`: **112,650 item rows** across **98,666 orders**; all item rows match an order, seller, and product.
- `raw_payments`: **103,886 payment rows** across **99,440 orders**; **2,961 orders (2.98%)** have multiple payment rows.
- `raw_reviews`: **99,224 clean review rows**, but only **98,410 distinct review IDs** and **98,673 distinct reviewed orders**.
- `raw_geolocation`: **1,000,163 rows** but only **19,015 ZIP prefixes**, with **261,831 exact duplicate rows (26.18%)**.
- Referential-integrity checks across the uploaded files found **0 orphan rows** for the main order/customer/item/seller/product/payment/review joins.
- Product category coverage is incomplete: **610 products (1.85%)** have no category; two source categories lack an English translation.
- Seller sample sizes are highly skewed: median seller volume is only **6 delivered orders**; **60.00%** of sellers have fewer than 10 delivered orders and **79.74%** have fewer than 30.
- Several source anomalies require explicit handling before final KPI construction: carrier dates preceding purchase dates, four 2020 shipping-limit timestamps, zero-weight products, zero-value payments, duplicate review IDs, and geolocation coordinate outliers.

## Readiness Decision

**Decision:** The source data is suitable for Stage 3 measurement design and for guarded Stage 4 analysis. It is **not** suitable for unqualified seller ranking, direct many-table aggregation, or ZIP-level geographic measurement without additional rules.

| Quality dimension | Assessment | Evidence | Stage 3 consequence |
|---|---|---|---|
| Completeness | Conditional pass | Core identifiers are complete; delivery timestamps are status-dependent; review text is highly sparse | Define eligible populations by business status; do not treat structurally absent values as ordinary missingness |
| Uniqueness | Conditional pass | Primary/composite keys are unique in the main fact and dimension tables; review IDs and order IDs are not unique in reviews | Specify a review reduction rule before order-level review metrics |
| Referential integrity | Pass for profiled joins | Zero orphans in the six principal parent-child checks | Main joins are usable, but row multiplication must still be controlled |
| Validity | Conditional pass | Non-negative prices/payments, but temporal, zero-value, zero-weight, and coordinate anomalies exist | Add explicit anomaly exclusions or flags rather than silently discarding rows |
| Timeliness and coverage | Conditional pass | Core purchase window is 2016-09-04 through 2018-10-17; edge periods are incomplete | Use complete comparison periods or document partial-period treatment |
| Volume and statistical stability | Conditional pass | Overall volume is strong, but seller-level sample sizes are heavily skewed | Apply a minimum-volume guardrail and report sample size beside seller KPIs |
| Join safety | High-risk without controls | Items, payments, reviews, and geolocation contain repeated join keys | Pre-aggregate every many-side table to the declared analytical grain before combining |

### Highest-priority analytical risks

| Priority | Risk | Severity | Required treatment |
|---:|---|---|---|
| 1 | Many-to-many row multiplication across items, payments, and reviews | Critical | Declare the final grain and aggregate each many-side table before joining |
| 2 | Seller rankings dominated by very small samples | High | Set a minimum delivered-order threshold in Stage 3 and retain the denominator in outputs |
| 3 | Invalid event sequences biasing delivery-duration metrics | High | Flag or exclude the 166 carrier-before-purchase and 23 delivery-before-carrier rows |
| 4 | Incomplete edge periods distorting trends | High | Restrict trend comparisons to complete periods or label partial periods explicitly |
| 5 | Raw geolocation joins multiplying rows and importing coordinate outliers | High | Reduce to one reviewed row per ZIP prefix before any customer/seller join |
| 6 | Duplicate/multiple reviews changing order-level sentiment metrics | Medium | Choose a documented aggregation or selection rule |

## 2. Table-Level Inventory

| Table | Grain | Rows | Full-row duplicates |
|---|---|---:|---:|
| `raw_orders` | One row per order_id | 99,441 | 0 |
| `raw_order_items` | One item sequence within an order; key = (order_id, order_item_id) | 112,650 | 0 |
| `raw_sellers` | One row per seller_id | 3,095 | 0 |
| `raw_customers` | One row per customer_id | 99,441 | 0 |
| `raw_products` | One row per product_id | 32,951 | 0 |
| `raw_payments` | One payment sequence within an order; key = (order_id, payment_sequential) | 103,886 | 0 |
| `raw_reviews` | One source review record; review_id and order_id are not unique | 99,224 | 0 |
| `raw_category_translation` | One source category-translation row | 71 | 0 |
| `raw_geolocation` | One geolocation observation; many rows per ZIP prefix | 1,000,163 | 261,831 |

## 3. Cross-Table Integrity and Coverage

### Referential-integrity checks

| Check | Orphan rows | Result |
|---|---:|---|
| `raw_order_items.order_id` → `raw_orders.order_id` | 0 | PASS |
| `raw_order_items.seller_id` → `raw_sellers.seller_id` | 0 | PASS |
| `raw_order_items.product_id` → `raw_products.product_id` | 0 | PASS |
| `raw_orders.customer_id` → `raw_customers.customer_id` | 0 | PASS |
| `raw_payments.order_id` → `raw_orders.order_id` | 0 | PASS |
| `raw_reviews.order_id` → `raw_orders.order_id` | 0 | PASS |

### Fact-table coverage by order

- **775 orders** have no `raw_order_items` row. Their statuses are: unavailable=603, canceled=164, created=5, invoiced=2, shipped=1.
- **1 order** has no payment row.
- **768 orders** have no review row.

### Geolocation ZIP coverage

- Customer ZIPs found in geolocation: **99,163/99,441 (99.72%)**; **278 customer rows** have ZIP prefixes absent from geolocation.
- Seller ZIPs found in geolocation: **3,088/3,095 (99.77%)**; **7 seller rows** have ZIP prefixes absent from geolocation.

## 4. `raw_orders` Profile

**Rows:** 99,441  
**Distinct `order_id`:** 99,441  
**Distinct `customer_id`:** 99,441  
**Full-row duplicates:** 0

### Order-status distribution

| Status | Orders | Share | Missing customer-delivery date | Missing share within status |
|---|---:|---:|---:|---:|
| `delivered` | 96,478 | 97.02% | 8 | 0.01% |
| `shipped` | 1,107 | 1.11% | 1,107 | 100.00% |
| `canceled` | 625 | 0.63% | 619 | 99.04% |
| `unavailable` | 609 | 0.61% | 609 | 100.00% |
| `invoiced` | 314 | 0.32% | 314 | 100.00% |
| `processing` | 301 | 0.30% | 301 | 100.00% |
| `created` | 5 | 0.01% | 5 | 100.00% |
| `approved` | 2 | 0.00% | 2 | 100.00% |

### Date coverage and missingness

| Field | Minimum | Maximum | Missing | Missing % |
|---|---|---|---:|---:|
| `order_purchase_timestamp` | 2016-09-04 21:15:19 | 2018-10-17 17:30:18 | 0 | 0.00% |
| `order_approved_at` | 2016-09-15 12:16:38 | 2018-09-03 17:40:06 | 160 | 0.16% |
| `order_delivered_carrier_date` | 2016-10-08 10:34:01 | 2018-09-11 19:48:28 | 1,783 | 1.79% |
| `order_delivered_customer_date` | 2016-10-11 13:46:32 | 2018-10-17 13:22:46 | 2,965 | 2.98% |
| `order_estimated_delivery_date` | 2016-09-30 00:00:00 | 2018-11-12 00:00:00 | 0 | 0.00% |

### Purchase-period coverage

- 2016: **329 orders**
- 2017: **45,101 orders**
- 2018: **54,011 orders**
- The first and last calendar periods are partial. September–October 2018 contain only 20 purchase records combined, so those months should not be treated as full comparable months without an explicit time-window rule.

### Delivered-order timing profile (descriptive only; not a finalized KPI)

- Delivered-status orders: **96,478**.
- Delivered orders with both actual and estimated delivery timestamps: **96,470**.
- Using the provisional rule `actual delivery > estimated delivery`, **7,826 (8.11%)** are late.
- Purchase → customer delivery: median **10.22 days**, mean **12.56**, P95 **29.27**, max **209.63**.
- Actual delivery vs estimate: median **-11.95 days** (negative = early), P95 **3.82**, max **188.98**.

### Temporal anomalies

- **166 rows** have carrier handoff timestamps earlier than purchase timestamps.
- **23 rows** have customer delivery earlier than carrier handoff.
- No rows have approval before purchase, customer delivery before purchase, or estimated delivery before purchase among rows where both relevant timestamps are present.
- These anomalous sequences should be excluded or explicitly investigated before timing KPIs are finalized.

## 5. `raw_order_items` Profile

**Rows:** 112,650  
**Distinct orders:** 98,666  
**Distinct products:** 32,951  
**Distinct sellers:** 3,095

### Item-price and freight distributions

| Measure | Min | Median | Mean | P95 | P99 | Max |
|---|---:|---:|---:|---:|---:|---:|
| `price` | 0.85 | 74.99 | 120.65 | 349.90 | 890.00 | 6,735.00 |
| `freight_value` | 0.00 | 16.26 | 19.99 | 45.12 | 84.52 | 409.68 |
| `price + freight_value` | 6.08 | 92.32 | 140.64 | 378.96 | 923.22 | 6,929.31 |

- `price`: **0 negative values**, **0 zero values**.
- `freight_value`: **0 negative values**, **383 zero values**.
- Orders represented in `raw_order_items` have a median of **1 item row**, mean **1.14**, max **21**.
- **9,803 orders (9.94%)** have more than one item row.

### Shipping-limit coverage/anomaly

- `shipping_limit_date` range: **2016-09-19 00:15:34** to **2020-04-09 22:35:08**.
- **4 item rows** have `shipping_limit_date` after 2018-12-31, all in 2020. These are temporal outliers relative to the order-purchase window and should be investigated/excluded for shipping-deadline metrics.

## 6. Seller Volume / Small-Sample Profile

- Sellers: **3,095**.
- Unique orders per seller across item data: median **6**, mean **32.31**, P95 **130.30**, max **1854**.
- Delivered orders per seller: median **6**, mean **31.61**, max **1819**.

| Minimum delivered orders | Sellers meeting threshold | Share of all sellers |
|---:|---:|---:|
| 5 | 1,766 | 57.06% |
| 10 | 1,238 | 40.00% |
| 20 | 804 | 25.98% |
| 30 | 627 | 20.26% |
| 50 | 425 | 13.73% |
| 100 | 210 | 6.79% |

**Measurement implication:** seller-level KPIs need a minimum-volume guardrail. A large majority of sellers have small samples; the threshold belongs in Stage 3 and should not be chosen implicitly inside SQL.

### Seller geography (top 10 states)

| State | Sellers | Share |
|---|---:|---:|
| `SP` | 1,849 | 59.74% |
| `PR` | 349 | 11.28% |
| `MG` | 244 | 7.88% |
| `SC` | 190 | 6.14% |
| `RJ` | 171 | 5.53% |
| `RS` | 129 | 4.17% |
| `GO` | 40 | 1.29% |
| `DF` | 30 | 0.97% |
| `ES` | 23 | 0.74% |
| `BA` | 19 | 0.61% |

## 7. `raw_customers` Profile

- Rows / distinct `customer_id`: **99,441 / 99,441**.
- Distinct `customer_unique_id`: **96,096**.
- Persistent customers with more than one `customer_id`: **2,997 (3.12%)**.
- Maximum number of customer records for one `customer_unique_id`: **17**.
- All customer ZIP prefixes are five characters in the source when read as text; leading zeros must be preserved.

### Customer geography (top 10 states)

| State | Customer rows | Share |
|---|---:|---:|
| `SP` | 41,746 | 41.98% |
| `RJ` | 12,852 | 12.92% |
| `MG` | 11,635 | 11.70% |
| `RS` | 5,466 | 5.50% |
| `PR` | 5,045 | 5.07% |
| `SC` | 3,637 | 3.66% |
| `BA` | 3,380 | 3.40% |
| `DF` | 2,140 | 2.15% |
| `ES` | 2,033 | 2.04% |
| `GO` | 2,020 | 2.03% |

## 8. `raw_products` and Category Profile

- Products: **32,951**, all with unique/non-null `product_id`.
- Missing `product_category_name`: **610 (1.85%)**.
- Product rows with missing name length/description length/photo count: **610 each (1.85%)**.
- Product rows missing weight/length/height/width: **2 each (0.006%)**.
- Products with `product_weight_g = 0`: **4**.

### Product dimensional ranges

| Measure | Min | Median | Mean | P95 | Max |
|---|---:|---:|---:|---:|---:|
| `product_weight_g` | 0.00 | 700.00 | 2,276.47 | 10,850.00 | 40,425.00 |
| `product_length_cm` | 7.00 | 25.00 | 30.82 | 65.00 | 105.00 |
| `product_height_cm` | 2.00 | 13.00 | 16.94 | 44.00 | 105.00 |
| `product_width_cm` | 6.00 | 20.00 | 23.20 | 47.00 | 118.00 |
| `product_photos_qty` | 1.00 | 1.00 | 2.19 | 6.00 | 20.00 |

### Category coverage

- Distinct non-null source product categories: **73**.
- Translation-table categories: **71**.
- Categories without English translation: **`pc_gamer`** and **`portateis_cozinha_e_preparadores_de_alimentos`**.
- Those untranslated categories affect **13 products** and **24 order-item rows**.
- Missing product category affects **1,603 order-item rows (1.42%)** across **1,451 orders**.

### Top product categories by order-item rows

| Source category | Item rows |
|---|---:|
| `cama_mesa_banho` | 11,115 |
| `beleza_saude` | 9,670 |
| `esporte_lazer` | 8,641 |
| `moveis_decoracao` | 8,334 |
| `informatica_acessorios` | 7,827 |
| `utilidades_domesticas` | 6,964 |
| `relogios_presentes` | 5,991 |
| `telefonia` | 4,545 |
| `ferramentas_jardim` | 4,347 |
| `automotivo` | 4,235 |

## 9. `raw_payments` Profile

- Payment rows: **103,886** across **99,440 orders**.
- Orders with multiple payment rows: **2,961 (2.98%)**; maximum payment rows on one order: **29**.

### Payment-type distribution

| Payment type | Rows | Share |
|---|---:|---:|
| `credit_card` | 76,795 | 73.92% |
| `boleto` | 19,784 | 19.04% |
| `voucher` | 5,775 | 5.56% |
| `debit_card` | 1,529 | 1.47% |
| `not_defined` | 3 | 0.00% |

### Payment-value distribution

- `payment_value`: min **0.00**, median **100.00**, mean **154.10**, P95 **437.63**, P99 **1,039.92**, max **13,664.08**.
- **9 zero-value payment rows**; no negative payment values.
- `payment_installments`: min **0**, median **1**, max **24**.
- **2 payment rows** have `payment_installments = 0`; **3 rows** use `payment_type = 'not_defined'`.

**Grain warning:** never sum `payment_value` after directly joining payments to item-level rows unless payments have first been aggregated to the intended order grain.

## 10. `raw_reviews` Profile

**Authoritative source:** `olist_order_reviews_clean.tsv`

- Review rows: **99,224**.
- Distinct `review_id`: **98,410**.
- Distinct `order_id`: **98,673**.
- Review IDs appearing more than once: **789**; extra rows beyond one-per-review-ID: **814**; max occurrences of one review ID: **3**.
- Orders with multiple review rows: **547 (0.55%)**; max reviews on one order: **3**.

### Missing review text

- `review_comment_title`: **87,658 missing (88.34%)**.
- `review_comment_message`: **58,274 missing (58.73%)**.
- Review IDs, order IDs, scores, creation dates, and answer timestamps have no missing values in the clean review file.

### Review-score distribution

| Score | Reviews | Share |
|---:|---:|---:|
| 1 | 11,424 | 11.51% |
| 2 | 3,151 | 3.18% |
| 3 | 8,179 | 8.24% |
| 4 | 19,142 | 19.29% |
| 5 | 57,328 | 57.78% |

- Mean review score: **4.09**; median: **5**.
- Review creation range: **2016-10-02 00:00:00** to **2018-08-31 00:00:00**.
- Review answer range: **2016-10-07 18:32:28** to **2018-10-29 12:27:35**.
- Creation → answer lag: median **40.20 hours**, P95 **167.33 hours**, max **12,448.78 hours**; no negative lags.

### Clean-file validation and import contract

- The TSV contains **7 columns** and **99,224 data records**.
- Every physical data line contains exactly **6 tab delimiters**; no malformed-width records were found.
- Neither review-text field contains embedded tabs, carriage returns, or line breaks.
- The file contains **0 exact duplicate rows**.
- Literal quotation marks remain inside some review text. The TSV must therefore be read as a tab-delimited file with quotation handling disabled; treating quotation marks as field wrappers incorrectly merges records and produces a false row count.
- Blank title and message fields should be converted to SQL `NULL` during the database load.

**Interpretation:** cleaning changed the representation and missingness of the two optional text fields, not the score, key, or timestamp distributions used for the core Stage 3 review KPI design. The clean TSV is the required source for all future review imports and reproducibility checks.

## 11. `raw_category_translation` Profile

- Rows: **71**.
- Distinct Portuguese category names: **71**.
- Distinct English category names: **71**.
- Missing values: **0**.
- Full-row duplicates: **0**.
- The translation table covers 71 of the 73 non-null categories present in `raw_products`.

## 12. `raw_geolocation` Profile

- Rows: **1,000,163**.
- Distinct ZIP prefixes: **19,015**.
- Exact duplicate rows: **261,831 (26.18%)**.
- ZIP prefixes with more than one geolocation row: **17,972 (94.51%)**.
- Median rows per ZIP prefix: **29**; mean **52.60**; P95 **180**; max **1146**.
- All geolocation ZIP prefixes are five characters in the source when read as text; leading zeros must be preserved.

### Coordinate ranges

- Latitude: min **-36.605374**, median **-22.919377**, max **45.065933**.
- Longitude: min **-101.466766**, median **-46.637879**, max **121.105394**.
- All coordinates are within globally valid latitude/longitude bounds, but extreme values such as positive latitudes above 40 and longitude above 120 are far from the central distribution and should be treated as source outliers until validated.

**Join warning:** do not directly join raw geolocation to customers or sellers for ordinary analytical aggregation. First reduce geolocation to one row per ZIP prefix using an explicit rule.

## 13. Known Data Issues / Decisions for Stage 3

1. **Partial time coverage:** early 2016 and late 2018 are incomplete. Any trend/comparison window must explicitly choose complete periods.
2. **Order-state dependence:** missing delivery timestamps are overwhelmingly concentrated in non-delivered statuses. Delivery KPIs should define the eligible population rather than treating all orders as missing-data failures.
3. **Temporal anomalies:** 166 carrier dates precede purchase dates and 23 customer-delivery dates precede carrier dates. Timing metrics need an exclusion/validation rule.
4. **Seller small samples:** most sellers have very few delivered orders. Seller comparisons require a minimum-order guardrail.
5. **Many-side inflation risk:** items, payments, and reviews can each have multiple rows per order. Aggregate to the target grain before combining.
6. **Review duplication:** review IDs are not unique and some orders have multiple reviews. Define a review-selection/aggregation rule if an order-level review metric is needed.
7. **Category incompleteness:** 610 products have no category, and two categories lack English translations.
8. **Geolocation duplication/outliers:** geolocation is highly duplicated by ZIP and contains coordinate outliers. Deduplicate/aggregate before use.
9. **Payment anomalies:** 9 zero-value payment rows, 2 zero-installment rows, and 3 `not_defined` payment-type rows.
10. **Product anomalies:** 4 products have zero weight; 2 products lack physical dimensions/weight.
11. **Shipping-limit outliers:** 4 item rows have 2020 shipping-limit dates despite purchase data ending in 2018.

## 14. Measurement-Design Readiness

The files are sufficient to support Stage 3 design, but the final measurement specification should explicitly decide:

- eligible order statuses;
- analysis time window and whether partial edge months are excluded;
- whether delivery lateness is defined at date or timestamp precision;
- seller minimum-volume guardrail;
- how duplicate/multiple reviews are reduced to the analytical grain;
- whether payment metrics are aggregated separately at order grain;
- how missing/untranslated product categories are labeled;
- whether geolocation is needed and, if so, the one-row-per-ZIP aggregation rule;
- which temporal anomalies are excluded from duration calculations.

### Stage 3 decisions that must be locked before final SQL

| Design element | Required decision | Why the profile cannot decide it automatically |
|---|---|---|
| Business outcome | Name the decision the metric will support | Column availability does not determine business value |
| Analytical grain | Order, seller-order, item, customer, seller-period, or another declared grain | Different fact tables repeat `order_id` at different rates |
| Eligible population | Define included statuses and required timestamps | Missing delivery fields are expected for most non-delivered orders |
| Time window | Choose complete periods and comparison baseline | The first and last source periods are partial |
| Primary KPI | Define numerator, denominator, units, and direction | A column name is not a complete metric definition |
| Driver metrics | Select factors that explain movement in the primary KPI | Drivers must follow the causal/business hypothesis |
| Guardrails | Set sample-size and unintended-harm protections | Seller volume is highly skewed and single-metric optimization can mislead |
| Review handling | Select, aggregate, or retain multiple reviews | Neither `review_id` nor `order_id` is unique in `raw_reviews` |
| Geography handling | Decide whether state/city is sufficient or ZIP coordinates are necessary | Raw geolocation is duplicated and contains outliers |
| Anomaly policy | Flag, exclude, winsorize, or separately report invalid/extreme values | Statistical treatment depends on the intended decision and metric |
| Decision rule | Define what result supports each available action | Statistical significance alone does not specify the business action |

### Recommended provisional rules for the first Stage 3 draft

These are starting positions, not final business decisions:

- Use **delivered orders with non-null actual and estimated delivery timestamps** for the first delivery-performance population.
- Define provisional lateness as `order_delivered_customer_date > order_estimated_delivery_date`, while Stage 3 decides whether timestamp or calendar-date precision is appropriate.
- Build delivery analysis at **one row per seller-order**, after consolidating item-level seller participation.
- Exclude or separately flag impossible event sequences from duration calculations; retain their counts in QA reporting.
- Require a minimum seller-order denominator before ranking sellers. The threshold must be chosen in Stage 3; the profile shows that 10, 20, 30, 50, and 100 orders produce materially different seller coverage.
- Aggregate payments and reviews to order grain before joining them to an order- or seller-order-level analytical dataset.
- Prefer state/city geography initially. Use ZIP coordinates only if the business question requires distance or local geography and a reviewed one-row-per-ZIP reference has been created.

## Recommended Stage 4 QA Gates

The following assertions should run against MySQL before the analytical dataset is released to R. A failed critical gate should halt execution rather than produce a report.

| Gate | Expected result | Severity if failed |
|---|---:|---|
| `raw_orders.order_id` uniqueness | 0 duplicate keys | Critical |
| `raw_order_items(order_id, order_item_id)` uniqueness | 0 duplicate composite keys | Critical |
| `raw_payments(order_id, payment_sequential)` uniqueness | 0 duplicate composite keys | Critical |
| Required parent-key orphans for items/customers/payments/reviews | 0 for the six profiled relationships | Critical |
| Negative `price`, `freight_value`, or `payment_value` | 0 rows | High |
| Row counts by raw table | Reconcile to the nine source counts in this profile | Critical |
| Final analytical-grain uniqueness | 0 duplicates at the Stage 3 grain | Critical |
| Join-expansion reconciliation | Row counts and totals reconcile before and after each join | Critical |
| Delivery KPI population | Denominator equals the documented eligible population | High |
| Invalid delivery event sequences | Flagged/excluded count reconciles to the chosen policy | High |
| Seller denominator | Present and above the approved minimum for ranked outputs | High |
| Partial-period treatment | Edge periods excluded or explicitly labeled | High |
| Category translation fallback | Untranslated/missing categories retained under documented labels | Medium |
| Geolocation reduction | At most one reviewed row per ZIP prefix before joining | Critical when geography is used |

### Live-database reconciliation requirement

Before Stage 4 is considered complete, reproduce at least these profile anchors directly in MySQL:

1. all nine table row counts and their corrected total of **1,550,922**;
2. primary/composite-key uniqueness;
3. six principal orphan checks;
4. order-status distribution and delivery-field missingness;
5. delivered-order KPI eligibility count;
6. seller delivered-order distribution and selected minimum-volume threshold;
7. review duplication counts;
8. geolocation ZIP multiplicity;
9. any anomaly count used as an exclusion or guardrail.

If the live-database result differs from this source profile, the MySQL result controls the Stage 4 analysis only after the difference is explained and documented.

## 15. Column-Level Missingness and Cardinality Appendix

Values below are computed from the uploaded source files; blank source values correspond to SQL `NULL` in the loaded database.

### `raw_orders`

| Column | Missing | Missing % | Distinct non-null |
|---|---:|---:|---:|
| `order_id` | 0 | 0.00% | 99,441 |
| `customer_id` | 0 | 0.00% | 99,441 |
| `order_status` | 0 | 0.00% | 8 |
| `order_purchase_timestamp` | 0 | 0.00% | 98,875 |
| `order_approved_at` | 160 | 0.16% | 90,733 |
| `order_delivered_carrier_date` | 1,783 | 1.79% | 81,018 |
| `order_delivered_customer_date` | 2,965 | 2.98% | 95,664 |
| `order_estimated_delivery_date` | 0 | 0.00% | 459 |

### `raw_order_items`

| Column | Missing | Missing % | Distinct non-null |
|---|---:|---:|---:|
| `order_id` | 0 | 0.00% | 98,666 |
| `order_item_id` | 0 | 0.00% | 21 |
| `product_id` | 0 | 0.00% | 32,951 |
| `seller_id` | 0 | 0.00% | 3,095 |
| `shipping_limit_date` | 0 | 0.00% | 93,318 |
| `price` | 0 | 0.00% | 5,968 |
| `freight_value` | 0 | 0.00% | 6,999 |

### `raw_sellers`

| Column | Missing | Missing % | Distinct non-null |
|---|---:|---:|---:|
| `seller_id` | 0 | 0.00% | 3,095 |
| `seller_zip_code_prefix` | 0 | 0.00% | 2,246 |
| `seller_city` | 0 | 0.00% | 611 |
| `seller_state` | 0 | 0.00% | 23 |

### `raw_customers`

| Column | Missing | Missing % | Distinct non-null |
|---|---:|---:|---:|
| `customer_id` | 0 | 0.00% | 99,441 |
| `customer_unique_id` | 0 | 0.00% | 96,096 |
| `customer_zip_code_prefix` | 0 | 0.00% | 14,994 |
| `customer_city` | 0 | 0.00% | 4,119 |
| `customer_state` | 0 | 0.00% | 27 |

### `raw_products`

| Column | Missing | Missing % | Distinct non-null |
|---|---:|---:|---:|
| `product_id` | 0 | 0.00% | 32,951 |
| `product_category_name` | 610 | 1.85% | 73 |
| `product_name_lenght` | 610 | 1.85% | 66 |
| `product_description_lenght` | 610 | 1.85% | 2,960 |
| `product_photos_qty` | 610 | 1.85% | 19 |
| `product_weight_g` | 2 | 0.01% | 2,204 |
| `product_length_cm` | 2 | 0.01% | 99 |
| `product_height_cm` | 2 | 0.01% | 102 |
| `product_width_cm` | 2 | 0.01% | 95 |

### `raw_payments`

| Column | Missing | Missing % | Distinct non-null |
|---|---:|---:|---:|
| `order_id` | 0 | 0.00% | 99,440 |
| `payment_sequential` | 0 | 0.00% | 29 |
| `payment_type` | 0 | 0.00% | 5 |
| `payment_installments` | 0 | 0.00% | 24 |
| `payment_value` | 0 | 0.00% | 29,077 |

### `raw_reviews`

| Column | Missing | Missing % | Distinct non-null |
|---|---:|---:|---:|
| `review_id` | 0 | 0.00% | 98,410 |
| `order_id` | 0 | 0.00% | 98,673 |
| `review_score` | 0 | 0.00% | 5 |
| `review_comment_title` | 87,658 | 88.34% | 4,178 |
| `review_comment_message` | 58,274 | 58.73% | 35,616 |
| `review_creation_date` | 0 | 0.00% | 636 |
| `review_answer_timestamp` | 0 | 0.00% | 98,248 |

### `raw_category_translation`

| Column | Missing | Missing % | Distinct non-null |
|---|---:|---:|---:|
| `product_category_name` | 0 | 0.00% | 71 |
| `product_category_name_english` | 0 | 0.00% | 71 |

### `raw_geolocation`

| Column | Missing | Missing % | Distinct non-null |
|---|---:|---:|---:|
| `geolocation_zip_code_prefix` | 0 | 0.00% | 19,015 |
| `geolocation_lat` | 0 | 0.00% | 717,360 |
| `geolocation_lng` | 0 | 0.00% | 717,613 |
| `geolocation_city` | 0 | 0.00% | 8,011 |
| `geolocation_state` | 0 | 0.00% | 27 |

## 16. Source Files Profiled

- `olist_orders_dataset.csv` → `raw_orders`
- `olist_order_items_dataset.csv` → `raw_order_items`
- `olist_sellers_dataset(1).csv` → `raw_sellers`
- `olist_customers_dataset(1).csv` → `raw_customers`
- `olist_products_dataset(1).csv` → `raw_products`
- `olist_order_payments_dataset.csv` → `raw_payments`
- `olist_order_reviews_clean.tsv` → `raw_reviews` (**authoritative cleaned review source**)
- `product_category_name_translation(1).csv` → `raw_category_translation`
- `olist_geolocation_dataset.csv` → `raw_geolocation`
- `FulfillIQ_Database_Context_Package(2).md` supplied the confirmed MySQL table-grain/load context.

---

## Stage 3 Handoff Summary

**Strongly supported measurements:** order counts, item prices/freight, seller/order volume, delivered-order timing, payment behavior, review scores, product categories, customer/seller geography at state/city level.

**Measurements requiring explicit guardrails:** seller-level performance (small samples), delivery timing (temporal anomalies and status eligibility), review-based KPIs (duplicate/multiple reviews), geography using ZIP coordinates (many geolocation rows per ZIP and coordinate outliers), and any query combining items/payments/reviews (row multiplication risk).

**Profile conclusion:** the dataset is analytically usable and ready to inform `stage_03_measurement_design.md`, but only conditionally. Stage 3 must encode population, grain, sample-size, time-window, duplicate-handling, anomaly-handling, comparison, guardrail, and decision rules before final execution SQL is written.

## Completion Statement

This file is complete as the **source-file baseline data profile** for FulfillIQ. It should now travel with:

- `stages_01_02_dialogue.md` — decision and framing provenance;
- `database_context.md` — MySQL structure, grains, keys, and joins;
- `stage_03_measurement_design.md` — final hypothesis, KPI system, metric contracts, segments, confounders, guardrails, and decision rules;
- `data_profile.md` — this empirical baseline and its quality constraints.

Completion of this profile does **not** eliminate the Stage 4 live-database QA gate. It establishes what must be reproduced, reconciled, and enforced when the final MySQL query and R workflow are executed.
