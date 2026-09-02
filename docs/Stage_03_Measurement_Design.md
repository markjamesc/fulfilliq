# FulfillIQ — Stage 3 Measurement Design

## Source Documents

All three GitHub files were retrieved on 2026-09-02 via `gh api` (bytes and SHA below) and read in full before measurement design. None were invented.

| File | GitHub URL | Bytes | SHA |
| ---- | ---------- | ----: | --- |
| Stages 1–2 Dialogue and Handoff | https://github.com/markjamesc/fulfilliq/blob/main/docs/Stages_01_02_Dialogue_and_Handoff.md | 17,498 | `9a333ed55415b44ca743c9b78dee44c8e5d7835a` |
| Database Context Package | https://github.com/markjamesc/fulfilliq/blob/main/docs/FulfillIQ_Database_Context_Package.md | 41,617 | `ec6274a0191cffe15238147a4bc2c3491defa0ea` |
| Data Profile | https://github.com/markjamesc/fulfilliq/blob/main/docs/FulfillIQ_Data_Profile.md | 34,149 | `bebb1727778b53276f7e6b136913835698eeb67b` |

Round 1 independent designs: Grok, ChatGPT, and DeepSeek each received the same three files plus Round 1 instructions. Round 2 cross-review was run on those designs. Final choices below were resolved from the three source files, not by majority vote.

**Confirmed reviewed:** all three source files. **Not begun:** Stage 4 SQL, R, live MySQL queries.

---

## Approved Business Decision

Maya, as Director of Marketplace Seller Operations, will decide by 18 September 2026 which sellers in the FulfillIQ Olist Brazil database, if any, to enroll in a 30-day late-fulfillment performance plan rather than leave on standard terms. The list must be informed by delivered orders those sellers fulfilled with `order_purchase_timestamp` from 1 January 2018 through 31 August 2018. The purpose is to reduce late customer deliveries before the VP meeting, without penalizing sellers whose volume is too small or whose orders never delivered. Featured-placement and plan administration are operations outside the database. Offboarding remains a later VP recommendation, not this decision.

Copied from the Stages 1–2 handoff. Not rewritten.

## Approved Analytical Framing Question

Among sellers in the FulfillIQ Olist Brazil database who fulfilled delivered orders with purchase timestamps from 1 January 2018 through 31 August 2018, which sellers show late-fulfillment performance that would support Maya’s decision to enroll them in a 30-day performance plan, rather than leave them on standard terms?

Copied from the Stages 1–2 handoff. Not rewritten.

## Business Constraints and Decision Authority

**Decision owner:** Maya Chen, Director of Marketplace Seller Operations (fictional). Deadline 18 September 2026.

**Actions Maya can take:** leave on standard terms / monitor; enroll in the 30-day plan; change featured placement as an operations step outside the tables; ask account management to call; recommend offboarding to the VP.

**Actions she cannot take:** terminate contracts; change fees; add capacity; enroll more than about 20 sellers at once; invent a US or 2026 extract.

**Confirmed constraints (Maya / handoff):** delivered orders only; purchases 2018-01-01 through 2018-08-31; all `seller_state` values; no primary use of reviews, payments, categories, or raw geolocation; ~20 enrollment cap; no extra budget; VP-defensible evidence; show the denominator; 95% is not approved; the Data Profile’s 8.11% late share is descriptive only.

**Accepted provisional assumption:** a seller needs at least 30 delivered orders in that window to be considered. Not an SLA. Median seller volume in the full extract is 6.

**Open from Stages 1–2 (still not silently closed as business locks):** official late/on-time percent; timestamp vs calendar-date precision; customer-delivery vs estimate vs shipping-limit as the lateness clock; treatment of 8 delivered orders missing customer-delivery dates; 166 carrier-before-purchase and 23 delivery-before-carrier rows; 4 item rows with 2020 shipping-limit dates; exact grain as a *Maya* lock; live MySQL vs source-file profile.

Stage 3 below sets **working defaults** for those open items so Stage 4 can run. Each default is labeled. If Stage 4 list membership is sensitive to a default, Maya must choose before enrollment.

## Measurement Scope and Analytical Grain

**Time window:** `order_purchase_timestamp >= 2018-01-01 00:00:00` and `< 2018-09-01 00:00:00` (keeps all of 31 August). Purchase time defines membership, not delivery time. An 31 August purchase delivered in September stays in if it is delivered. **Confirmed by Maya.**

