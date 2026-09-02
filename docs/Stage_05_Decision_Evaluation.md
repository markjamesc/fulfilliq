# FulfillIQ Stage 5 — Interpretation, Decision Evaluation, and Recommendation

**Document date:** 2 September 2026 (America/Chicago).  
**Decision owner:** Maya Chen, Director of Marketplace Seller Operations (fictional; Stages 1–2).  
**Deadline:** 18 September 2026.  
**Coordinator role:** merge independent reviews against locked Stage 3 rules and executed Stage 4 results. Not a majority vote. Stage 3 + executed CSV/xlsx control. Round-1 and Round-2 notes are decision support, not a new design.

This Stage 5 file interprets executed evidence. It does not reopen Stage 3, does not generate SQL or R, and does not invent metrics.

---

## 1. Files reviewed and the role of each

GitHub repository (optional reference): https://github.com/markjamesc/fulfilliq. Local copies used for this write-up live under `/workspace/fulfilliq-s4/` (Stages 1–4 artifacts) and `/workspace/fulfilliq-s5/` (Stage 5 reviews).

### 1.1 Repository files (required inventory)

| Repo path | Role in this decision |
| --------- | --------------------- |
| `README.md` | Project orientation. Not a source of executed rates or actions. |
| `docs/Stages_01_02_Dialogue_and_Handoff.md` | Locks Maya’s decision, framing question, window, delivered-only rule, ~20-plan cap, authority, and what is out of scope (offboarding as this decision; featured placement as a column). Local copy: `/workspace/fulfilliq-s4/Stages_01_02_Dialogue_and_Handoff.md`. |
| `docs/FulfillIQ_Database_Context_Package.md` | What tables and columns exist. Stage 3/4 used this to stay inside `fulfilliq`. Not reopened here. Local copy: `/workspace/fulfilliq-s4/FulfillIQ_Database_Context_Package.md`. |
| `docs/FulfillIQ_Data_Profile.md` | Source-file profile (fan-out, small samples, edge months, descriptive 8.11% late share). Descriptive only; 8.11% is not a KPI. Local copy: `/workspace/fulfilliq-s4/FulfillIQ_Data_Profile.md`. |
| `docs/Stage_03_Measurement_Design.md` | Controlling measurement spec: grain, LFR contract, peer rule (P75 then raise to P90 if clean P75 set >20, do not pad), volume floor, precision/attribution/split-window rules, hypothesis, decision rules. Local copy: `/workspace/fulfilliq-s4/Stage_03_Measurement_Design.md`. |
| `sql/Stage_04_FulfillIQ_Analysis.sql` | Implementation of the Stage 3 spec. Header states the script was **not executed** against a live `fulfilliq` instance. Cited as implementation, **not proof**. Local copy: `/workspace/fulfilliq-s4/Stage_04_FulfillIQ_Analysis.sql`. |
| `output/Stage_04_seller_export.csv` | Executed seller export (source of action counts and enroll IDs after stitching 2 junk city-newline rows). Local copy: `/workspace/fulfilliq-s4/Stage_04_seller_export.csv`. |
| `r/Stage_04_FulfillIQ_R_Analysis.R` | R analysis that ran on 2 September 2026. Assure passed after treating `lfr_date_pct` display rounding as non-fatal (<0.5pp). Rate/flag/action reconciliation passed. Local copy: `/workspace/fulfilliq-s4/Stage_04_FulfillIQ_R_Analysis.R`. |
| `results/2026-09-02/FulfillIQ_R_Evidence_2026-09-02.xlsx` | Executed evidence workbook. Sheets include `enroll`, `watch`, `inconclusive`, `charts`, `QA`, `peer`, `volume`, `state`, plus measured-group sheets (`overall__counts`, `overall__rates`, `seller_id__*`, `seller_state__*`, `volume_band__*`, `action__*`, `below_floor_appendix`, `precision`, `stability`, `attribution`, `lineage`, `overall`, `seller`). Local copy: `/workspace/fulfilliq-s4/FulfillIQ_R_Evidence_2026-09-02.xlsx`. |

SQL is not treated as execution proof. Executed facts below come from the CSV / xlsx (and the Stage 5 evidence pack that transcribed those outputs), not from running the `.sql` file.

### 1.2 Stage 5 review files (read in full)

| File | Role |
| ---- | ---- |
| `/workspace/fulfilliq-s5/round1-grok.md` | Independent Round-1 interpretation (Business Decision Reviewer). Source of the printed ENROLL 18 table (rank, id, state, n, late/eligible, lfr_date, lfr_timestamp). |
| `/workspace/fulfilliq-s5/round1-chatgpt.md` | Independent Round-1 interpretation (Evidence and Interpretation Reviewer). |
| `/workspace/fulfilliq-s5/round1-deepseek.md` | Independent Round-1 interpretation (Technical and Statistical Reviewer). |
| `/workspace/fulfilliq-s5/round2-grok.md` | Grok’s cross-review of the other two Round-1 notes; whether Grok revises. |
| `/workspace/fulfilliq-s5/round2-chatgpt.md` | ChatGPT’s cross-review; whether ChatGPT revises. |
| `/workspace/fulfilliq-s5/round2-deepseek.md` | DeepSeek’s cross-review; whether DeepSeek revises. |
| `/workspace/fulfilliq-s5/pack.txt` | Round-1 evidence pack (locked rules + executed metrics + ENROLL 18 list + options A–G). |

---

## 2. Locked decision, framing question, and constraints

Copied from Stages 1–2 and restated as locked in Stage 3. Not rewritten as a new decision.

**Locked decision (Stages 1–2; Stage 3 “Approved Business Decision”):** Maya, as Director of Marketplace Seller Operations, will decide by 18 September 2026 which sellers in the FulfillIQ Olist Brazil database, if any, to enroll in a 30-day late-fulfillment performance plan rather than leave on standard terms. The list must be informed by delivered orders those sellers fulfilled with `order_purchase_timestamp` from 1 January 2018 through 31 August 2018. The purpose is to reduce late customer deliveries before the VP meeting, without penalizing sellers whose volume is too small or whose orders never delivered. Featured-placement and plan administration are operations outside the database. Offboarding remains a later VP recommendation, not this decision.

