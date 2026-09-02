# FulfillIQ — Stages 1 and 2 Dialogue and Handoff

## Scenario

Maya Chen is a fictional Director of Marketplace Seller Operations at FulfillIQ. FulfillIQ’s working database is a MySQL 8 local schema, `fulfilliq`, loaded from the Brazilian Olist e-commerce CSVs (nine raw tables). Maya’s answers in this interview are **mock business requirements created for the FulfillIQ portfolio project**.

This rewrite was done after reading:

- `docs/FulfillIQ_Database_Context_Package.md` (schema, grains, keys, known load limits)
- `docs/FulfillIQ_Data_Profile.md` (source-file distributions, date coverage, seller volume, quality risks)

The AI Analyst uses those documents only to keep Maya’s decision inside what the data can support. It does not design KPIs, write hypotheses, write SQL or R, or begin Stage 3 measurement design.

Maya begins with a realistic but incomplete metric request (a last-month US seller-lateness ranking). The data cannot support a live US 2026 marketplace view. The interview moves her to a decision that can be informed by Olist Brazil, 2016-09-04 through 2018-10-17, on delivered orders that have actual and estimated delivery timestamps.

---

## Complete Maya–AI Dialogue

**Maya:** I need late shipment rate by seller for last month. Leadership wants a ranking of who’s slow in the US. Just pull it.

**AI Analyst:** I will not start with that pull. I read the Database Context Package and the Data Profile. This database is not a live US marketplace in 2026. It is Brazilian Olist loaded into MySQL `fulfilliq`: 99,441 orders, 3,095 sellers, 112,650 order-item rows. Order purchase timestamps run from 2016-09-04 to 2018-10-17. Seller geography is Brazilian states (`seller_state`), mostly SP, PR, MG, SC, RJ. There is no US region field. “Last month” in calendar 2026 is empty. If we rank “US sellers last month,” we would be inventing a population the tables do not contain. What business problem made leadership ask for names?

**Maya:** Customer complaints about late packages. They think some sellers are the problem and I am supposed to do something about seller performance before peak. I talked as if this were our current US book. I didn’t realize the sandbox is Brazil 2016–2018.

**AI Analyst:** It is. So the useful version of your problem is: using this historical Brazilian marketplace, which sellers look like a late-fulfillment problem you would put on a performance plan, rather than leave on standard terms. Is the decision still “enroll vs not enroll,” or did you only want a chart?

**Maya:** The decision is still enroll vs not. We have used a 30-day seller performance plan: weekly check-ins, they can lose featured placement, and if they stay bad I can recommend offboarding to the VP. I cannot terminate a contract myself. I want a list I can take to the VP, not a vanity ranking.

**AI Analyst:** Featured placement and “already on a plan” are operations outside this database. `raw_sellers` has `seller_id`, ZIP prefix, city, and Brazilian state only. There is no plan-status column, no 1P vs 3P flag, and no featured-placement flag. All 3,095 sellers in `raw_sellers` appear as marketplace sellers on item rows. I can still support a list of sellers whose *delivery performance in the data* would support enrollment. I cannot score “already on a plan” or “featured.” Who owns the enrollment decision?

**Maya:** I do. Seller ops executes the plan. The VP of Marketplace hears the recommendation on Friday 18 September 2026. That meeting date is real for this project even though the orders are historical.

**AI Analyst:** Good. The deadline is when you decide. The analysis window has to sit inside the Olist dates. Why act at all?

**Maya:** If we never name sellers, peak or no peak, we keep featuring people who deliver late. If we hammer small noisy sellers, we cut GMV and look arbitrary. I want fewer late deliveries to customers without punishing volume that is just sparse.

**AI Analyst:** Outcomes to improve: fewer late customer deliveries from in-scope sellers. Outcomes to avoid: ranking sellers with tiny samples, mixing in orders that never delivered, treating Brazil as the US, and pretending a one-month 2026 extract exists. What actions can you actually take once you have a list?

**Maya:** Do nothing. Enroll in the 30-day plan. Pull featured placement as part of that plan, as an ops action, not as a database field. Ask account management to call. Recommend offboarding to the VP. I cannot change fees, add warehouses, or terminate contracts. Staffing: about 20 concurrent plans, no extra budget.

**AI Analyst:** Scope, against the actual tables. Orders live in `raw_orders` with statuses delivered, shipped, canceled, unavailable, invoiced, processing, created, approved. 96,478 of 99,441 are `delivered`. Delivery timestamps are missing almost exactly when status is not delivered. The Data Profile says delivery KPIs must define an eligible population, not treat undelivered orders as ordinary missingness. Item-level seller is `raw_order_items.seller_id`. An order can have several item rows and therefore more than one seller. 775 orders have no item row at all. Lateness, if we ever measure it, has to use columns that exist: `order_delivered_customer_date` vs `order_estimated_delivery_date` on orders, and optionally `shipping_limit_date` on items. I am not locking a formula today. I am telling you what is there. Does your decision concern sellers on delivered orders, or every status?