**Order status:** `order_status = 'delivered'` only. **Confirmed by Maya.** Non-delivered missing delivery dates are structural, not ordinary missingness, and are not scored late.

**Geography:** all sellers in `raw_sellers`. Attributes `seller_state` and `seller_city` may be attached. Raw `raw_geolocation` is unused.

**Working grain (Stage 3 design choice, not Confirmed by Maya):**

| Layer | One record | Use |
| ----- | ---------- | --- |
| Item | `(order_id, order_item_id)` | Source of `seller_id`, `price`, `freight_value`, `shipping_limit_date`. Collapse immediately. |
| Seller-order | `(seller_id, order_id)` | Lateness flag, durations, anomaly flags. **Working grain for the primary KPI build.** |
| Seller-window | `seller_id` in Jan–Aug 2018 | Decision grain: rate, denominator, ranking, enrollment recommendation. |

**Why this grain (source-file evidence):** `raw_orders` is one row per order; customer delivery exists once per order. `raw_order_items` is one row per item and is the only path to `seller_id`. Counting items as deliveries would multiply the same late/on-time flag. The Data Profile lists many-side fan-out as the highest-priority risk and recommends one row per seller-order after consolidating items. DeepSeek labeled this grain “Confirmed by Maya”; Maya did not confirm a grain. The label here is **Stage 3 design choice**.

**Attribution limit:** if two sellers share an order, both inherit the same `order_delivered_customer_date` and `order_estimated_delivery_date`. The database cannot split who made the order late. Keep a multi-seller flag and a single-seller-only late rate.

**Eligible orders:** delivered; purchase in window; at least one `raw_order_items` row; both `order_delivered_customer_date` and `order_estimated_delivery_date` non-null.

**Eligible seller-orders:** parent order eligible; `seller_id` present and matches `raw_sellers`.

**Enrollment-eligible sellers:** ≥30 *usable* seller-orders in the primary-KPI denominator after required exclusions. **Accepted provisional assumption.** Applying the floor to the post-exclusion denominator is a Stage 3 tightening of Maya’s “30 delivered orders” so the 30 is the n that actually supports the rate. **Needs Maya’s confirmation if she meant 30 before exclusions.**

**Out of population:** non-delivered statuses; purchases outside the window; 2016 and Sep–Oct 2018; 775 orders with no items (full extract); sellers who only appear on ineligible orders.

## Hypothesis

**Business hypothesis:** Among sellers who meet the approved window, delivered-only rule, and provisional volume floor, some sellers show a late-fulfillment *pattern* on customer delivery versus the promised estimate that is worse than same-window eligible peers, stable enough not to be a one-half spike, and not an artifact of grain or timestamp anomalies. Those sellers are the ones whose enrollment in the 30-day plan is supported.

**Null (operational, not a p-value):** after grain control, exclusions, and guardrails, no seller presents a VP-defensible enrollment case inside the ~20-plan cap. Maya leaves them on standard terms.

**Expected relationship:** higher seller late-fulfillment rate (and, among lates, longer delay versus estimate) is more support for enrollment, subject to guardrails. The unit compared is the seller, built from seller-orders.

**Evidence that supports enrollment:** volume floor met; late-fulfillment rate above the Stage 4 peer bar defined in Decision Rules; pattern not only one half-window; not driven only by excluded anomalies; single-seller subset does not reverse the call; operable list respects the ~20 cap.

**Evidence that fails to support it:** n < 30; rate at or below the peer bar; high rate only on rows the anomaly policy removes; high rate only on multi-seller orders while single-seller rate is ordinary.

**Inconclusive:** n barely at 30 with a rate that sits on the peer bar; date-precision vs timestamp-precision would change the action; live MySQL fails a critical QA gate; more than ~20 sellers clear every bar (return a ranked shortlist plus a watch band, do not expand the roster).

This hypothesis does **not** claim the seller is the sole cause of delay (carrier, address, and estimate-setting are not in `raw_sellers`).

## KPI Framework