**Framing question (Stages 1–2; Stage 3):** Among sellers in the FulfillIQ Olist Brazil database who fulfilled delivered orders with purchase timestamps from 1 January 2018 through 31 August 2018, which sellers show late-fulfillment performance that would support Maya’s decision to enroll them in a 30-day performance plan, rather than leave them on standard terms?

**Constraints that remain locked (do not reopen):**

- Delivered orders only; all `seller_state` values.
- Purchase window 2018-01-01 through 2018-08-31.
- Cap about 20 concurrent 30-day plans; no extra budget.
- Featured placement is ops, not a column.
- Offboarding is a later VP recommendation, not this decision.
- No signed 95% on-time target; do not use the Data Profile’s descriptive 8.11% late share as a cut.
- Volume floor: ≥30 usable seller-orders **after exclusions** (provisional; Stage 3).
- Grain: seller-order, then seller-window (Stage 3 design choice).
- Working lateness: `DATE(actual) > DATE(estimate)`; timestamp twin required (Stage 3 working default).
- Peer rule (Stage 3 Decision Rules): LFR ≥ P75 of n≥30 **and** LFR > seller-order-weighted marketplace LFR; if the clean P75 set >20, raise the enroll bar to P90; do not pad.
- Attribution conflict → inconclusive. Precision conflict (date vs timestamp action) → inconclusive. Split-window unstable → watch. n<30 → standard terms, appendix only.

Stage 4 SQL header (`sql/Stage_04_FulfillIQ_Analysis.sql`) restates the same locks and records that the `.sql` file itself was not live-executed. Proof of the numbers is the executed CSV/xlsx/R run of 2 September 2026.

---

## 3. Executed evidence from CSV and workbook

Facts below are from `output/Stage_04_seller_export.csv` after R assure, and from `results/2026-09-02/FulfillIQ_R_Evidence_2026-09-02.xlsx`. They are the same figures transcribed in `/workspace/fulfilliq-s5/pack.txt` and cited by all three Round-1 reviews. Two junk CSV rows caused by a city newline were stitched; they are **not** extra sellers. Clean seller count = **2,329**.

R (`r/Stage_04_FulfillIQ_R_Analysis.R`) ran successfully on 2 September 2026 after treating `lfr_date_pct` display rounding as non-fatal (<0.5pp). Rate/flag/action reconciliation passed. That is process integrity, not treatment effectiveness.

### 3.1 Marketplace and peer metrics

| Metric | Value | Source |
| ------ | ----- | ------ |
| Eligible seller-orders (`eligible_n` sum) | 53,611 | CSV / pack / xlsx |
| Late seller-orders (`late_n` sum) | 4,084 | CSV / pack / xlsx |
| Overall LFR | 7.62% (4,084 / 53,611) | CSV / pack |
| Clean sellers | 2,329 | CSV after stitching 2 junk rows |
| n≥30 floor sellers | 393 | volume output |
| Below floor | 1,936 | volume output |
| `peer_weighted_mkt_lfr` | 0.07808 (~7.808%) | peer sheet |
| `peer_p75` | 0.10169 (~10.169%) | peer sheet |
| `peer_p90` | 0.14286 (~14.286%) | peer sheet |
| `peer_median` | 0.06667 (~6.667%) | peer sheet |
| `raise_bar_to_p90` | 1 (clean P75 pool >20) | peer / action |
| `pass_p75` | 99 | peer / action |
| `pass_p90` | 40 | peer / action |
| `attribution_conflict` | 0 | QA / action |

Volume bands among **floor** sellers (n≥30): `30_49` = 159; `50_99` = 141; `100_plus` = 93; `below_floor` = 1,936. Check: 159 + 141 + 93 = 393.

### 3.2 Final actions (2,329 sellers)

| Action | n | Notes | Source |
| ------ | - | ----- | ------ |
| enroll | 18 | All reason `p90_and_above_weighted_after_cap` | action / enroll sheet |
| watch | 63 | 51 `split_window_unstable` + 12 `p75_watch_band_after_cap` | action / watch sheet |
| inconclusive | 36 | All `date_vs_timestamp_action_conflict` | action / inconclusive sheet |
| standard_terms | 2,212 | Includes all 1,936 below-floor sellers | action |

Check: 18 + 63 + 36 + 2,212 = 2,329.

`raise_bar_to_p90 = 1` is why the 99 P75-passers are **not** an enrollment list. The operable enroll bar is P90. Eighteen is inside the ~20 concurrent-plan cap. Two slots remain empty. Empty slots are unused capacity, not missing evidence.

**What is given, and what is not:** `pass_p90 = 40` and `enroll = 18` are executed facts. The pack does **not** include a cross-tab of the other 22 P90 passers into watch / inconclusive / standard_terms. Reviewers must not invent that path (coordinator merge; ChatGPT Round 2 is the correct reading).

### 3.3 ENROLL 18 roster

All 18 carry action reason `p90_and_above_weighted_after_cap`. Rank, seller_id, state, eligible_n, late_n/eligible_n, lfr_date, lfr_timestamp from `/workspace/fulfilliq-s5/round1-grok.md` (same table as `pack.txt`). Rank numbers skip; that skip is observed on the printed list. Do not treat skipped ranks as a reconstructed filter of the 40 P90 passers.

