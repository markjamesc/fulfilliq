# FulfillIQ — Stages 1 and 2 Dialogue and Handoff

## Scenario

Maya Chen is a fictional Director of Marketplace Seller Operations at FulfillIQ, an e-commerce marketplace and fulfillment analytics environment used for this portfolio project. Q4 peak is approaching. Leadership has been forwarding customer complaints about packages that arrive late and has asked Maya for “seller lateness numbers.” Maya’s first instinct is to request a ranking of late-shipment rates. She understands that some sellers are hurting the customer experience, but she has not yet stated a decision she can take, a population, a deadline, or the actions she is actually authorized to use.

This document records a Stage 1–2 interview between Maya and an AI Analyst. **Maya’s answers are mock business requirements created for the FulfillIQ portfolio project.** They are not live production policy. The AI Analyst does not open the Database Context Package or the Data Profile, does not design KPIs or hypotheses, and does not write SQL or R. Stage 3 begins only after this handoff.

---

## Complete Maya–AI Dialogue

**Maya:** I need late shipment rate by seller for last month. Leadership wants a ranking of who’s slow. Can you just pull that?

**AI Analyst:** I can help, but a ranking is a metric, not a decision. Before we measure anything, I need to know what you would *do* with that ranking. What is going wrong in the business that made leadership ask for this?

**Maya:** Customer complaints about late packages are up. Support is sending me screenshots. Leadership thinks some of our third-party sellers are the problem and they want names. I’m supposed to “do something about seller performance” before peak.

**AI Analyst:** So the problem is late deliveries hitting customers, and the suspected source is a subset of third-party marketplace sellers, with peak coming. Who is asking you to act, and who actually has to live with the action?

**Maya:** My VP of Marketplace. I own seller operations. Support and the CX team will feel it if we get this wrong. Sellers will feel it if we put them on a plan they don’t deserve.

**AI Analyst:** What decision do you personally need to make? Not “see who’s late,” but a yes/no or choose-A-or-B that you will own.

**Maya:** I think I need to decide which sellers we put on a performance plan before Q4. We’ve used a 30-day seller performance plan before: weekly check-ins, they lose featured placement if they stay bad, and if they still fail we can recommend offboarding. I don’t want to blast everyone with a dashboard and then freeze.

**AI Analyst:** That is closer to a decision: enroll specific sellers in a 30-day late-fulfillment performance plan versus leave them on standard terms. Why does that decision matter now, rather than after peak?

**Maya:** Peak will multiply whatever is already late. If we wait until November we will be firefighting. If we hammer good sellers now, we lose GMV going into the season. So the cost of waiting and the cost of over-enrolling are both real.

**AI Analyst:** Who will act on the decision once you make it?

**Maya:** I will. Seller ops executes the plan: I notify the seller, start the 30-day clock, pull featured placement if they stay off-track. Offboarding is not mine alone. I can recommend it to the VP. I cannot terminate a seller contract by myself.

**AI Analyst:** What actions are realistically available to you in the next few weeks? Please list what you can do and what you cannot do.

**Maya:** I can do nothing and keep monitoring. I can enroll a seller in the 30-day performance plan. I can remove featured placement as part of that plan. I can ask account management to call a seller. I can recommend offboarding to the VP. I cannot change the marketplace fee schedule. I cannot add warehouse capacity. I cannot pay sellers to ship faster. I cannot redesign the website.

**AI Analyst:** When must you decide?

**Maya:** I need a recommendation I can take to the VP by Friday, 18 September 2026. If we enroll people, I want the 30-day clock to start before October so we have a reading before peak volume really hits.

**AI Analyst:** Scope: which sellers, orders, products, customers, regions, and time periods are in this, and which are out?

**Maya:** US marketplace only. Third-party sellers, not FulfillIQ first-party catalog. Active sellers, not already suspended. I don’t want a global view. I’m not trying to fix apparel vs electronics as a category strategy. Customers are whoever bought from those US 3P listings. Time period… I said last month because that’s what leadership asked for. I’m not sure last month is long enough.

**AI Analyst:** Last month is a reporting window, not necessarily the right evidence window. If one slow week can put a good seller on a plan, you will over-enroll. What outcome do you want to improve, and what negative outcome must we avoid?