**Maya:** Delivered orders only. If it never reached the customer, it is not this performance-plan decision. I don’t want canceled or unavailable in the ranking.

**AI Analyst:** Confirmed: eligible orders are `order_status = 'delivered'`. The profile also notes 8 delivered orders lack a customer-delivery timestamp, and 96,470 delivered orders have both actual and estimated delivery timestamps. Stage 3 will have to say whether those 8 are dropped. Time window: 2016 is 329 orders. 2017 is 45,101. 2018 is 54,011, but September–October 2018 together have only 20 purchases, so they are not comparable months. Reviews also stop at 2018-08-31. The profile forbids treating partial edge periods as full months. I will not use “last 90 days of 2026.” What window do you want inside the complete data?

**Maya:** I wanted last month because leadership said last month. That was the wrong clock. Use a complete 2018 window before the broken tail. January through August 2018.

**AI Analyst:** I will record 1 January 2018 through 31 August 2018 as your confirmed analysis period, with purchase timestamp in that range. Not 2016, not Sep–Oct 2018, not a 2026 month. Geography: 23 seller states, 27 customer states, Brazil. About 60% of sellers are in SP. Do you want all Brazilian sellers in the data, or only SP?

**Maya:** All sellers in the database. Do not drop the other states just because SP is large. Do not filter to the US. There is no US.

**AI Analyst:** Volume. The Data Profile is explicit that seller samples are skewed and that Stage 3 must set a minimum delivered-order guardrail rather than invent one inside SQL. Median delivered orders per seller is 6. Coverage if we require a minimum of delivered orders: 5 → 57% of sellers; 10 → 40%; 20 → 26%; 30 → 20%; 50 → 14% (425 sellers); 100 → 7%. You said you will not chase a handful of orders. I will not pick a number for you. Which floor do you accept for this fictional project?

**Maya:** Fifty feels clean but that throws away most sellers. Thirty. I’ll accept 30 delivered orders in the analysis window as a provisional floor only. Stage 3 must not call it a signed SLA. Show the denominator next to any seller figure.

**AI Analyst:** Recorded as an accepted provisional assumption: at least 30 delivered orders for that seller in 1 Jan–31 Aug 2018. Not a company SLA. Official on-time target: do you have a signed percentage?

**Maya:** People say 95%. I have not signed it. Do not put 95% in the question or treat the profile’s descriptive 8.11% late share as my KPI. That 8.11% was labeled descriptive only.

**AI Analyst:** Correct. The profile’s 7,826 / 96,470 late count used a provisional rule `actual > estimated` and is not an approved metric. Open question: official target. Also open: whether Stage 3 uses timestamp or calendar-date precision; whether lateness is customer-delivery vs estimate, or seller `shipping_limit_date` vs carrier handoff; how to treat 166 carrier-before-purchase and 23 delivery-before-carrier rows; how to collapse multi-item, multi-seller orders to a seller-order grain; whether reviews belong in this decision at all. Do you want reviews in this decision?

**Maya:** No. Complaints started this, but the decision is late fulfillment, not review-score management. Don’t join reviews for the primary question. Payments neither. Don’t use raw geolocation ZIP coordinates. State on `raw_sellers` is enough if we slice geography later.

**AI Analyst:** Confirmed exclusions: reviews, payments, and raw geolocation joins are out of this decision’s primary path. Categories are also not this decision unless you say so.

**Maya:** Not this decision. I am not doing a category strategy.

**AI Analyst:** Evidence standard?

**Maya:** I need a VP-defensible list from delivered Brazilian orders in Jan–Aug 2018, with a volume floor, not a one-month ranking, not a 2026 extract, not undelivered statuses. If we cannot tell seller fulfillment from everything else, say so. I will not enroll from impossible timestamps if Stage 3 flags them. Cap the operable list at about 20 names because of staffing.

**AI Analyst:** Proposed one-sentence decision, against this database:

*Maya, as Director of Marketplace Seller Operations, will decide by 18 September 2026 which FulfillIQ marketplace sellers in the Olist Brazil sandbox, if any, to enroll in a 30-day late-fulfillment performance plan rather than leave on standard terms, using delivered orders those sellers fulfilled with purchase timestamps from 1 January 2018 through 31 August 2018, in order to reduce late customer deliveries without ranking tiny-sample or out-of-scope sellers, and without treating offboarding, US geography, or a live 2026 month as things this database contains.*