| Role | Name | Direction | Threshold status |
| ---- | ---- | --------- | ---------------- |
| Primary | Seller Late-Fulfillment Rate (LFR) | Higher is worse | No signed percent. Peer bar is data-derived in Stage 4. |
| Supporting | Eligible volume; late count; on-time count; median days vs estimate; median days late among lates; split-window LFR; single-seller LFR; multi-seller order share; seller item revenue (`price`); seller state | Context and narrative | No approved numeric cuts except the volume floor |
| Guardrail | Volume floor; staffing cap; always print `late_n / eligible_n`; anomaly concentration; split-window stability; attribution contamination; live-DB reconciliation; no 95% back-door | Permit / block / downgrade | Floor = provisional; cap = confirmed |

Ship-limit miss rate (carrier date vs `shipping_limit_date`) is a **diagnostic only**, not a supporting reason to enroll. Reviews, payments, and categories are unused.

## Metric Contracts

### Seller Late-Fulfillment Rate (primary)

| Field | Definition |
| ----- | ---------- |
| Metric name | Seller Late-Fulfillment Rate (LFR) |
| Metric type | Primary |
| Business purpose | Answers which in-scope sellers show late-fulfillment performance that would support enrollment vs standard terms |
| Analytical grain | One seller-order for the flag; one seller-window for the rate |
| Eligible population | Enrollment-eligible sellers’ usable seller-orders (delivered, window, both delivery timestamps, parent order has items) |
| Numerator | Count of those seller-orders classified late |
| Denominator | Count of those seller-orders |
| Formula | LFR = late seller-orders ÷ eligible seller-orders. Report as percent to one decimal **and** as `late_n / eligible_n` |
| Source tables | `raw_orders`, `raw_order_items`, `raw_sellers` |
| Source columns | `order_id`, `order_status`, `order_purchase_timestamp`, `order_delivered_customer_date`, `order_estimated_delivery_date`, `order_item_id`, `seller_id`, `seller_state` |
| Time window | Purchases 2018-01-01 through 2018-08-31 |
| Exclusions | Non-delivered; outside window; no items; null actual or estimate; `seller_id` not in `raw_sellers` |
| Duplicate handling | Collapse items to one `(seller_id, order_id)` before counting. An order with two sellers yields two seller-orders, each with the same late flag |
| Missing-value handling | Null actual or estimate → not in LFR; counted in QA |
| Directionality | Higher is worse |
| Threshold status | **Still unresolved** as a business percent. Working lateness rule below. Peer bar **data-derived in Stage 4**. 95% and 8.11% **not used** |
| Decision use | Rank and screen candidates; does not by itself enroll |
| Known limitation | Shared order clock on multi-seller orders; estimate-setting is not a seller column |

**Working lateness rule (recommended default, not a Maya lock):** late if and only if `DATE(order_delivered_customer_date) > DATE(order_estimated_delivery_date)`. Evidence: in the Data Profile, `order_estimated_delivery_date` min/max are at 00:00:00, i.e. a calendar promise. Timestamp comparison would treat a same-day afternoon delivery as late against midnight. **Still unresolved** as a business lock. Stage 4 **must** also compute the timestamp twin. If list membership flips, stop and ask Maya. This is **not** adoption of the profile’s 8.11% full-extract figure.

### Eligible volume (supporting / guardrail input)

| Field | Definition |
| ----- | ---------- |
| Metric name | Eligible seller-order volume |
| Metric type | Supporting and guardrail input |
| Business purpose | Maya required a volume floor and the denominator beside every rate |
| Analytical grain | Seller-window |
| Eligible population | Same as LFR denominator |
| Numerator | n/a |
| Denominator | n/a |
| Formula | Count of usable seller-orders |
| Source tables | `raw_orders`, `raw_order_items` |
| Source columns | `order_id`, `seller_id`, plus LFR eligibility columns |
| Time window | Same |
| Exclusions | Same as LFR |
| Duplicate handling | Distinct `(seller_id, order_id)` |
| Missing-value handling | Same as LFR |
| Directionality | Higher is more stable evidence, not “better fulfillment” |
| Threshold status | ≥30 **Accepted provisional assumption** on the post-exclusion denominator |
| Decision use | Below 30 → standard terms / monitor, not ranked |
| Known limitation | Full-extract “627 sellers at 30 orders” is **not** the expected Jan–Aug 2018 count |

### Late count (supporting)