**Maya:** Improve: fewer late deliveries to customers from 3P US sellers before and into peak. Avoid: putting decent sellers on a plan because of a short noisy month, cutting GMV, or missing the actual late sellers because we stared at a vanity ranking.

**AI Analyst:** What evidence would you need before you enroll someone? Would a single ranking of “late rate last month” be enough?

**Maya:** No. I would look stupid if we punish a seller who shipped 12 orders. I need a long enough window, some minimum volume so I’m not chasing noise, and I need to know the delay is the seller’s fulfillment performance, not us holding the order. I also don’t want to act on cancelled orders that never shipped. I don’t have the exact cutoff numbers in my head.

**AI Analyst:** Then your original request, “late shipment rate by seller last month,” is a slide, not the decision. The decision I think you need is this:

*Maya, as Director of Marketplace Seller Operations, will decide by 18 September 2026 whether to enroll currently active US third-party marketplace sellers into a 30-day late-fulfillment performance plan before Q4 peak, in order to reduce late customer deliveries without cutting GMV from sellers whose delays are too noisy, out of scope, or outside her authority to fix.*

Does that name the owner, the action, the group affected, the purpose, and the timing? What do you want changed?

**Maya:** Almost. Say that leaving them on standard terms is the alternative. And say I can recommend offboarding but that is not this decision. This decision is the plan vs standard terms.

**AI Analyst:** Revised decision:

*Maya, as Director of Marketplace Seller Operations, will decide by 18 September 2026 which currently active US third-party marketplace sellers, if any, to enroll in a 30-day late-fulfillment performance plan rather than leave on standard terms, in order to reduce late customer deliveries before Q4 peak without penalizing in-scope sellers whose recent delays are too noisy or outside the actions she is authorized to take. Offboarding remains a later recommendation to the VP, not this decision.*

Do you approve that sentence?

**Maya:** Yes. That is the decision. I approve it.

**AI Analyst:** Before we freeze Stage 1, I need constraints. These will bind Stage 3. If you don’t know, we will leave it open rather than invent it. First: decision deadline. You said 18 September 2026. Confirmed?

**Maya:** Confirmed. VP meeting that Friday.

**AI Analyst:** Analysis period. You were unsure about “last month.” What window should we evaluate performance over?

**Maya:** Use the last 90 days before the analysis run. A month is too jumpy. I don’t want a full year; that mixes last peak into this decision. 90 days is what I’ll stand behind for this project.

**AI Analyst:** I will record “last 90 days before the analysis run” as a confirmed constraint from you, not as my invention. Next: minimum seller or order volume. You said you will not chase tiny volume. Do you have a number?

**Maya:** Not a company rule. I don’t want sellers with a handful of orders. If you need a working floor for this fictional project, use at least 50 shipped orders in that 90-day window. I’ll accept that as a provisional assumption. Stage 3 should not pretend it is a signed SLA.

**AI Analyst:** Recorded as an accepted provisional assumption: at least 50 shipped orders in the 90-day window. Existing performance targets: is there an official on-time or late-delivery target I should treat as law?

**Maya:** Leadership talks like 95% on-time is the vibe. I have not been given a signed seller SLA number for this exercise. Do not treat 95% as a confirmed target. Stage 3 must not bake in a threshold I didn’t approve.

**AI Analyst:** So “95% on-time” is an open question, not a constraint. What counts as acceptable vs unacceptable performance in your own words, without a formula?

**Maya:** Acceptable: a seller who is generally getting paid-for orders to customers on time, with the occasional miss. Unacceptable: a pattern of lateness that I would be willing to put on a 30-day plan and, if needed, take to the VP. I am not giving you a cutoff percentage today.

**AI Analyst:** Include and exclude. Please confirm the population.

**Maya:** Include: currently active US third-party marketplace sellers. Include orders those sellers were responsible for fulfilling. Exclude: sellers already suspended. Exclude: FulfillIQ first-party / owned-catalog fulfillment. Exclude: non-US marketplace. Exclude: orders cancelled before they shipped. Exclude: sellers already on a live performance plan, if we can see that; I don’t want to double-enroll. If we cannot see “already on a plan” in the data, that is an open question, not a fake flag.