| Rank | seller_id | state | eligible_n | late_n / eligible_n | lfr_date | lfr_timestamp |
| ---: | --------- | :---: | ---------: | ------------------- | -------: | ------------: |
| 2 | c3867b4666c7d76867627c2f7fb22e21 | SP | 80 | 23/80 | 0.288 | 0.300 |
| 7 | cac4c8e7b1ca6252d8f20b2fc1a2e4af | SP | 46 | 11/46 | 0.239 | 0.283 |
| 8 | bbad7e518d7af88a0897397ffdca1979 | SP | 38 | 9/38 | 0.237 | 0.237 |
| 9 | beadbee30901a7f61d031b6b686095ad | SP | 64 | 15/64 | 0.234 | 0.250 |
| 11 | ef990a83bbea832f36ebe81376335aa8 | SC | 36 | 8/36 | 0.222 | 0.278 |
| 12 | 1ca7077d890b907f89be8c954a02686a | SP | 56 | 12/56 | 0.214 | 0.268 |
| 14 | abe42c5d03695b4257b5c6cbf4e6784e | RJ | 34 | 7/34 | 0.206 | 0.206 |
| 15 | 729f06993dac8e860d4f02d7088ca48a | SP | 45 | 9/45 | 0.200 | 0.222 |
| 16 | ea566164622c6b439516ab18062c42cd | SP | 46 | 9/46 | 0.196 | 0.217 |
| 17 | e5a3438891c0bfdb9394643f95273d8e | SP | 105 | 20/105 | 0.190 | 0.210 |
| 18 | 06a2c3af7b3aee5d69171b0e14f0ee87 | MA | 389 | 74/389 | 0.190 | 0.231 |
| 26 | e9d99831abad74458942f21e16f33f92 | SP | 32 | 5/32 | 0.156 | 0.188 |
| 28 | c60b801f2d52c7f7f91de00870882a75 | SP | 39 | 6/39 | 0.154 | 0.205 |
| 35 | 643214e62b870443ccbe55ab29a4dccf | SP | 48 | 7/48 | 0.146 | 0.167 |
| 36 | 8b9d6eec4a7eb7d0f9d579ce0b38324d | RJ | 48 | 7/48 | 0.146 | 0.167 |
| 37 | 8f2ce03f928b567e3d56181ae20ae952 | SP | 104 | 15/104 | 0.144 | 0.163 |
| 38 | f7ba60f8c3f99e7ee4042fdef03b70c4 | SP | 175 | 25/175 | 0.143 | 0.160 |
| 39 | 2e90cb1677d35cfe24eef47d441b7c87 | SP | 84 | 12/84 | 0.143 | 0.155 |

State mix of the 18: **SP 14, RJ 2, SC 1, MA 1**. Date-based LFR on this list runs from 0.143 to 0.288 (about 14.3%–28.8%). Composition is a fact. It is not a causal finding that SP causes lateness (ChatGPT Round 1; coordinator).

These 18 are **not** “the worst 18 LFRs,” **not** “the top 18 performers,” and **not** a padded 20. They are the executed enroll class under the locked P90-and-above rule after the remaining screens the pipeline applied. Eighteen is a **rule output**, not a target.

---

## 4. Independent interpretations (Grok, ChatGPT, DeepSeek)

Each model received the same evidence pack independently in Round 1, then the other two Round-1 answers in Round 2. Roles: Grok = Business Decision Reviewer; ChatGPT = Evidence and Interpretation Reviewer; DeepSeek = Technical and Statistical Reviewer. Coordinator merge is in Sections 5 and 9. This section reports each review as written, then notes Round-2 revisions.

### 4.1 Grok (Business Decision Reviewer)

**Round 1 source:** `/workspace/fulfilliq-s5/round1-grok.md`.

**Independent interpretation.** The pipeline did what locked Stage 3 rules required. Marketplace LFR among delivered in-window seller-orders is 7.62% (4,084 / 53,611). On the 393 sellers with n≥30, seller-order-weighted marketplace LFR is 7.81%, P75 10.17%, P90 14.29%. Because the clean P75 pool (99) is above 20, the enroll bar was correctly raised to P90; 99 P75-passers are not an enrollment list. Grok then described 40 sellers who “clear P90 and the weighted-market test,” after which “quality filters then remove the rest,” listing 36 inconclusive, 51 split-window watch, and 12 post-cap P75 watch. Remaining action: enroll 18, watch 63, standard_terms 2,212. Grok’s operational reading of the 18: SP 14 / RJ 2 / SC 1 / MA 1; date LFR 14.3%–28.8% with the bottom on the P90 knife-edge; mixed volume including one large MA seller (06a2c3af…, n=389, 74 late, date LFR 19.0% / timestamp 23.1%); date vs timestamp aligned in direction for all 18 (gaps 0–6 pp did not flip action). Relative to the ~20 cap, 18 is inside the cap and was produced by raise-to-P90 + no-pad, not by filling empty slots.

**Concerns (Round 1).** Statistical: several enroll IDs have n just above 30 (32, 34, 36, 38, 39); four of the 18 sit at 14.3–15.6% date LFR; timestamp LFR is systematically a bit higher (working rule is date-based); 51-seller split-window watch pile. Operational: 18 is near the ~20 limit; the MA n=389 seller is a different workload; 14/18 in SP; watch list of 63 is larger than enroll if “watch” is treated as active monitoring. Historical 2018 LFR is not a forecast and not a treatment-effect estimate. Defensibility: (C) and (D) break locked policy; (B) only with a stated capacity choice, not a rewrite of P90.

**Preliminary recommendation (Round 1):** **(A) enroll the 18.** Guardrails inside A, not as a new statistical rule: treat the MA n=389 seller as a named high-touch case; treat the lowest-n / knife-edge P90 IDs as first to review at day 15; keep 63 watch and 36 inconclusive off the plan roster; do not backfill unused cap slots. Grok called (B) “the only respectable alternative” if Maya’s real constraint is account-manager hours, and offered “roughly the first 10–11 on the printed list” as a capacity trim.

**Confidence (Round 1):** process/rule-compliance **high** (counts reconcile; cap and no-pad respected). Outcome / “these 18 are the right commercial targets” **medium** (small n, P90 edge, outsized MA seller, SP concentration, no causal or forward holdout). Decision confidence for (A) vs other letters: **high** that A is easiest to defend without reopening Stage 3.

**Round 2 revisions** (`/workspace/fulfilliq-s5/round2-grok.md`): **No change of letter — still (A).** Grok adopted ChatGPT’s constraint on claims (clean actionable subset, not “the worst sellers,” not proven 2026 lates, not a treatment-effect result). Grok **rejected** DeepSeek’s ranking-and-weights reconstruction and “early offboarding” phrasing. Grok **kept (B) only as a staffing contingency** if Maya cannot run 18 plans by 18 Sep 2026 — not as a better statistical rule — and acknowledged being too ready in Round 1 to offer (B) as a peer-style alternative. Grok stayed with ChatGPT on the 40→18 path: the pack does not prove the 22 non-enrolled P90 IDs were simply “lower rank.” Confidence stays high that A is the defensible VP choice; medium that these 18 are homogeneous, stable, or currently still late. Grok will not use DeepSeek’s 9.5/8.5 scores.

### 4.2 ChatGPT (Evidence and Interpretation Reviewer)