What do you want changed?

**Maya:** Say the plan and featured-placement execution sit outside the tables. And say I can recommend offboarding to the VP but that is not this decision.

**AI Analyst:** Revised:

*Maya, as Director of Marketplace Seller Operations, will decide by 18 September 2026 which sellers in the FulfillIQ Olist Brazil database, if any, to enroll in a 30-day late-fulfillment performance plan rather than leave on standard terms. The list must be informed by delivered orders those sellers fulfilled with `order_purchase_timestamp` from 1 January 2018 through 31 August 2018. The purpose is to reduce late customer deliveries before she takes a recommendation to the VP, without penalizing sellers whose volume is too small or whose orders are outside the eligible delivered population. Plan operations (notification, featured-placement changes) are outside the database. Offboarding remains a later VP recommendation, not this decision. The data are Brazilian 2016–2018 Olist tables, not a US 2026 extract.*

Do you approve that decision?

**Maya:** Yes. I approve it. Mock requirements only.

**AI Analyst:** Constraints read-back before Stage 2.

Confirmed from you and from the documents: decision date 18 September 2026; analysis purchases 2018-01-01 through 2018-08-31; Brazil only, all seller states in `raw_sellers`; delivered orders only; sellers identified from `raw_order_items.seller_id`; no US filter; no 2026 month; no reviews/payments/geolocation/category as primary inputs; staffing cap ~20 enrollments; no extra budget; you cannot terminate contracts; 95% is not approved; the profile’s 8.11% is not a KPI; median seller volume is 6 so a floor is mandatory.

Provisional, you accepted: at least 30 delivered orders for that seller in the analysis window.

Open, because you or the documents left them unset: official late/on-time threshold; timestamp vs date precision; customer-delivery-vs-estimate vs shipping-limit definition; anomaly rows (166 + 23, plus four 2020 shipping-limit dates); exact seller-order grain rule; the 8 delivered orders missing customer-delivery dates; live MySQL vs source-profile reconciliation; whether “already on a plan” can ever be known (no such column).

**Maya:** That split is right. Freeze Stage 1.

**AI Analyst:** Stage 2. Framing question. It has to support that decision, name the population this database actually has, stay neutral, and not embed an unapproved formula.

Draft 1, your original: *Which US sellers were late last month?* Unsupported. No US, no 2026 month.

Draft 2: *Which sellers are below 95% on-time?* Embeds an unapproved threshold and treats the descriptive 8.11% rule as decided.

Draft 3: *In January–August 2018, among sellers in the FulfillIQ Olist Brazil data with enough delivered orders, which sellers’ late-fulfillment performance would support Maya’s decision to enroll them in a 30-day plan rather than leave them on standard terms?*

Plain language: we ask which in-scope Brazilian sellers, in a complete 2018 window, look like the late-fulfillment problem you would use the plan for. We do not define “late” as SQL yet. Stage 3 still has to design measurement from `order_delivered_customer_date`, `order_estimated_delivery_date`, and possibly `shipping_limit_date`, at a grain that does not explode items into fake extra orders.

**Maya:** Put delivered orders and the 2018 window in the question. Put that this is the Olist Brazil sandbox. Don’t put 30 in the question; that floor is provisional. Don’t put 95%. Then I approve it.

**AI Analyst:** Final framing question:

*Among sellers in the FulfillIQ Olist Brazil database who fulfilled delivered orders with purchase timestamps from 1 January 2018 through 31 August 2018, which sellers show late-fulfillment performance that would support Maya’s decision to enroll them in a 30-day performance plan, rather than leave them on standard terms?*

Do you approve that as the single primary framing question?

**Maya:** Yes. I approve it. No second primary question. No SQL. No KPI formula in the question.

**AI Analyst:** We stop. Stage 3 gets this handoff plus the Database Context Package and the Data Profile. It must not treat 95%, the 8.11% descriptive share, a US filter, a 2026 month, or a geolocation join as settled. It must declare grain so item and payment fan-out cannot silently multiply sellers’ orders.

**Maya:** Use this rewrite.

---

## Final Business Decision

Maya, as Director of Marketplace Seller Operations, will decide by 18 September 2026 which sellers in the FulfillIQ Olist Brazil database, if any, to enroll in a 30-day late-fulfillment performance plan rather than leave on standard terms. The list must be informed by delivered orders those sellers fulfilled with `order_purchase_timestamp` from 1 January 2018 through 31 August 2018. The purpose is to reduce late customer deliveries before she takes a recommendation to the VP, without penalizing sellers whose volume is too small or whose orders are outside the eligible delivered population. Plan operations (notification, featured-placement changes) are outside the database. Offboarding remains a later VP recommendation, not this decision. The data are Brazilian 2016–2018 Olist tables, not a US 2026 extract.