**AI Analyst:** Budget, staffing, contractual, or operational limits?

**Maya:** Seller ops can run the 30-day plan for about 20 sellers without extra headcount. If the analysis dumps 80 names, I cannot operationally enroll 80. I will not enroll more than 20. That is a real staffing limit. No extra budget. I cannot change contracts except through the VP for offboarding.

**AI Analyst:** Actions you are authorized to take: we already listed them. Risks and unintended consequences you care about?

**Maya:** False positives: good sellers lose featured placement and GMV. False negatives: a genuinely late seller stays featured into peak. Seller revolt if we look arbitrary. Support load if we do nothing. I also don’t want Stage 3 to “find” a category strategy or a carrier problem and call that my seller plan. If the lateness is not the seller’s fulfillment, I should not enroll them.

**AI Analyst:** How strong does the evidence need to be before you act?

**Maya:** Strong enough that I can defend the list in the VP meeting with more than a one-month ranking. Volume floor, 90 days, US 3P only, shipped orders only. I will not enroll from a single noisy week. I do not need academic proof. I do need to show the list is not random. If Stage 3 cannot separate seller fulfillment delay from other delay, I want that called out rather than a fake ranking.

**AI Analyst:** I will not invent any further constraint. Let me read back the constraint classes, then we freeze Stage 1.

Confirmed from you: decision by 18 September 2026; last 90 days as the analysis period; US 3P active sellers only; exclude first-party, non-US, pre-ship cancellations, already suspended; you can enroll in the 30-day plan, remove featured placement as part of it, recommend offboarding but not execute it; staffing cap of about 20 enrollments; no extra budget; evidence must survive VP scrutiny and must not be a one-month ranking.

Provisional, because you accepted my suggested number: at least 50 shipped orders in the 90-day window.

Open: official on-time / late threshold; whether “already on a performance plan” exists as a usable field; whether lateness can be attributed to seller fulfillment versus other parties in the data we have not opened yet.

**Maya:** That split is fair. I approve the decision and those constraint classes. Mock requirements only, for the portfolio.

**AI Analyst:** Stage 2. We turn the approved decision into one analytical framing question. The question has to support the decision, name the population, name the issue, include the scope you gave, stay neutral, and not sneak in a KPI formula or a 95% line.

Draft 1: *Which US third-party sellers were late last month?* That is your original metric request. It does not support the enroll-or-not decision, it assumes last month, and it has no volume or action.

Draft 2: *Which sellers are below 95% on-time and should be put on a plan?* That embeds an unapproved threshold and assumes the answer is a list of guilty sellers.

Draft 3, the one I want you to consider: *Over the last 90 days, among currently active US third-party marketplace sellers in scope, which sellers’ late-fulfillment performance would justify enrollment in a 30-day performance plan before Q4 peak, rather than remaining on standard terms?*

Plain language: we are not asking “who looks bad on a chart.” We are asking which in-scope sellers, in the window you chose, look like the kind of late-fulfillment problem that would make you use the plan, versus the kind you would leave alone. It does not define “late” as a formula. Stage 3 still has to design measurement. It names US 3P, 90 days, and the two actions: enroll vs standard terms.

**Maya:** Add that we only care about sellers we could actually enroll, meaning not already suspended, not first-party. And don’t say “would justify” as if the model decides. I decide. The question should be what the analysis must answer for me.

**AI Analyst:** Revised: *Over the last 90 days, among currently active US third-party marketplace sellers who are in scope for a new 30-day performance plan, which sellers show late-fulfillment performance that would support Maya’s decision to enroll them before Q4 peak, rather than leave them on standard terms?*

That still stays neutral: it does not say they should be enrolled. It does not put a percentage in the question. It names who is evaluated, what issue, which window, and which decision.

**Maya:** One more tweak. Say “shipped orders those sellers fulfilled” so we are not mixing in cancelled-before-ship. Then I approve it.

**AI Analyst:** Final framing question:

*Over the last 90 days, among currently active US third-party marketplace sellers who are in scope for a new 30-day performance plan, which sellers show late-fulfillment performance on shipped orders they were responsible for fulfilling that would support Maya’s decision to enroll them before Q4 peak, rather than leave them on standard terms?*

Do you approve this as the single primary framing question?

**Maya:** Yes. I approve that question. Do not add a second primary question. Category mix and carrier issues can be comments later. They are not this decision.

**AI Analyst:** Confirmed. We stop here. No KPI design, no hypotheses, no SQL, no R, no database or data-profile review. Stage 3 receives the decision, this question, the constraint table, and the open questions. It may not treat 95% or any other unapproved cutoff as settled.

**Maya:** Good. Use this for the handoff.

---

## Final Business Decision

Maya, as Director of Marketplace Seller Operations, will decide by 18 September 2026 which currently active US third-party marketplace sellers, if any, to enroll in a 30-day late-fulfillment performance plan rather than leave on standard terms, in order to reduce late customer deliveries before Q4 peak without penalizing in-scope sellers whose recent delays are too noisy or outside the actions she is authorized to take. Offboarding remains a later recommendation to the VP, not this decision.

## Final Analytical Framing Question

Over the last 90 days, among currently active US third-party marketplace sellers who are in scope for a new 30-day performance plan, which sellers show late-fulfillment performance on shipped orders they were responsible for fulfilling that would support Maya’s decision to enroll them before Q4 peak, rather than leave them on standard terms?

## Business Constraints

Maya’s answers below are mock business requirements created for the FulfillIQ portfolio project.

| Constraint | Status | Maya’s answer | Stage 3 implication |
| ---------- | ------ | ------------- | ------------------- |
| Decision deadline | Confirmed constraint | Recommendation due Friday, 18 September 2026, for a VP meeting. 30-day plans should be able to start before October. | Do not design a measurement program that cannot inform a decision by that date. |
| Analysis period | Confirmed constraint | Last 90 days before the analysis run. Not last month. Not a full year. | Stage 3 may not substitute a different window without returning to the decision owner. |
| Geography | Confirmed constraint | US marketplace only. | Non-US sellers and orders are out of scope. |
| Seller type | Confirmed constraint | Currently active third-party marketplace sellers. Exclude first-party / owned-catalog fulfillment. Exclude already suspended sellers. | Do not mix 1P fulfillment into a 3P performance-plan list. |
| Order population | Confirmed constraint | Shipped orders the seller was responsible for fulfilling. Exclude orders cancelled before they shipped. | Do not treat pre-ship cancellations as late fulfillments. |
| Already on a performance plan | Open question | Exclude if visible in the data; Maya does not want to double-enroll. If the data cannot show this, do not invent a flag. | Stage 3 must not silently assume an “on plan” attribute exists. |
| Minimum volume | Accepted provisional assumption | Maya did not have a signed rule. She accepted “at least 50 shipped orders in the 90-day window” for this fictional project only. | Use 50 as a working floor. Do not present it as a company SLA. Note it as provisional in Stage 3. |
| Official on-time / late target | Open question | Leadership “vibe” of 95% on-time is not a signed SLA for this exercise. Maya refused to approve a cutoff percentage. | Do not embed 95% or any other unapproved threshold in a KPI or in the framing question. |
| Acceptable vs unacceptable | Confirmed constraint (qualitative only) | Acceptable: generally on-time with occasional misses. Unacceptable: a lateness pattern Maya would put on a 30-day plan. No numeric cutoff given. | Stage 3 designs measurement; it does not invent a pass/fail line Maya did not approve. |
| Staffing / ops capacity | Confirmed constraint | Seller ops can run about 20 concurrent 30-day plans without extra headcount. No extra budget. | A raw list longer than ~20 names is not an operable decision. Rank or otherwise support a cap; do not dump 80 enrollments. |
| Contractual limits | Confirmed constraint | Maya cannot change fee schedules or terminate seller contracts. Offboarding is a VP recommendation only. | Do not frame the output as “sellers to terminate.” |
| Operational limits | Confirmed constraint | Maya cannot add warehouse capacity, pay sellers to ship faster, or redesign the site. | Do not turn the analysis into a capacity or UX project. |
| Evidence standard | Confirmed constraint | Must survive VP scrutiny. Not a one-month ranking. Not a handful of orders. If seller-fulfillment delay cannot be separated from other delay, say so rather than force a ranking. | Stage 3 must not hide attribution limits. |
| Attribution of delay | Open question | Maya will not enroll sellers if lateness is not their fulfillment. Whether the data can support that split is unknown because Stage 3 sources have not been opened here. | Do not invent carrier, warehouse, or customer-caused delay fields. |