| Field | Definition |
| ----- | ---------- |
| Metric name | Late seller-order count |
| Metric type | Supporting |
| Business purpose | Distinguishes 40% of 30 from 40% of 400 |
| Analytical grain | Seller-window |
| Eligible population | Same as LFR |
| Numerator | Same as LFR numerator |
| Denominator | n/a |
| Formula | Count of late seller-orders |
| Source tables / columns | Same as LFR |
| Time window | Same |
| Exclusions / duplicates / missing | Same as LFR |
| Directionality | Higher is worse, given volume |
| Threshold status | Recommended hygiene of ≥5 lates before auto-enroll is **Still unresolved**; not a Maya number |
| Decision use | Tie-break after LFR |
| Known limitation | None beyond LFR |

### Median calendar days versus estimate (supporting)

| Field | Definition |
| ----- | ---------- |
| Metric name | Median days vs estimate |
| Metric type | Supporting |
| Business purpose | Severity: often a little late vs systematically far past the promise |
| Analytical grain | Seller-order then seller median |
| Eligible population | LFR seller-orders that pass duration screens in the anomaly rules |
| Numerator / denominator | n/a |
| Formula | Median of `DATE(actual) − DATE(estimate)` in days (negative = early). Also report median on the late subset only |
| Source tables | `raw_orders`, `raw_order_items` |
| Source columns | `order_delivered_customer_date`, `order_estimated_delivery_date`, `seller_id`, `order_id` |
| Time window | Same |
| Exclusions | Duration metrics additionally park 166 carrier-before-purchase and 23 delivery-before-carrier rows (full-extract counts; live DB may differ) |
| Duplicate handling | Seller-order grain |
| Missing-value handling | Same as LFR |
| Directionality | For the late subset, higher (more days late) is worse |
| Threshold status | Cuts such as 7-day “severe” are **Still unresolved**; diagnostic only |
| Decision use | Narrative and tie-break; cannot enroll by itself |
| Known limitation | Calendar subtraction follows the working date rule |

### Split-window LFR (supporting / guardrail)

| Field | Definition |
| ----- | ---------- |
| Metric name | Split-window LFR (Jan–Apr vs May–Aug 2018) |
| Metric type | Supporting and guardrail |
| Business purpose | Maya wanted a pattern, not a one-month spike |
| Analytical grain | Seller-window halves, purchase date |
| Eligible population | Same seller-orders, split by purchase in Jan–Apr vs May–Aug 2018 |
| Numerator / denominator | LFR in each half |
| Formula | Same LFR formula per half |
| Source tables / columns | Same as LFR plus purchase timestamp |
| Time window | Inside the approved window only |
| Exclusions | Same as LFR |
| Duplicate handling | Same |
| Missing-value handling | Same |
| Directionality | Same |
| Threshold status | Recommended default: if only one half is above the peer bar and the other is at or below eligible-seller median, mark watch / inconclusive. **Still unresolved** as a hard Maya rule |
| Decision use | Blocks auto-enroll when unstable |
| Known limitation | Halves are unequal in calendar length (4 vs 4 months; OK) but volume per half may be thin |

### Single-seller LFR (supporting / guardrail)

| Field | Definition |
| ----- | ---------- |
| Metric name | Single-seller LFR |
| Metric type | Supporting and guardrail |
| Business purpose | Tests whether the late pattern survives when the order clock is not shared |
| Analytical grain | Seller-order restricted to orders with exactly one distinct `seller_id` |
| Eligible population | Subset of LFR seller-orders |
| Formula | LFR on that subset |
| Source tables / columns | Same plus count of distinct sellers per `order_id` from items |
| Time window | Same |
| Exclusions | Multi-seller orders out of this metric only |
| Duplicate handling | Same collapse |
| Missing-value handling | Same |
| Directionality | Higher is worse |
| Threshold status | No numeric share cut is confirmed. If all-order LFR would enroll and single-seller LFR would not, **inconclusive / Maya review** |
| Decision use | Blocks auto-enroll when attribution is the whole story |
| Known limitation | Some sellers may have few single-seller orders |

### Seller item revenue (supporting)