## Final Analytical Framing Question

Among sellers in the FulfillIQ Olist Brazil database who fulfilled delivered orders with purchase timestamps from 1 January 2018 through 31 August 2018, which sellers show late-fulfillment performance that would support Maya’s decision to enroll them in a 30-day performance plan, rather than leave them on standard terms?

## Business Constraints

Maya’s answers are mock business requirements created for the FulfillIQ portfolio project. Facts about tables, dates, and volume come from the Database Context Package and the Data Profile, not from invented marketplace fields.

| Constraint | Status | Maya’s answer | Stage 3 implication |
| ---------- | ------ | ------------- | ------------------- |
| Decision deadline | Confirmed constraint | VP recommendation due 18 September 2026. | Measurement must be completable for that meeting. The order clock is 2018, not 2026. |
| Data universe | Confirmed constraint (from documents) | MySQL schema `fulfilliq`; Brazilian Olist; 9 raw tables; purchases 2016-09-04 to 2018-10-17; 3,095 sellers; 99,441 orders. | Do not design for a US 2026 marketplace or for tables that were not built. |
| Analysis period | Confirmed constraint | Purchases from 1 January 2018 through 31 August 2018. | Exclude 2016 (329 orders), Sep–Oct 2018 (20 purchases combined), and any 2026 window. |
| Geography | Confirmed constraint | All seller states present in `raw_sellers` (Brazil). Not US. Not SP-only. | Use `seller_state` / `seller_city` if sliced. Do not join raw `raw_geolocation` for this decision. |
| Eligible orders | Confirmed constraint | `order_status = 'delivered'` only. | Do not treat shipped/canceled/unavailable/invoiced/processing/created/approved as this plan population. |
| Eligible sellers | Confirmed constraint | Sellers on `raw_order_items.seller_id` for those delivered orders. | 775 orders have no item row and cannot contribute a seller. |
| Plan / featured / 1P flags | Confirmed constraint (absence) | No such columns. All sellers in this extract are marketplace sellers. | Do not invent plan-status or 1P/3P filters. |
| Minimum volume | Accepted provisional assumption | Maya accepted ≥30 delivered orders for that seller in the analysis window after seeing the profile’s 5/10/20/30/50/100 coverage table. Median seller volume is 6. | Use 30 as a working floor. Report the denominator. Do not call it a signed SLA. Do not silently switch to 50 or 10. |
| Official on-time target | Open question | 95% was mentioned as a vibe only. Maya refused to approve it. | Do not embed 95% or the profile’s descriptive 8.11% late share as a KPI. |
| Acceptable vs unacceptable | Confirmed constraint (qualitative) | Acceptable: generally on time with occasional misses. Unacceptable: a lateness pattern she would put on a 30-day plan. No cutoff %. | Stage 3 designs measurement; it does not invent a pass line. |
| Staffing | Confirmed constraint | About 20 concurrent 30-day plans; no extra budget. | A raw list longer than ~20 is not operable. |
| Authority | Confirmed constraint | Maya enrolls, can request AM contact, can recommend offboarding. Cannot terminate, change fees, or add capacity. | Output is an enrollment list, not a termination list. |
| Reviews / payments / categories | Confirmed constraint | Out of this primary decision. | Do not require those joins to answer the framing question. |
| Evidence standard | Confirmed constraint | VP-defensible; complete 2018 window; volume floor; delivered only; Brazil; say so if seller fulfillment cannot be separated from other delay. | Do not hide attribution or data-quality limits. |
| Delivery-timestamp eligibility | Open question | 8 delivered orders lack customer-delivery dates; 96,470 have both actual and estimated. | Stage 3 must declare whether the 8 are dropped. |
| Lateness definition | Open question | Columns exist (`order_delivered_customer_date`, `order_estimated_delivery_date`, item `shipping_limit_date`). Maya did not approve a formula or timestamp vs date precision. | Do not treat the profile’s provisional `actual > estimated` rule as locked. |
| Event-sequence anomalies | Open question | 166 carrier-before-purchase; 23 delivery-before-carrier; 4 item rows with 2020 shipping-limit dates. | Stage 3 must flag or exclude; do not silently drop them from QA counts. |
| Grain | Open question | Item rows can repeat `order_id`; an order can have more than one seller. Profile recommends seller-order grain after consolidating items. Maya did not lock SQL. | Stage 3 must declare grain so joins do not multiply orders. |
| Live MySQL vs source profile | Open question | Profile was computed from source files, not a live query. Grand total in the context package (1,450,922) is an arithmetic error; profile corrects to 1,550,922. | Stage 4 must reconcile to MySQL. Stage 3 must not pretend the live server was already queried. |