## Decision Authority and Available Actions

Maya owns the enrollment decision. She can:

- Leave a seller on standard terms (monitor, no plan).
- Enroll a seller in the 30-day late-fulfillment performance plan.
- Remove featured placement as part of that plan.
- Ask account management to contact a seller.
- Recommend offboarding to the VP of Marketplace.

She cannot:

- Terminate a seller contract on her own.
- Change marketplace fees.
- Add fulfillment capacity or spend budget to buy faster shipping.
- Enroll more sellers than seller ops can run (~20).
- Act on non-US, first-party, already suspended, or pre-ship-cancelled volume as if it were this decision.

## Accepted Provisional Assumptions

- For this fictional project only, a seller must have at least 50 shipped orders in the 90-day analysis window to be eligible for consideration. Maya explicitly accepted this floor. It is not a signed company SLA.

No other AI-proposed numbers were accepted.

## Open Questions

Stage 3 must not silently decide these:

1. Whether an official on-time or late-delivery target exists, including the unofficial 95% figure.
2. Whether “already on a performance plan” is a usable field; if not, double-enrollment risk remains.
3. Whether late delivery can be attributed to the seller’s fulfillment versus other parties; the Database Context Package and Data Profile were not opened in Stages 1–2.
4. Exact product, customer, or carrier cuts beyond US 3P shipped orders; Maya did not authorize a category strategy.
5. How to treat sellers between the qualitative “occasional miss” and “pattern of lateness” without an approved numeric cutoff.

## Stage 3 Handoff

* **Final business decision:** Maya, as Director of Marketplace Seller Operations, will decide by 18 September 2026 which currently active US third-party marketplace sellers, if any, to enroll in a 30-day late-fulfillment performance plan rather than leave on standard terms, in order to reduce late customer deliveries before Q4 peak without penalizing in-scope sellers whose recent delays are too noisy or outside the actions she is authorized to take. Offboarding remains a later recommendation to the VP, not this decision.
* **Final framing question:** Over the last 90 days, among currently active US third-party marketplace sellers who are in scope for a new 30-day performance plan, which sellers show late-fulfillment performance on shipped orders they were responsible for fulfilling that would support Maya’s decision to enroll them before Q4 peak, rather than leave them on standard terms?
* **Decision owner:** Maya Chen, Director of Marketplace Seller Operations (fictional).
* **Available actions:** Monitor / standard terms; enroll in 30-day plan; remove featured placement as part of the plan; request an account-management contact; recommend offboarding to the VP. Not available: contract termination, fee changes, capacity spend, site redesign, >~20 concurrent plans.
* **Analysis scope:** Currently active US third-party marketplace sellers; shipped orders those sellers fulfilled; last 90 days before the analysis run; exclude first-party fulfillment, non-US, pre-ship cancellations, already suspended sellers.
* **Decision deadline:** 18 September 2026.
* **Confirmed constraints:** Deadline; 90-day window; US 3P active population; shipped-only; qualitative acceptable/unacceptable without a formula; ~20 enrollment cap; no extra budget; VP-defensible evidence; no one-month ranking.
* **Accepted provisional assumptions:** ≥50 shipped orders in the 90-day window (fictional working floor only).
* **Open questions:** Official performance target; visibility of current plan status; attribution of delay to seller vs other parties; any further cuts Maya did not authorize; numeric cutoff between noise and a plan-worthy pattern.
* **Evidence standard required for action:** Stronger than a last-month ranking; volume floor and 90-day window; list defensible to the VP; if seller-fulfillment delay cannot be separated from other delay, report that limitation instead of forcing enrollments.

End of Stages 1–2. Do not begin Stage 3 from this document alone beyond using it as an input.