| Field | Definition |
| ----- | ---------- |
| Metric name | Seller item revenue in window |
| Metric type | Supporting |
| Business purpose | Maya worried about cutting GMV. Print exposure. Do not auto-exclude high-revenue sellers |
| Analytical grain | Seller-window |
| Formula | Sum of `raw_order_items.price` on that seller’s items on eligible orders (optionally `price + freight_value` as a second column) |
| Source tables | `raw_order_items`, filtered to eligible orders |
| Source columns | `price`, `freight_value`, `seller_id`, `order_id` |
| Time window | Same |
| Exclusions | Same eligible orders; do **not** join `raw_payments` |
| Duplicate handling | Sum at item grain, then seller. Payments unused so no payment fan-out |
| Missing-value handling | Profile: price has 0 nulls in source |
| Directionality | Not better/worse for fulfillment |
| Threshold status | No kill-rule |
| Decision use | Eyes-open before enrollment; AM call is available |
| Known limitation | Not GMV from `payment_value` |

### Guardrail contracts (short)

Volume floor, staffing cap, always-print-fraction, live-DB gate, and no-95% back-door are specified in Decision Rules and Sample-Size. They are not second primary KPIs.

## Comparison Groups and Segments

**Primary comparison group:** sellers with usable denominator ≥30 after exclusions, same window, same rules.

Stage 4 must compute, as **data-derived benchmarks** (not SLAs): seller-order-weighted marketplace LFR; equal-weighted seller LFR; min, P25, median, P75, P90, P95, max of seller LFR in that group.

**Working peer bar (ranking device, not an SLA):** LFR ≥ P75 of enrollment-eligible sellers **and** LFR > seller-order-weighted marketplace LFR. If after guardrails that set is larger than ~20, raise the operable bar to P90 and keep P75–P90 as watch. If it is far smaller than 20, **do not pad** with ordinary sellers. ChatGPT’s “above portfolio average” can admit a long tail; DeepSeek’s “top 20 by LFR” can enroll the least-bad of a tight cluster. Source-file resolution: Maya asked for a pattern she would put on a plan, and for a cap, not a full roster of 20 regardless of separation.

**Segments (descriptive, not extra filters):** `seller_state`; volume bands 30–49 / 50–99 / 100+; multi-seller vs single-seller orders; purchase half-window; late-severity bands (on-time / 1–3 / 4–7 / 8–30 / >30 days vs estimate).

**Not segments:** SP-only; review scores; payment type; product category; ZIP coordinates; 2016 or Sep–Oct 2018 as a baseline.

## Confounders and Interpretation Risks

1. **Shared delivery clock** on multi-seller orders.
2. **Promise-date setting** (estimate may be generous or tight; not a seller column).
3. **Carrier time after handoff** (`order_delivered_carrier_date` is diagnostic only).
4. **Customer state vs seller state** (distance not measured; geo join forbidden on the primary path).
5. **Small-n rates** even at 30.
6. **One extreme delay** (profile max purchase→customer ~210 days on the full extract).
7. **Calendar vs timestamp precision** flipping list membership.
8. **SP concentration** (~60% of sellers in the full extract) dominating an unsegmented list.
9. **Item-revenue vs payment-value** if someone later joins payments incorrectly.
10. **Live MySQL ≠ source-file profile.**

## Data-Quality and Anomaly Rules

Do not hide counts. Stage 4 QA log must print each exclusion’s row count.

| Issue | Source | Treatment |
| ----- | ------ | --------- |
| Many-side fan-out (items, payments, reviews) | Profile priority 1 | Pre-aggregate items to seller-order **before** seller roll-up. Do not join payments or reviews on the primary path. If a later sensitivity uses them, aggregate those tables to `order_id` first |
| Small seller samples | Profile; median 6 | Volume floor; always print n |
| 8 delivered missing customer-delivery date | Profile | **Exclude from LFR**; QA count. Recommended default. **Still unresolved** if Maya wants a delivered-unknown bucket; they still cannot be scored |
| 166 carrier before purchase | Profile (full extract) | **Exclude from duration metrics**; **keep in LFR** if actual and estimate exist; **flag**. Recommended default. **Still unresolved** for LFR membership |
| 23 delivery before carrier | Profile (full extract) | Same as 166 |
| 4 item rows with 2020 `shipping_limit_date` | Profile | Exclude those **item rows** from ship-limit diagnostic only. Do not drop the parent order from LFR on this alone |
| Partial 2016 and Sep–Oct 2018 | Profile; Maya | Out of the study window |
| Duplicate / multiple reviews | Profile | Unused. Rule if ever used: reduce to one row per `order_id` with a documented rule before joining |
| Multiple payments | Profile | Unused. If ever used: aggregate to `order_id` before joining. Never sum `payment_value` after an item join |
| Multiple items | Schema | Collapse to seller-order |
| Missing / untranslated categories | Profile | Unused. If labeled later: keep rows, tag `untranslated` / `missing` |
| Geolocation many-rows-per-ZIP and coordinate outliers | Profile | Unused. If ever used: one reviewed row per ZIP prefix first |
| Zero freight / zero weight / zero payment | Profile | Do not drop from LFR |
| Context-package grand total 1,450,922 | Profile correction | Use **1,550,922** as the nine-table source sum. Individual table counts in the context package stand |
| Live vs source | Profile | Stage 4 MySQL controls after differences are explained. Critical gate fail → no enrollment list |

