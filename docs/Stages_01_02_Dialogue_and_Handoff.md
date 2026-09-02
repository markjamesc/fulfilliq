# FulfillIQ — Stages 1 and 2 Dialogue and Handoff

## Scenario

Maya Chen is a fictional Director of Marketplace Seller Operations at FulfillIQ. She already knows the working database is Brazilian Olist loaded into MySQL schema `fulfilliq` (nine raw tables; order purchases 2016-09-04 through 2018-10-17; 3,095 sellers). Her first request is a metric those tables can actually compute. She has not yet stated a decision, an eligible order status, a complete time window, or a volume floor.

This document was written after reading `docs/FulfillIQ_Database_Context_Package.md` and `docs/FulfillIQ_Data_Profile.md`. The AI Analyst uses those documents to keep the interview inside the data. It does not design KPIs, write hypotheses, write SQL or R, or begin Stage 3.

**Maya’s answers are mock business requirements created for the FulfillIQ portfolio project.**

---

## Complete Maya–AI Dialogue

**Maya:** I need late delivery rate by seller for last month in the Olist Brazil data. Leadership wants a ranking of which sellers are slow.

**AI Analyst:** That ranking is a metric, not a decision. The tables can support a seller-level lateness view: `raw_orders` has `order_delivered_customer_date` and `order_estimated_delivery_date`, and `raw_order_items` has `seller_id`. Before we measure, what would you do with the ranking?

**Maya:** Put the worst sellers on a 30-day performance plan before I go to the VP. We have used that plan before: weekly check-ins, we can pull featured placement as an ops step, and if they stay bad I recommend offboarding. I cannot terminate a contract myself. I asked for last month because that is what leadership said.

**AI Analyst:** So the decision is enroll specific sellers in that plan versus leave them on standard terms. Why does that matter now?

**Maya:** Late deliveries are what customers feel. If we do nothing, we keep treating every seller the same. If we punish people with almost no orders, we look arbitrary and we cut GMV. I need a list I can defend, not a dump of every seller with one late order.

**AI Analyst:** Who owns that decision, and who acts?

**Maya:** I own enrollment. Seller ops runs the plan. VP of Marketplace gets the recommendation on Friday, 18 September 2026. Account management can call a seller if I ask. Featured placement is an ops action; it is not a column in `raw_sellers`. I know that table is just `seller_id`, ZIP prefix, city, and Brazilian state.

**AI Analyst:** What can you actually do, and what can you not do?

**Maya:** I can monitor. I can enroll in the 30-day plan. I can pull featured placement as part of the plan. I can ask AM to call. I can recommend offboarding to the VP. I cannot change fees, add warehouses, or terminate contracts. We can run about 20 plans at once. No extra budget.

**AI Analyst:** Last month in this extract is a problem. Purchase timestamps go through 2018-10-17, but September and October 2018 together have only 20 purchases. 2016 is 329 orders. The Data Profile says not to treat those edge periods as comparable months. Last month is not a usable window here. What period do you want inside the complete data?

**Maya:** Then not last month. Use a complete 2018 stretch before that tail. January through August 2018.

**AI Analyst:** Confirmed: `order_purchase_timestamp` from 1 January 2018 through 31 August 2018. Eligible orders: 96,478 of 99,441 orders are delivered, and missing delivery timestamps sit almost entirely in the other statuses. If we leave status open, a late-rate ranking will mix undelivered orders in as if they were missing data. Do you want delivered orders only?

**Maya:** Delivered only. If it never reached the customer, it is not this plan.

**AI Analyst:** Eight delivered orders still lack a customer-delivery timestamp; 96,470 have both actual and estimated. Stage 3 will have to say whether those eight drop. I am not locking a lateness formula. Columns that exist for later design: `order_delivered_customer_date`, `order_estimated_delivery_date`, and item `shipping_limit_date`. An order can have several item rows and more than one seller. 775 orders have no item row, so they cannot contribute a seller. Do you want all seller states, or only SP?