**Round 1 source:** `/workspace/fulfilliq-s5/round1-chatgpt.md`.

**Independent interpretation.** Executed evidence supports enrolling the 18 already classified enroll, because the pipeline did what Stage 3 required rather than selecting the 20 worst-looking sellers. Relied on: 53,611 eligible / 4,084 late / 7.62% overall LFR; among 393 floor sellers, median 6.667%, P75 10.169%, P90 14.286%; `raise_bar_to_p90=1`; 99 pass P75, 40 pass P90; final actions 18 / 63 / 36 / 2,212; QA reconciliation passed after non-fatal display rounding; all 18 labeled `p90_and_above_weighted_after_cap` with date LFR roughly 14.3%–28.8%. ChatGPT stressed the distinction between 40 P90 passers and 18 final enrollments: peer pass was not sufficient; stability/precision/conflict rules also applied. The 18 are the clean actionable subset of the high-lateness population, not merely the highest observed percentages. Evidence strength varies within the 18 (e.g. 06a2… 74/389 vs denominators in the 30s). SP 14/18 is descriptive, not causal.

**Concerns (Round 1).** (A) Small-denominator uncertainty remains (floor is provisional; several enrolled near n=32–39). (B) Date-vs-timestamp disagreement is material in the broader population (36 inconclusive). (C) Split-window instability is common enough to matter (51 watch). (D) Historical 2018 evidence is not proof of current 2026 performance. (E) SP concentration should not become a geographic conclusion. (F) Do not manufacture capacity usage; remaining two slots are capacity, not evidence.

**Preliminary recommendation (Round 1):** **Option A — enroll the 18** and leave remaining capacity unused. (B) not supported by the executed design (would be a new unpublished screen). (C) conflicts with `raise_bar_to_p90=1`. (D) no analytical justification. (E) ignores actionable differentiation. (F) not warranted; watch/inconclusive already exist for insufficient evidence. (G) out of scope.

**Confidence (Round 1):** **High within the locked Stage 3 framework** (population, floor, P90 escalation, marketplace comparison, quarantined conflicts/instability, 0 attribution conflicts, QA pass, 18 below cap). Not absolute: provisional ≥30, historical window, and denominator mix inside the 18. High that the 18 are appropriate under the specified framework; lower on claims that observed rates are permanent or currently unchanged.

**Round 2 revisions** (`/workspace/fulfilliq-s5/round2-chatgpt.md`): **No revision — remain at Option A.** ChatGPT’s largest disagreement with Grok is the implied 40→18 filtering sequence (“quality filters then remove the rest: 36 inconclusive… 51 are watch”). 36 + 51 already exceeds 40; there is no cross-tab. ChatGPT also rejects Grok’s “first 10–11” as a newly invented cutoff, and treats day-15 review as an operational suggestion, not an inference from the executed evidence. ChatGPT rejects DeepSeek’s “highest-ranked of the 40,” implied volume/weighted-rank tie-breaker, 40→18 reconstruction, “top 18 performers,” “early offboarding triggers,” x/10 scores, and the ~3.1pp / 0.014pp arithmetic. Confidence remains high for the enrollment decision, phrased narrowly: the 18 meet locked criteria; the pack does not show every excluded P90 seller’s path.

### 4.3 DeepSeek (Technical and Statistical Reviewer)

**Round 1 source:** `/workspace/fulfilliq-s5/round1-deepseek.md`.

**Independent interpretation.** Results are internally consistent and procedurally sound relative to locked Stage 3. Eligible base 53,611 and overall LFR 7.62% are cleanly calculated; 393 floor-qualified sellers are a valid peer pool; raise to P90 (14.286%) with `raise_bar_to_p90=1`; all 18 have lfr_date ≥ 14.3%. DeepSeek described the 18 as “the highest-ranked sellers among the 40 who cleared the P90 threshold,” with `after_cap` implying “a defensible tie-breaker/prioritization (likely volume or weighted rank)” used to trim 40 down to 18. Watch 63 = 51 + 12; inconclusive 36 all date-vs-timestamp; standard_terms 2,212 described as 1,936 below-floor plus “276 others who failed peer or stability checks.” Cap compliance: 18 within ~20; no padding.

**Concerns (Round 1).** Small-n at the lower bound (seller rank 26 n=32 and rank 14 n=34); claimed that with n=32 a single additional early delivery shifts LFR by ~3.1 percentage points; seller rank 39 (n=84, lfr_date=14.3%) claimed “only by 0.014 percentage points” above P90; SP 14/18 geographic concentration; 2 junk CSV rows / non-fatal rounding as a minor data-quality tail; 51 + 36 = 87 “who nearly qualified.”

**Preliminary recommendation (Round 1):** **Option A — enroll the 18.** Called A “the only option that fully respects all locked decisions.” Rejected B as not statistically justified; C violates raised P90; D forbidden; E “ignores the clear signal from the top 18 performers”; F unnecessary; G out of scope.

**Confidence (Round 1):** presented as 9.5/10 statistical execution, 7/10 for two lowest-volume and the marginal seller, 8.5/10 overall — **removed by coordinator** (use high/moderate/low, not x/10).

**Round 2 revisions** (`/workspace/fulfilliq-s5/round2-deepseek.md`): **Does not revise — remains firmly with Option A.** DeepSeek disagreed strongly with Grok’s treating (B) as a respectable alternative and with a 10–11 trim. DeepSeek still isolated seller rank 39 as the most fragile single case and still treated opacity of “weighted” 40→18 prioritization as an unresolved interpretational risk. DeepSeek kept the 9.5 / 7 / 8.5 scores and a heightened first-15-days monitoring schedule for n=32, n=34, and seller rank 39. **Coordinator does not adopt** those scores, the 40-trimmed-by-ranking story, the ~3.1pp extra-delivery math, the 0.014pp cushion, “early offboarding,” or “top 18 performers” (see Section 5).

---

## 5. Cross-review: agreements, disagreements, challenges, and resolution

Merge rule: **not majority vote.** Stage 3 Decision Rules + executed CSV/xlsx control. Round 2 is used to drop unsupported claims, not to bargain a different roster.

### 5.1 Agreements (kept)