## Sample-Size and Stability Rules

- Enrollment ranking requires usable denominator ≥30. **Accepted provisional assumption.**
- Sellers below 30 appear in a volume-suppressed appendix (counts only).
- Always publish `late_n / eligible_n`.
- Do not treat the full-extract “425 sellers at 50 orders” or “627 at 30” as the expected size of the Jan–Aug 2018 n≥30 set. Those percents are full-history coverage.
- Split-window: recommended default blocks auto-enroll when only one half is hot. **Still unresolved** as a Maya lock.
- If date vs timestamp LFR would change the action, that seller is inconclusive until Maya picks precision.
- If live MySQL critical QA fails, the whole list is inconclusive.

## Decision Rules

**Global gate:** live MySQL does not pass critical reconciliation → no list. Action: wait. Guardrail: live-DB.

**Volume gate:** usable n < 30 → standard terms / monitor. Not ranked. Guardrail: provisional floor.

**Peer screen:** among n≥30, LFR at or below the working peer bar → standard terms / monitor. LFR above the bar → candidate pool. Peer bar is **data-derived in Stage 4**, not 95% and not 8.11%.

**Rank candidates:** higher LFR, then higher late count, then larger denominator, then `seller_id` for a technical tie.

**Capacity:** recommend up to about 20 from the top of that ranked pool **who also pass attribution and stability guardrails**. Do not fill 20 because the seats exist. If fewer pass, recommend fewer. Overflow of the pool = watch / monitor, not silent expansion. Cap **Confirmed by Maya**.

**Attribution:** if all-order LFR would enroll and single-seller LFR would not → inconclusive / Maya review. No approved 50% contamination cut.

**Precision:** if date-rule and timestamp-rule imply different actions → inconclusive until Maya chooses.

**Supporting metrics** (duration, ship-limit, state, revenue) may change the *conversation* (e.g. AM call) but must not enroll by themselves.

**Inconclusive / empty pool:** if nobody is materially above peers, output the LFR distribution and “continue monitoring.” Do not invent a lower bar to force 20 names.

**Actions by result**

| Result | Meaning | Sufficient? | Action | What can block it |
| ------ | ------- | ----------- | ------ | ----------------- |
| Above peer bar, n≥30, stable, attribution OK, inside cap | Pattern Maya can defend | Yes, as working design | Enroll (ops plan outside DB) | Live-DB fail; precision flip; Maya rejects working lateness rule |
| Above bar but multi-seller-driven | Shared clock | No | Inconclusive / review | Attribution guardrail |
| Above bar in one half only | Spike | No | Watch / standard terms | Stability guardrail |
| At or below bar, n≥30 | Ordinary relative to peers | Yes | Standard terms | None |
| n<30 | Too little evidence | Yes for *not ranking* | Monitor, appendix only | Volume floor |
| Empty candidate pool | No separable late pattern | Yes | Monitor; show distribution | Do not pad |
| >20 pass every bar | More names than staffing | Partial | Top ~20 enroll; rest watch | Cap |

Featured placement and offboarding are **not** outputs of these rules.

## SQL Implementation Blueprint for Stage 4

No executable SQL.

**Engine:** MySQL 8.0, schema `fulfilliq`. Record `VERSION()`, `sql_mode`, session/global time zone (context package marks the last two UNKNOWN).

**Tables in the primary path:** `raw_orders`, `raw_order_items`, `raw_sellers`.

**Columns in the primary path:**  
`raw_orders`: `order_id`, `order_status`, `order_purchase_timestamp`, `order_delivered_carrier_date`, `order_delivered_customer_date`, `order_estimated_delivery_date`.  
`raw_order_items`: `order_id`, `order_item_id`, `seller_id`, `shipping_limit_date`, `price`, `freight_value`.  
`raw_sellers`: `seller_id`, `seller_city`, `seller_state`.