**Maya:** All states in `raw_sellers`. SP is most of them. I still want the rest. I am not doing a category cut, and I do not want reviews or payments in this decision. Complaints started the conversation; the decision is late fulfillment.

**AI Analyst:** Reviews, payments, product category, and raw geolocation joins are out of the primary path. State on `raw_sellers` is enough if we slice later. Volume: median delivered orders per seller is 6. The profile coverage table: 5 orders, 57 percent of sellers; 10, 40 percent; 20, 26 percent; 30, 20 percent; 50, 14 percent; 100, 7 percent. Stage 3 must set a floor rather than invent one in SQL. I will not pick it for you. Which floor do you accept for this project?

**Maya:** Thirty delivered orders in that January through August 2018 window. Provisional only. Show the denominator. Do not call it an SLA.

**AI Analyst:** Recorded as an accepted provisional assumption. Official on-time target: do you have a signed percentage?

**Maya:** People say 95 percent. I have not signed it. Do not put 95 percent in the question. Do not treat the profile’s descriptive 8.11 percent late share as my KPI either. That was labeled descriptive only.

**AI Analyst:** Open: official target; timestamp versus date precision; customer-delivery versus estimate versus shipping-limit; the 166 carrier-before-purchase and 23 delivery-before-carrier rows; four item rows with 2020 shipping-limit dates; seller-order grain; live MySQL versus source-file profile. Evidence you need before you enroll?

**Maya:** A VP-defensible list from delivered Brazilian orders in January through August 2018, with the volume floor, not a 20-order last month, not undelivered statuses. If we cannot tell seller fulfillment from everything else, say so. Cap the operable list at about 20 names.

**AI Analyst:** Proposed decision:

Maya, as Director of Marketplace Seller Operations, will decide by 18 September 2026 which sellers in the FulfillIQ Olist Brazil database, if any, to enroll in a 30-day late-fulfillment performance plan rather than leave on standard terms, using delivered orders those sellers fulfilled with order_purchase_timestamp from 1 January 2018 through 31 August 2018, in order to reduce late customer deliveries without ranking tiny-sample or undelivered volume. Plan operations sit outside the tables. Offboarding is a later VP recommendation, not this decision.

**Maya:** Approve that. Add that featured placement is ops, not a column. Mock requirements only.

**AI Analyst:** Revised:

Maya, as Director of Marketplace Seller Operations, will decide by 18 September 2026 which sellers in the FulfillIQ Olist Brazil database, if any, to enroll in a 30-day late-fulfillment performance plan rather than leave on standard terms. The list must be informed by delivered orders those sellers fulfilled with `order_purchase_timestamp` from 1 January 2018 through 31 August 2018. The purpose is to reduce late customer deliveries before the VP meeting, without penalizing sellers whose volume is too small or whose orders never delivered. Featured-placement and plan administration are operations outside the database. Offboarding remains a later VP recommendation, not this decision.

Do you approve that decision?

**Maya:** Yes. I approve that decision.

**AI Analyst:** Stage 2. Your original question, late delivery rate by seller last month, is the wrong window and it is still a metric. A draft that embeds 95 percent is also out.

Framing question:

Among sellers in the FulfillIQ Olist Brazil database who fulfilled delivered orders with purchase timestamps from 1 January 2018 through 31 August 2018, which sellers show late-fulfillment performance that would support Maya’s decision to enroll them in a 30-day performance plan, rather than leave them on standard terms?

It names the real population and window. It stays neutral. It does not put 30 or 95 percent in the question. Stage 3 still designs the measure from the delivery columns.

**Maya:** That is the question. I approve it. One primary question only. No SQL.

**AI Analyst:** Stop here. Stage 3 receives this handoff plus the Database Context Package and the Data Profile. It must not treat 95 percent, the 8.11 percent descriptive share, September–October 2018, undelivered statuses, or a geolocation join as settled.

**Maya:** Use this.

---

## Final Business Decision