## Decision Authority and Available Actions

Maya owns the enrollment decision. She can leave a seller on standard terms, enroll them in the 30-day late-fulfillment plan, change featured placement as an operations step outside the database, ask account management to contact the seller, and recommend offboarding to the VP.

She cannot terminate contracts, change fees, add capacity, filter to the US, score a 2026 month, or enroll more than about 20 sellers at once.

## Accepted Provisional Assumptions

- For this fictional project only, a seller must have at least 30 delivered orders with purchase timestamps in 1 January 2018–31 August 2018 to be eligible for consideration. Maya explicitly accepted this after seeing the Data Profile coverage table. It is not a signed SLA.

No other AI-proposed numeric cutoff was accepted. The profile’s descriptive late share (7,826 / 96,470, 8.11%) was explicitly rejected as a KPI.

## Open Questions

Stage 3 must not silently decide these:

1. Official on-time or late-delivery target, including 95%.
2. Whether lateness uses timestamp or calendar date, and whether it is customer delivery vs estimate, seller shipping-limit vs carrier, or both.
3. Treatment of 8 delivered orders missing customer-delivery timestamps.
4. Treatment of 166 carrier-before-purchase rows, 23 delivery-before-carrier rows, and 4 item rows with 2020 shipping-limit dates.
5. Exact analytical grain (order vs seller-order vs item) given multi-item, multi-seller orders.
6. Whether “already on a performance plan” can be known (no column exists).
7. Live MySQL value-level agreement with the source-file profile, including the corrected 1,550,922 row total.
8. Any category, payment, review, or ZIP-coordinate cut Maya did not authorize.

## Stage 3 Handoff

* **Final business decision:** Maya, as Director of Marketplace Seller Operations, will decide by 18 September 2026 which sellers in the FulfillIQ Olist Brazil database, if any, to enroll in a 30-day late-fulfillment performance plan rather than leave on standard terms, using delivered orders those sellers fulfilled with `order_purchase_timestamp` from 1 January 2018 through 31 August 2018.
* **Final framing question:** Among sellers in the FulfillIQ Olist Brazil database who fulfilled delivered orders with purchase timestamps from 1 January 2018 through 31 August 2018, which sellers show late-fulfillment performance that would support Maya’s decision to enroll them in a 30-day performance plan, rather than leave them on standard terms?
* **Decision owner:** Maya Chen, Director of Marketplace Seller Operations (fictional).
* **Available actions:** Monitor / standard terms; enroll in 30-day plan; featured-placement change as ops, not as a table; AM contact; recommend offboarding. Not available: contract termination, fee changes, capacity spend, US filter, 2026 extract, >~20 concurrent plans.
* **Analysis scope:** Schema `fulfilliq`; Brazilian Olist; `raw_orders` delivered only; sellers from `raw_order_items.seller_id`; purchases 2018-01-01 through 2018-08-31; all seller states in `raw_sellers`; no primary use of reviews, payments, categories, or raw geolocation.
* **Decision deadline:** 18 September 2026.
* **Confirmed constraints:** Olist Brazil universe; delivered-only; 2018-01-01–2018-08-31; no US; no 2026 month; no plan/1P flags; qualitative acceptable/unacceptable without a formula; ~20 enrollment cap; VP-defensible evidence; do not treat 8.11% as a KPI.
* **Accepted provisional assumptions:** ≥30 delivered orders for that seller in the analysis window.
* **Open questions:** Target %; lateness formula and precision; 8 missing delivery dates; temporal anomalies; grain; plan-status (absent); live MySQL reconciliation.
* **Evidence standard required for action:** Complete 2018 window, delivered Brazilian orders, volume floor with denominator shown, attribution limits stated, no one-month ranking, no invented geography.

**Source facts Stage 3 may rely on (already in the two documents, not invented here):** 99,441 orders; 112,650 item rows; 3,095 sellers; 96,478 delivered; 96,470 delivered with both delivery timestamps; 775 orders with no items; seller delivered-order median 6; partial 2016 and Sep–Oct 2018; no physical FKs; review_id and order_id not unique in reviews; geolocation many rows per ZIP; context-package grand total 1,450,922 is wrong, profile total 1,550,922 is the corrected sum.

End of Stages 1–2. Do not begin Stage 3 beyond using this file as an input together with the Database Context Package and the Data Profile.