**Do not use on the primary path:** `raw_payments`, `raw_reviews`, `raw_products`, `raw_category_translation`, `raw_geolocation`, `raw_customers` (customer state is a confounder note only).

**Filters:** `order_status = 'delivered'`; purchase timestamp in `[2018-01-01, 2018-09-01)`.

**Required exclusions:** orders with no items; null actual or estimate; `seller_id` not in `raw_sellers`.

**Pre-aggregations (mandatory):**

1. `item_seller_order` — collapse `raw_order_items` to one row per `(order_id, seller_id)`: min/max `shipping_limit_date` (for diagnostic), sum `price`, sum `freight_value`, count item rows.
2. `order_seller_count` — count distinct `seller_id` per `order_id` (multi-seller flag).
3. Join those to filtered `raw_orders` **after** order filters, never before.
4. Attach `raw_sellers` on `seller_id`.
5. Seller roll-up last.

**Safe join order:** filter orders → aggregate items to seller-order → join orders to that aggregate (coverage check) → join sellers → compute flags → aggregate to seller.

**Proposed CTE names and purpose:**

| CTE | Purpose |
| --- | ------- |
| `cte_version_check` | Server version, sql_mode, time zone |
| `cte_orders_window` | Delivered orders in the purchase window |
| `cte_item_to_seller_order` | Item collapse to `(order_id, seller_id)` |
| `cte_order_n_sellers` | Distinct sellers per order |
| `cte_seller_order` | Working grain with late flags (date and timestamp twins), duration, anomaly flags |
| `cte_seller_window` | Seller-level LFR, volume, split-window, single-seller LFR, revenue |
| `cte_peer_benchmarks` | P25–P95 and weighted marketplace LFR among n≥30 |
| `cte_candidates` | Peer-bar passers after guardrails |
| `cte_operable_list` | Ranked, cap-aware enroll / watch / standard / inconclusive |
| `cte_qa_counts` | Exclusion and join-reconciliation counts |

**Expected output columns (seller-level):** `seller_id`, `seller_state`, `seller_city`, `eligible_n`, `late_n`, `lfr_date`, `lfr_timestamp`, `median_days_vs_estimate`, `median_days_late`, `lfr_jan_apr`, `lfr_may_aug`, `lfr_single_seller`, `multi_seller_order_share`, `item_revenue`, `anomaly_n`, `action` (`enroll` / `watch` / `standard_terms` / `inconclusive`), `rank_if_candidate`.

**QA checks (halt on Critical):** uniqueness of `raw_orders.order_id` and `(order_id, order_item_id)`; six profiled orphan checks at 0; nine table row counts vs profile (and corrected total 1,550,922); seller-order uniqueness on `(seller_id, order_id)`; join-expansion: seller-order count = distinct `(order_id, seller_id)` in items for eligible orders; LFR denominator equals documented eligible population; non-delivered rows in extract = 0; null actual/estimate in LFR denom = 0; n printed for every rate; no output labeled 95% SLA; date vs timestamp rank-flip count; live vs source anchors listed in the Data Profile’s Stage 4 QA gates.

**Stage 4 must not:** write executable analysis in this Stage 3 file (already none); join payments/reviews/geolocation on the primary path; use Sep–Oct 2018 or 2016; treat 8.11% or 95% as cuts; rank sellers with n<30.

## Multi-AI Review Record

### Round 1 (independent)