Maya, as Director of Marketplace Seller Operations, will decide by 18 September 2026 which sellers in the FulfillIQ Olist Brazil database, if any, to enroll in a 30-day late-fulfillment performance plan rather than leave on standard terms. The list must be informed by delivered orders those sellers fulfilled with `order_purchase_timestamp` from 1 January 2018 through 31 August 2018. The purpose is to reduce late customer deliveries before the VP meeting, without penalizing sellers whose volume is too small or whose orders never delivered. Featured-placement and plan administration are operations outside the database. Offboarding remains a later VP recommendation, not this decision.

## Final Analytical Framing Question

Among sellers in the FulfillIQ Olist Brazil database who fulfilled delivered orders with purchase timestamps from 1 January 2018 through 31 August 2018, which sellers show late-fulfillment performance that would support Maya’s decision to enroll them in a 30-day performance plan, rather than leave them on standard terms?

## Business Constraints

Maya’s answers are mock business requirements created for the FulfillIQ portfolio project. Table facts come from the Database Context Package and the Data Profile.

| Constraint | Status | Maya’s answer | Stage 3 implication |
| ---------- | ------ | ------------- | ------------------- |
| Decision deadline | Confirmed constraint | 18 September 2026, VP meeting. | Analysis uses 2018 orders; the meeting is when Maya decides. |
| Data universe | Confirmed constraint | Olist Brazil in `fulfilliq`. Maya already knew this. 9 raw tables; 3,095 sellers; 99,441 orders; purchases 2016-09-04 to 2018-10-17. | Do not add tables that were not built. |
| Original metric request | Confirmed (superseded) | Late delivery rate by seller for last month, on this Brazil extract. | Valid columns exist; the window is not usable. |
| Analysis period | Confirmed constraint | Purchases 1 January 2018–31 August 2018, after rejecting last month because Sep–Oct 2018 have 20 purchases combined. | Do not use 2016, Sep–Oct 2018, or a partial edge month as a comparable period. |
| Geography | Confirmed constraint | All seller states in `raw_sellers`. Not SP-only. | Slice with `seller_state` / `seller_city` if needed. Do not join raw `raw_geolocation`. |
| Eligible orders | Confirmed constraint | `order_status = 'delivered'` only. | Other statuses are out. Missing delivery dates are expected there. |
| Eligible sellers | Confirmed constraint | `raw_order_items.seller_id` on those delivered orders. | 775 orders have no item row and cannot contribute a seller. |
| Plan / featured columns | Confirmed constraint (absence) | Maya knows these are ops, not columns. | Do not invent plan-status or first-party filters. |
| Minimum volume | Accepted provisional assumption | At least 30 delivered orders for that seller in the analysis window, after Maya saw the profile coverage table. Median seller volume is 6. | Working floor only. Keep the denominator. Do not silently change it. |
| Official on-time target | Open question | 95 percent mentioned, not signed. | Do not embed 95 percent or the descriptive 8.11 percent late share. |
| Acceptable vs unacceptable | Confirmed constraint (qualitative) | Occasional misses vs a pattern she would put on a 30-day plan. No cutoff percent. | Stage 3 designs measurement; it does not invent a pass line. |
| Staffing | Confirmed constraint | About 20 concurrent plans; no extra budget. | Lists longer than about 20 are not operable. |
| Authority | Confirmed constraint | Enroll, AM contact, recommend offboarding. Cannot terminate or change fees. | Output is an enrollment list. |
| Reviews / payments / categories | Confirmed constraint | Out of this primary decision. | Do not require those joins to answer the framing question. |
| Evidence standard | Confirmed constraint | VP-defensible; complete 2018 window; volume floor; delivered only; state attribution limits. | Do not hide data-quality limits. |
| 8 delivered orders missing customer-delivery date | Open question | 96,470 have both timestamps. | Stage 3 declares whether the 8 drop. |
| Lateness definition | Open question | Columns exist; Maya did not approve a formula or timestamp vs date. | Do not lock actual greater than estimated from the profile’s descriptive note. |
| Anomalies | Open question | 166 carrier-before-purchase; 23 delivery-before-carrier; 4 item rows with 2020 shipping-limit dates. | Flag or exclude; keep QA counts. |
| Grain | Open question | Multi-item, possible multi-seller orders. Profile suggests seller-order grain after consolidating items. | Stage 3 must declare grain. |
| Live MySQL vs source profile | Open question | Profile is source-file based. Context-package grand total 1,450,922 is an arithmetic error; corrected sum is 1,550,922. | Stage 4 reconciles to MySQL. |