- All three independent reviews recommend **Option A: enroll the 18**. Do not pad to 20. Do not enroll the P75 band. Offboarding is out of scope.
- Consensus on framing: **18 is a rule output, not a target.** Not “the worst 18.” Not “the top 18 performers.”
- Shared facts: 53,611 / 4,084 / 7.62%; 393 / 1,936; peer 0.07808 / 0.10169 / 0.14286 / 0.06667; `raise_bar_to_p90=1`; 99 / 40; actions 18 / 63 / 36 / 2,212; 51 split-window watch; 36 precision-conflict inconclusive; 0 attribution conflicts; all 18 reason `p90_and_above_weighted_after_cap`; SP 14 / RJ 2 / SC 1 / MA 1; QA passed after non-fatal display rounding.
- Shared cautions: small n near the provisional floor; P90-edge sellers; SP concentration is composition not cause; 2018 window is not 2026 performance; enrollment is not proof the 30-day plan will reduce LFR; unused cap slots must stay empty; do not convert watch/inconclusive into enroll.

### 5.2 Disagreements

| Topic | Grok | ChatGPT | DeepSeek | Coordinator resolution |
| ----- | ---- | ------- | -------- | ---------------------- |
| How 40 P90 became 18 | Round 1 implied quality filters deducted 36 + 51 from the 40 (counts exceed 40; no cross-tab). Round 2 stayed with ChatGPT’s safer reading. | 40 and 18 are facts; path of the other 22 is not shown. | “Highest-ranked of the 40”; `after_cap` implies volume or weighted rank. | **ChatGPT is correct.** 40 `pass_p90` and 18 enroll are facts. Do not reconstruct the other 22. |
| Option (B) | Round 1: respectable capacity alternative, “first 10–11.” Round 2: staffing contingency only, not a peer-style alternative. | Not supported as a new statistical rule; B could be considered only if an external capacity constraint tighter than ~20 existed (none shown). | B is not statistically justified; only A is the evidence-based choice. | **(B) is not a new statistical rule.** Allowed **only** as a staffing contingency if Maya cannot run 18 plans. **Do not invent a 10–11 cutoff.** |
| MA n=389 seller | Ops-load risk (same enroll flag, different workload). | Larger denominator = stronger historical estimate. | Barely used in Round 1. | Both precision and workload readings can be true. Neither changes classification. Do not claim the 389 historical orders require more plan-management effort than 32 — that is a hypothesis, not an executed result (ChatGPT R2). |
| “Performers” language | Corrected DeepSeek in R2. | “Not the 18 worst / clean actionable subset.” | Round 1: “top 18 performers.” | **Remove “top 18 performers.”** They are P90-and-above late sellers who survived the executed screens. |
| 2018 vs Sep 2026 | Adopted ChatGPT’s wording constraint in R2. | Stated explicitly: historical rule-satisfaction, not current propensity. | Almost skipped in R1. | Keep as a **wording and external-validity limit**. Does not reopen Stage 3. Does not by itself justify (F). |
| Offboarding-adjacent talk | Rejected DeepSeek’s phrasing in R2; heightened in-plan review is fine. | Conflicts with locked scope. | Seller #39 watched for “early offboarding triggers.” | **Remove “early offboarding.”** Offboarding is later VP rec (G), not this decision. |

### 5.3 Challenges to the evidence (accepted as cautions, not as roster changes)

- Provisional ≥30 floor still leaves binomial uncertainty on n=32–39 enrollments.
- Several date LFRs sit on the displayed P90 (~14.286%).
- Date vs timestamp still disagrees for 36 other sellers (quarantined as inconclusive); residual 0–6 pp gaps on the 18 did not flip action.
- 51 split-window-unstable sellers show that a high full-period LFR is not automatically persistent.
- 14/18 SP is observed composition; no state-cause finding.
- Two stitched junk CSV rows and non-fatal display-percent rounding are documented data handling; QA passed. Not a reason to defer.
- Watch (63) + inconclusive (36) is larger than enroll (18). If “watch” is active monitoring, ops load is larger than 18 plans.

### 5.4 Unsupported claims removed

**From DeepSeek (removed; do not carry into the recommendation):**

- 40 trimmed by ranking/weights, or “highest-ranked 18 of 40.”
- ~3.1pp from one extra delivery (wrong math: 5/32 vs 4/32 is ~3.1 **if a late flips**, not if n+1 on-time; ChatGPT R2: 5/33 ≈ 15.2%, about 0.5pp).
- 0.014pp above P90 (mixes rounded 14.3% display with 14.286% P90; 12/84 ≈ 0.14286, on the boundary under rounding).
- 9.5 / 7 / 8.5 out of 10 scores.
- “Early offboarding.”
- “Top 18 performers.”
- “Likely volume or weighted rank” as the cap tie-breaker.
- “276 others who failed peer or stability checks” as a single explanation of residual standard_terms (arithmetic 2,212 − 1,936 = 276 is valid; the label packs reasons the export already split).
- “87 sellers who nearly qualified” (51 + 36 = 87 is arithmetic; the labels do not mean “nearly enroll”).

**From Grok (removed or narrowed):**

- Implied 36 + 51 deducted from the 40 P90 (counts exceed 40; no cross-tab). ChatGPT is correct: 40 and 18 are facts; path of the other 22 is not shown.
- “First 10–11” as a B alternative (unsupported cutoff).
- “SP is overloaded” (too strong without staffing data). Supportable: SP concentration could have operational implications.
- Day-15 review of five IDs as if produced by the analysis (operational suggestion only).

**From ChatGPT (narrowed, not removed):** “substantially above the marketplace rate” as a single blob is true vs 7.62% / 7.81% weighted; the bottom of the list is not “substantially” above P90. Distinguish market gap from P90 gap. “(B) not supported by the executed design” is kept as a **statistical** statement; it is not a lock that Maya may never choose a smaller wave for staffing.

### 5.5 How resolved

- **Roster:** enroll the executed 18 (Option A). Do not pad. Do not enroll P75. Do not convert watch/inconclusive.
- **40→18:** state the two facts; refuse a reconstructed cross-tab.
- **(B):** not a new statistical rule; staffing overlay only; no 10–11 cutoff.
- **Language:** targeting under locked 2018 delivered-order rules; not “worst 18”; not “top performers”; not causal plan effect; not 2026 = 2018.
- **Scores:** high / moderate / low only.

### 5.6 Remaining unresolved (not blocking A)