| Topic | Grok | ChatGPT | DeepSeek | Resolution (source-file) |
| ----- | ---- | ------- | -------- | ------------------------ |
| Grain | Seller-order then seller-window | Same | Same, but labeled Confirmed by Maya | Same grain. **Not** Confirmed by Maya. Profile + schema. |
| Primary KPI | LFR, higher worse | Same | LDR, same idea | One name: LFR. Same formula. |
| Lateness clock | DATE(actual)>DATE(estimate), timestamp twin | Calendar date recommended; both until Maya | Timestamp `actual > estimated` | Working **date** rule; Stage 4 runs both. Estimate field looks like a date in the profile. |
| Volume floor | ≥30 eligible seller-orders | ≥30 on **post-exclusion** denom; asks Maya | ≥30 delivered orders | Post-exclusion denom. Flag for Maya. |
| Peer / list rule | P75 and above weighted LFR; raise to P90 if >20; do not pad | Above portfolio rate then rank to 20 | Top 20 by LDR | Must be worse than peers, then cap. Do not pad. Do not take top 20 of a flat distribution. |
| Attribution | 50% multi-seller cut recommended, unresolved | Inconclusive if single-seller view flips | Flags; weaker | ChatGPT rule: flip → inconclusive. No confirmed 50% cut. |
| 8 missing dates | Exclude from LFR | Exclude | Exclude | Exclude + QA count. |
| 166 / 23 | Keep in LFR, drop from duration | Flag / exclude from timing | Flag >10% as caution | Keep in LFR if scorable; drop from duration; flag. |
| 627 sellers at n≥30 | Warned as full extract | Not used as window expectation | Used as expected coverage | **Do not** use 627 for Jan–Aug 2018. |
| Reviews/payments/geo | Unused | Unused | Unused on primary | Unused. Handling rules still documented. |
| 95% / 8.11% | Forbidden | Forbidden | Forbidden as KPI | Forbidden. |

Grok chat: https://grok.com/c/a2006263-8d65-43bc-a42f-aa8f92183af5  
ChatGPT chat: https://chatgpt.com/c/6a97b299-b160-83ea-8bbe-9634b8653f00  
DeepSeek chat: https://chat.deepseek.com/a/chat/s/18db5397-4ed7-4902-a98e-bd3e3a4f66f8  

DeepSeek Round 1 ran in Instant with all four files attached (Expert on that account blocks file uploads). ChatGPT Chat mode; Grok regular chat.

### Round 2–3

Cross-review files: `round2-grok.md`, `round2-chatgpt.md`, `round2-deepseek.md` when present under `/workspace/fulfilliq-s3/`. Disagreements were not resolved by vote. The Database Context Package decided what columns exist. The Data Profile decided fan-out, small samples, edge periods, and anomaly counts. The Stages 1–2 handoff decided the decision, window, delivered-only rule, cap, unused tables, and what Maya refused to sign.

## Assumptions and Open Questions

**Confirmed facts / Maya:** delivered-only; Jan–Aug 2018 purchases; all seller states; ~20 cap; no 95%; no 8.11% as KPI; no reviews/payments/categories/geo on the primary path; ops plan is outside the DB; deadline 18 Sep 2026.

**Accepted provisional:** ≥30 usable seller-orders (post-exclusion, pending Maya if she meant pre-exclusion).

**Stage 3 working defaults (not Maya locks):** seller-order grain; DATE lateness; exclude 8 from LFR; 166/23 out of duration, in LFR if scorable; P75+above-weighted-LFR peer bar with no padding; attribution flip → inconclusive.

**Data-derived in Stage 4:** marketplace LFR and seller LFR percentiles; actual n≥30 headcount in the window; rank-flip count between date and timestamp rules.

**Still unresolved / Maya:** official percent target; date vs timestamp as the business lock; whether 30 is before or after exclusions; whether 166/23 may stay in LFR; 7-day severe-late cut; 5-late hygiene floor; split-window as a hard block; live MySQL vs source.

## Stage 4 Handoff

Stage 4 (SQL then R) should:

1. Reconcile live MySQL to the Data Profile anchors (nine counts, corrected 1,550,922 total, keys, orphans, status mix, 8 missing customer dates, 166, 23, four 2020 ship-limits).
2. Build `cte_seller_order` at `(seller_id, order_id)` for delivered purchases in `[2018-01-01, 2018-09-01)` with both delivery timestamps.
3. Compute LFR under **both** date and timestamp rules; print rank flips.
4. Apply n≥30 on the usable denominator; print every rate as `late_n / eligible_n`.
5. Compute peer distribution among those sellers; apply the working peer bar; rank; cap ~20 without padding.
6. Attach split-window LFR, single-seller LFR, revenue, state, anomaly flags.
7. Output enroll / watch / standard_terms / inconclusive with no 95% label.
8. Halt on critical QA failure. Do not join payments, reviews, or raw geolocation on this path.
9. If date vs timestamp changes the enroll set, stop for Maya. If n≥30-before vs after exclusions changes the enroll set, stop for Maya.

No Stage 4 analysis was performed in this document. No executable SQL is included.