## Decision Authority and Available Actions

Maya owns enrollment. She can leave a seller on standard terms, enroll them in the 30-day plan, change featured placement as an operations step, ask account management to call, and recommend offboarding to the VP.

She cannot terminate contracts, change fees, add capacity, use September–October 2018 as last month, or enroll more than about 20 sellers at once.

## Accepted Provisional Assumptions

- For this fictional project only, a seller must have at least 30 delivered orders with purchase timestamps in 1 January 2018–31 August 2018. Maya accepted this after seeing the Data Profile coverage table. It is not a signed SLA.

No other numeric cutoff was accepted. The profile’s descriptive late share (7,826 / 96,470, 8.11 percent) is not a KPI.

## Open Questions

Stage 3 must not silently decide these:

1. Official on-time or late-delivery target, including 95 percent.
2. Lateness formula and timestamp vs calendar-date precision (customer delivery vs estimate, and/or shipping-limit vs carrier).
3. Treatment of 8 delivered orders missing customer-delivery timestamps.
4. Treatment of 166 + 23 event-sequence anomalies and 4 item rows with 2020 shipping-limit dates.
5. Exact grain (order vs seller-order vs item).
6. Live MySQL agreement with the source-file profile, including the corrected 1,550,922 row total.

## Stage 3 Handoff

* **Final business decision:** Maya, as Director of Marketplace Seller Operations, will decide by 18 September 2026 which sellers in the FulfillIQ Olist Brazil database, if any, to enroll in a 30-day late-fulfillment performance plan rather than leave on standard terms, using delivered orders those sellers fulfilled with `order_purchase_timestamp` from 1 January 2018 through 31 August 2018.
* **Final framing question:** Among sellers in the FulfillIQ Olist Brazil database who fulfilled delivered orders with purchase timestamps from 1 January 2018 through 31 August 2018, which sellers show late-fulfillment performance that would support Maya’s decision to enroll them in a 30-day performance plan, rather than leave them on standard terms?
* **Decision owner:** Maya Chen, Director of Marketplace Seller Operations (fictional).
* **Available actions:** Monitor / standard terms; enroll in 30-day plan; featured placement as ops; AM contact; recommend offboarding. Not available: contract termination, fee changes, capacity spend, more than about 20 concurrent plans.
* **Analysis scope:** `fulfilliq` Olist Brazil; delivered orders only; sellers from `raw_order_items.seller_id`; purchases 2018-01-01 through 2018-08-31; all `seller_state` values; no primary use of reviews, payments, categories, or raw geolocation.
* **Decision deadline:** 18 September 2026.
* **Confirmed constraints:** Maya’s original ask was late delivery rate by seller last month on this Brazil extract; that window was rejected because Sep–Oct 2018 is incomplete; delivered-only; no signed 95 percent; about 20 enrollment cap.
* **Accepted provisional assumptions:** At least 30 delivered orders for that seller in the analysis window.
* **Open questions:** Target percent; lateness formula and precision; 8 missing delivery dates; temporal anomalies; grain; live MySQL reconciliation.
* **Evidence standard required for action:** Complete January–August 2018 window, delivered orders, volume floor with denominator, attribution limits stated, no 20-order last-month ranking.

**Source facts Stage 3 may rely on:** 99,441 orders; 112,650 item rows; 3,095 sellers; 96,478 delivered; 96,470 delivered with both delivery timestamps; 775 orders with no items; seller delivered-order median 6; Sep–Oct 2018 combined purchases = 20; no physical foreign keys; context-package grand total 1,450,922 is wrong; profile total 1,550,922 is the corrected sum.

End of Stages 1–2. Do not begin Stage 3 beyond using this file as an input together with the Database Context Package and the Data Profile.