1. **No 40-to-18 cross-tab** in the pack. Fairness questions among the 40 cannot be answered from aggregate counts.
2. **2018 window vs a 2 September 2026 / 18 September 2026 decision.** Historical rule-satisfaction, not current propensity.
3. **Treatment effect of the 30-day plan is unknown.** The analysis selects; it does not estimate intervention effect.
4. **P90-edge and small-n sellers** (including displayed 0.143 on n=84, 12/84, and n=32–39 IDs). Fragility is a monitoring issue, not a license to rewrite the bar after seeing the list.

---

## 6. Findings (fact, interpretation, and limitation)

Each finding is labeled. Sources are the executed CSV/xlsx/pack, Stage 3, Stages 1–2, or reviewer interpretation as noted.

**Finding 1 — Eligible population and overall late-fulfillment rate.**  
- **Fact:** 53,611 eligible seller-orders; 4,084 late; overall LFR 7.62% (4,084/53,611). 2,329 clean sellers after stitching 2 junk city-newline rows. Source: CSV / pack / xlsx; Round-1 notes.  
- **Interpretation:** The decision is being made on a large delivered, in-window seller-order base, not on a 20-order “last month” ranking (Stages 1–2 rejected that window).  
- **Limitation:** This is the locked 2018 delivered-purchase window, not a 2026 operating snapshot.

**Finding 2 — Volume floor was applied.**  
- **Fact:** 393 sellers have n≥30; 1,936 are below floor. Floor volume bands: 30–49 = 159; 50–99 = 141; 100+ = 93. Source: volume output / pack.  
- **Interpretation:** Tiny-sample sellers were not ranked into the plan, matching Maya’s constraint not to penalize small volume (Stages 1–2; Stage 3 volume gate).  
- **Limitation:** ≥30 is a **provisional** floor (Stage 3). n=32 is still a modest denominator.

**Finding 3 — Peer bar was raised to P90.**  
- **Fact:** `peer_weighted_mkt_lfr` 0.07808; `peer_p75` 0.10169; `peer_p90` 0.14286; `peer_median` 0.06667; `raise_bar_to_p90=1`; `pass_p75=99`; `pass_p90=40`. Source: peer sheet / pack.  
- **Interpretation:** Clean P75 >20 triggered the locked raise-to-P90 / do-not-pad rule (Stage 3 Comparison Groups and Decision Rules). The 99 P75-passers are not an enroll list.  
- **Limitation:** Percentiles are data-derived ranking devices, not a signed SLA. 95% and 8.11% remain unused.

**Finding 4 — Final actions after remaining screens.**  
- **Fact:** enroll 18, watch 63 (51 `split_window_unstable` + 12 `p75_watch_band_after_cap`), inconclusive 36 (all `date_vs_timestamp_action_conflict`), standard_terms 2,212; `attribution_conflict=0`. Source: action output / xlsx sheets enroll, watch, inconclusive.  
- **Interpretation:** Passing P90 was not treated as sufficient by the executed action system. Precision conflicts were quarantined; split-window instability was parked as watch. That makes the 18 more defensible than taking all 40 P90 passers or the 99 P75 passers (ChatGPT R1; coordinator).  
- **Limitation:** The pack does not cross-tab the other 22 `pass_p90` sellers. Do not claim a specific filter removed each of them.

**Finding 5 — The 18 enrollments.**  
- **Fact:** All 18 have reason `p90_and_above_weighted_after_cap`. Date LFR 0.143–0.288. States SP 14, RJ 2, SC 1, MA 1. Roster in Section 3.3. Source: enroll sheet / round1-grok.md / pack.  
- **Interpretation:** 18 is the cap-respecting, rule-faithful roster (Option A). Empty slots must not be filled.  
- **Limitation:** Mixed denominators (32 to 389). Several IDs sit near n=30 or on the displayed P90. Rank skips are observed; they are not a published ranking formula for the 40.

**Finding 6 — Date vs timestamp precision.**  
- **Fact:** 36 sellers are inconclusive, all because date and timestamp actions conflicted. Enrolled 18 were not in that bucket. Residual date/timestamp gaps on the 18 exist (examples called out in reviews: rank 12 0.214 vs 0.268; rank 28 0.154 vs 0.205). Source: action output; enroll table.  
- **Interpretation:** The pipeline handled conflicts as Stage 3 required (precision flip → inconclusive). The two definitions are not interchangeable. Timestamp is not a second vote that “buffers” enrollment (coordinator; Grok R2).  
- **Limitation:** Working lateness remains a Stage 3 default, not a Maya business lock.

**Finding 7 — Split-window stability.**  
- **Fact:** 51 sellers are watch for `split_window_unstable`. Source: action / watch sheet.  
- **Interpretation:** A high full-period LFR is not automatically a persistent pattern. This supports not expanding to P75 (ChatGPT R1). The 18 were not flagged split-window-unstable in the executed action table.  
- **Limitation:** Stability is in-sample (Jan–Apr vs May–Aug 2018). It is not a 2026 persistence proof.

**Finding 8 — Attribution.**  
- **Fact:** `attribution_conflict=0`. Source: QA / action.  
- **Interpretation:** The executed single-seller vs all-order screen did not flip any seller into inconclusive for attribution.  
- **Limitation:** Shared delivery clocks remain a design confounder (Stage 3). Zero conflicts is not proof that sellers solely caused delay.

**Finding 9 — QA / data handling.**  
- **Fact:** R ran 2 September 2026; display-percent rounding treated as non-fatal (<0.5pp); rate/flag/action reconciliation passed; 2 junk CSV rows stitched; 2,329 clean sellers. Source: pack; R script; xlsx QA. SQL file was not live-executed (SQL header).  
- **Interpretation:** Process integrity supports using the action table.  
- **Limitation:** Non-fatal rounding tolerance applies to display reconciliation, **not** to a ±0.5pp statistical band around the P90 action threshold (ChatGPT R2). SQL is implementation, not proof.

**Finding 10 — Geography.**  
- **Fact:** 14 of 18 enrolled sellers are SP; also RJ 2, SC 1, MA 1. Source: enroll table / state counts.  
- **Interpretation:** Legitimate observed composition (all states were in scope).  
- **Limitation:** Does not establish that SP causes lateness, that SP operations are overloaded, or that a state policy should change.

**Finding 11 — What this analysis is not.**  
- **Fact:** Locked population is delivered purchases 1 Jan–31 Aug 2018; Maya’s meeting is 18 Sep 2026; Stage 3 hypothesis does not claim the seller is the sole cause of delay and does not estimate plan treatment effect.  
- **Interpretation:** Enrollment is targeting under a pre-locked peer rule.  
- **Limitation:** Do not claim the 30-day plan will reduce lateness in 2026. Do not claim 2026 performance equals 2018.

---

## 7. Hypothesis evaluation

**Business hypothesis (Stage 3, not rewritten):** Among sellers who meet the approved window, delivered-only rule, and provisional volume floor, some sellers show a late-fulfillment pattern on customer delivery versus the promised estimate that is worse than same-window eligible peers, stable enough not to be a one-half spike, and not an artifact of grain or timestamp anomalies. Those sellers are the ones whose enrollment in the 30-day plan is supported.

**Operational null (Stage 3, not a p-value):** after grain control, exclusions, and guardrails, no seller presents a VP-defensible enrollment case inside the ~20-plan cap.

**Evaluation against executed results:**

| Stage 3 support test | Executed result | Verdict for the 18 |
| -------------------- | --------------- | ------------------ |
| Volume floor met | All 18 have eligible_n ≥32 (floor 30); 1,936 below-floor were not enrolled | Pass |
| LFR above peer bar after raise | `raise_bar_to_p90=1`; all 18 reason `p90_and_above_weighted_after_cap`; date LFR 0.143–0.288 vs P90 0.14286 | Pass as classified |
| Pattern not only one half-window | 51 split-window-unstable → watch; 18 not in that watch reason | Pass as classified (not flagged) |
| Attribution OK | `attribution_conflict=0` | Pass as classified |
| Precision did not flip action | 36 precision conflicts → inconclusive; 18 not in that bucket | Pass as classified |
| Cap respected; do not pad | 18 ≤ ~20; two slots empty | Pass |

**Coordinator verdict:**

- Hypothesis is **SUPPORTED for the 18** (volume floor, above P90 peer bar after raise, split-window not flagged, attribution OK, precision did not flip action, cap respected).
- Operational null (nobody enrollable) is **NOT supported**.
- Do **not** claim a causal plan effect.
- Do **not** claim 2026 performance equals 2018.

Support is for **targeting under the locked 2018 delivered-order rules**, not for a forecast of plan ROI.

---

## 8. Decision options (A–G)

Options as given to the three reviewers (`pack.txt`). Evaluated against Stage 3 + executed results.

### (A) Enroll the 18

Enroll exactly the 18 sellers classified `enroll`. Leave two ~20-cap slots empty. Keep watch and inconclusive classified.

**Fit to locked rules:** Matches raise-to-P90, no-pad, volume floor, precision/attribution/stability screens, and the ~20 cap. All three AIs recommend A. **Selected.**

### (B) Enroll fewer (e.g. only very high LFR / high volume)

**Not supported as a new statistical rule.** The bar was already raised from P75 to P90 because the P75 pool (99) exceeded ~20. A further unpublished “very high LFR” or “high-volume only” screen would be a post-hoc rule after seeing results.

**Allowed only as a staffing contingency** if Maya cannot run 18 concurrent 30-day plans by 18 September 2026. If used, it must be labeled as staffing, not as “the data now say only the very highest LFRs.” **Do not invent a 10–11 cutoff** (Grok Round 1 offered that figure; ChatGPT Round 2 correctly rejected it; Grok Round 2 withdrew it as a peer-style alternative).

### (C) Enroll the P75 band too

**Reject.** `raise_bar_to_p90=1` because clean P75 = 99 > 20. Enrolling the P75 band would violate the locked raise-to-P90 trigger and blow the cap.

### (D) Pad to 20

**Reject.** Padding was explicitly forbidden (Stage 3: do not fill 20 because the seats exist). Unused slots are capacity, not missing evidence.

### (E) Enroll nobody / monitor only

**Reject.** The operational null is not supported. Eighteen sellers survived the defined eligibility, peer, precision, attribution, stability, and capacity framework. Monitoring everybody would ignore the differentiation the design produced.

### (F) Defer for more data

**Reject as a default.** The window is locked. Watch (63) and inconclusive (36) already exist for sellers whose evidence is unstable or precision-conflicted. Uncertainty elsewhere is not a reason to defer action on the clean enrollment class. External-validity (2018 vs 2026) is a wording limit, not by itself option F.

### (G) Recommend offboarding

**Out of scope.** Stages 1–2 and Stage 3: offboarding is a later VP recommendation, not this decision. Do not preview offboarding triggers in the enrollment memo.

---

## 9. Recommendation

**Proceed with Option A: enroll the 18.**

Maya should enroll the 18 sellers listed in Section 3.3 in the 30-day late-fulfillment plan, and leave all other sellers on their executed classifications (watch 63, inconclusive 36, standard_terms 2,212).

**Why this is the decision the design already authorized**

1. Locked peer rule: if clean P75 >20, enroll at P90, do not pad. Execution: `pass_p75=99`, `raise_bar_to_p90=1`, `pass_p90=40`, enroll 18.
2. The 18 all carry `p90_and_above_weighted_after_cap`. They cleared the executed stability and precision screens as classified (not in the 51 split-window watch reason; not in the 36 precision-conflict inconclusive class). Attribution conflicts = 0. Cap respected with two slots of slack.
3. All three independent reviews remain on A after Round 2. Remaining dissent is about overlays and missing cross-tabs, not about a different letter (Section 13).

**Implementation inside A (not new KPI cuts)**

- 30-day plan for the 18 only.
- Do not fill empty cap slots.
- Keep watch and inconclusive classified; do not convert them to enroll.
- No new KPI cuts (no unpublished n>50, no unpublished LFR>20%, no 10–11 trim presented as statistics).
- Primary monitoring metric remains LFR as `late_n / eligible_n` (Stage 3 metric contract).
- Stop/review if precision would flip the action or volume collapses on an enrolled seller. Maya retains approval (Section 14).
- Optional ops notes that **do not change enrollment status:** the MA seller `06a2c3af7b3aee5d69171b0e14f0ee87` (n=389, 74/389, date LFR 0.190) is the largest historical denominator on the list; 14 of 18 accounts are SP. These are execution-awareness items, not new bars.

**If Maya cannot staff 18 plans:** that is option (B) as a **staffing contingency**, documented as capacity, not as a Stage 3 rewrite. Do not invent a 10–11 statistical cutoff.

---

## 10. Implementation, monitoring, and stop rules

**Implementation**

- Decision date: Maya approve the 18 by **18 September 2026**.
- Seller ops opens 30-day plans for those 18 IDs only.
- Featured placement remains an ops lever, not a data column (Stages 1–2).
- Account-management contact remains available at Maya’s request.
- Do not open plans for the 63 watch or 36 inconclusive sellers.
- Do not pad the two unused ~20-cap slots.

**Monitoring (locked metric, no new bar)**

- Report `late_n / eligible_n` (and the resulting LFR) for the 18 during the plan.
- Working lateness remains the Stage 3 date rule unless Maya later locks timestamp precision.
- Do not invent a new peer bar, a 95% SLA, or an 8.11% cut during the plan.

**Stop / review triggers (operational, not a rewritten P90)**

- If date vs timestamp **would flip the action** for an enrolled seller on the data used for review, stop and return that ID to Maya (Stage 3 precision rule).
- If eligible volume **collapses** so the denominator no longer supports a rate (Stage 3 always-print-fraction / floor logic), stop and review rather than treating a tiny-n spike as the same evidence.
- Maya retains approval to keep, pause, or return a seller to standard terms. Offboarding is **not** a Stage 5 output.

---

## 11. Best existing chart

**Best existing chart:** workbook sheet `charts`, **Figure 1** — Seller LFR vs eligible volume with floor, peer bar, and action.

**File:** `results/2026-09-02/FulfillIQ_R_Evidence_2026-09-02.xlsx`  
**Local copy:** `/workspace/fulfilliq-s4/FulfillIQ_R_Evidence_2026-09-02.xlsx`

**Why this chart, not a reconstructed plot:** it shows **denominator and rate together**, so Maya does not enroll a high rate with a tiny n, and it shows **18 vs watch vs standard** without hiding volume. That is the visual that matches the locked volume-floor + peer-bar + cap logic.

This Stage 5 pack does **not** embed fake chart pixels. Open Figure 1 in the workbook. Other figures on the same sheet (pack: Fig2 n≥30 LFR distribution; Fig3 date vs timestamp; Fig4 split-window) are supporting, not the primary decision visual.

---

## 12. Executive bullets and next actions

**Three executive bullets**

1. Enroll the 18 P90-and-above sellers who cleared stability and precision screens; leave two ~20-cap slots empty.
2. Do not pad; do not enroll the 99 P75 passers; 51 split-window and 36 precision-conflict sellers stay watch/inconclusive.
3. This is targeting under locked 2018 delivered-order rules, not proof the 30-day plan will reduce lateness in 2026.

**Three next actions**

1. Maya approve the 18 by 18 September 2026.
2. Seller ops open 30-day plans; do not convert watch/inconclusive.
3. Report `late_n / eligible_n` for the 18 during the plan; do not invent a new bar.

**Confidence (qualitative; not x/10)**

- **Overall: MODERATE.**
- **HIGH** on process / rule compliance (floor, raise-to-P90, actions, QA pass, cap, no-pad).
- **Lower** on transporting the 2018 window to a September 2026 decision, and on small-n / P90-edge sellers inside the 18.

---

## 13. Remaining dissent after merge

After Round 2, **all three reviewers remain on Option A.** There is no letter-level split to split-the-difference.

**Remaining dissent (not a different recommendation):**

1. **(B) as a staffing overlay.** ChatGPT and DeepSeek treat B as unwarranted unless an external capacity constraint exists (none is shown in the pack). Grok Round 2 keeps B only if Maya cannot staff 18 plans, and agrees it is not a better statistical rule. Coordinator: B is not selected; it remains a labeled contingency, without a 10–11 cutoff.
2. **Reconstructing 40 → 18.** DeepSeek still wants more transparency on “weighted” prioritization. Grok Round 1 implied a filter sequence from the 40; ChatGPT (and Grok Round 2) refuse that reconstruction. Coordinator: **do not reconstruct.** State `pass_p90=40` and `enroll=18`. The missing cross-tab is unresolved, not a reason to change the 18.

No reviewer, after Round 2, recommends C, D, E, F, or G as the primary action.

---

## 14. Human approval

The three-AI recommendation is **decision support**. It is not self-executing.

**Maya Chen, Director of Marketplace Seller Operations** (or another authorized human) **retains approval** of which sellers, if any, enter the 30-day plan.

What this pack supports Maya to approve:

- Enroll the 18 IDs in Section 3.3.
- Leave two ~20-cap slots empty.
- Leave watch 63 and inconclusive 36 in those classes.
- Brief the VP that 18 is a rule output under locked 2018 delivered-order evidence, not a treatment-effect claim for 2026.

What this pack does **not** authorize:

- Padding to 20.
- Enrolling the 99 P75 passers.
- Converting watch or inconclusive to enroll without a new, stated decision.
- Offboarding.
- A new statistical cutoff invented after seeing the list.
- Treating SQL as live-execution proof.

**Approval block**

| Item | Entry |
| ---- | ----- |
| Recommended action | Option A — enroll the 18 |
| Decision owner | Maya Chen, Director of Marketplace Seller Operations |
| Deadline | 18 September 2026 |
| Human approval (name) | _to be signed_ |
| Date signed | _to be signed_ |
| Decision | ☐ Approve enroll-18 &nbsp; ☐ Approve with staffing trim (B, labeled as capacity) &nbsp; ☐ Reject / return |
| Notes | |

Until this block is signed, the 18 remain a **recommended** list, not an executed enrollment.

---

*End of Stage 5 Decision Evaluation. Sources: Stages 1–2 handoff; Stage 3 measurement design; Stage 4 SQL header (implementation only); executed `output/Stage_04_seller_export.csv` and `results/2026-09-02/FulfillIQ_R_Evidence_2026-09-02.xlsx`; `/workspace/fulfilliq-s5/round1-grok.md`, `round1-chatgpt.md`, `round1-deepseek.md`, `round2-grok.md`, `round2-chatgpt.md`, `round2-deepseek.md`, `pack.txt`.*
