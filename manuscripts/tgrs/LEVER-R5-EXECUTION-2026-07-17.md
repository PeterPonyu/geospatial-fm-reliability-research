# LEVER R5 EXECUTION — Protocol-First Reframe + Family-Clustered Sign Test
**Date:** 2026-07-17
**Source lever:** `FINAL-SCORE-R5-2026-07-17.md`, "SINGLE HIGHEST-LEVERAGE REMAINING LEVER" section.
**Files edited:** `manuscripts/tgrs/paper_ieeetran.tex` (primary), `manuscripts/paper.tex` (mirror).
**Backups:** `paper_ieeetran.tex.bak-pre-r5lever`, `paper.tex.bak-pre-r5lever`.
**New artifacts:** `roster_analysis_2026-07-16/population_test_family.py`, `roster_analysis_2026-07-16/population_test_family.json`.

No new experiments, no new GPU compute, no number invention. Every number added to prose traces
to a computed JSON (either the pre-existing `population_test.json` or the new
`population_test_family.json`).

---

## PART 1 — Protocol-first reframe

**(a) Abstract.** Added one deliverable sentence right after the benchmark/roster parenthetical,
naming the four report-card entries the audit actually returns (matches Table XII's four rows
exactly: FNR-if-uncalibrated, FNR-after-repair, efficiency cost, worst-class coverage).

**(b) Intro contribution list.** The list now opens with "Our primary contribution is a reusable
pre-deployment reliability report-card protocol..." The five items that were previously "primary
/ second / third / fourth / fifth contribution" are relabeled "the protocol's first/second/
third/fourth/fifth evidence axis," each with a one-clause tie-back to which report-card entry it
justifies (e.g. the remedy-failure axis "is what fixes the report card's target-slice repair cost
as necessary rather than optional"; the conditional-collapse axis "is exactly what the report
card's hidden-worst-class-coverage entry is designed to catch"). No claim strengthened — same
facts, re-anchored to the protocol.

**(c) Fig. 1 caption.** Retitled "Overview of the pre-deployment reliability report-card protocol
(§IV-B, Table XII)," with the four practitioner-facing numbers stated explicitly. Encoder list
reworded from "one of five frozen ... encoders" to "one of the frozen ... encoders under audit
(five illustrated: ...)" — honest about the graphic showing 5 icons while the audited roster is
13 for the FNR arm. **Figure graphic itself was not touched**, only caption text.

**(d) "No new estimator" honest counterpart.** The literal sentence ("this paper introduces no new
estimator...") is the only occurrence of that exact phrasing in the document; its existing
counter-clause was upgraded from "the contribution is the applied diagnostic and its validated
repair" to "the contribution is the reusable pre-deployment report-card protocol (§IV-B) and the
audited evidence behind it, not conformal machinery" — directly naming the protocol rather than
the vaguer "applied diagnostic."

## PART 2 — Family-clustered sign test (R1.1 pseudo-replication)

**Grouping rule (documented in `population_test_family.py` docstring and inline in the paper):**
family = shared pretraining corpus + method lineage, read off the `fm_label` prefix in the source
roster JSON. All six `ssl4eo_s12_*`-labeled encoders (ViT-S/B/L × DINO/MAE/MoCo, both ResNet50
variants) cluster into **one** family regardless of backbone architecture, because they share the
identical pretraining corpus and the identical BigEarthNet target-shift split. SoftCon (ViT-B/14,
ViT-S/14) and CROMA (Base, Large) are each one family across their size variants. Prithvi, Clay,
DOFA are singleton families. **6 families total** — matches the reviewer's own "~5–6 independent
families" estimate, and is the coarsest (most conservative) grouping defensible from the roster's
own provenance naming.

**Vote rule:** a family votes success only if every member individually agrees in the claimed
direction (unanimous within-family agreement) — the most conservative rule available, since
majority-vote would count a family as a success on weaker evidence.

**Result:** all 13 individual encoders already agree unanimously in both the debt and repair
direction (verified against `population_test.json`), so every one of the 6 families is unanimous
by construction. The family-clustered sign test is therefore **6/6 in both directions**, but at
$p \approx 0.031$ two-sided ($p \approx 0.016$ one-sided) — roughly **130× weaker** than the
$n{=}13$ figure ($p \approx 2.4\times10^{-4}$). It **survives** $\alpha{=}0.05$, but only barely.
One added sentence in the paper (both files, next to the existing sign-test paragraph) reports
this honestly, and explicitly redirects the reader to the 13 per-encoder bootstrap CIs as the
primary evidence rather than the population $p$-value at either $n$.

Numeric check: every number quoted in the new paper sentence (n=6, 6/6, p≈0.031, p≈0.016) was
verified against `population_test_family.json` byte-for-byte before insertion.

---

## Build verification

| | primary (`paper_ieeetran.tex`, IEEEtran) | mirror (`paper.tex`, article) |
|---|---|---|
| Exit code | 0 | 0 |
| Pages before → after | 18 → 18 | 27 → 28 |
| Overfull hbox before → after | 2 → 0 | 4 → 2 |
| Underfull hbox before → after | 107 → 82 | 0 → 0 |

The mirror gained one page (27→28) from the added prose (protocol reframe + family-test sentence);
this is expected content growth, not a formatting break — no new overfull boxes were introduced in
either file, and the primary TGRS file's warning counts actually improved. Both PDFs rebuilt clean.

Visually verified (rendered at 150dpi): abstract page (both files), the sign-test paragraph page
(both files), Table XII / report-card page (primary), and the Fig. 1 caption page (primary). All
render as intended, cross-references (§IV-B, Table XII) resolve correctly, and no text overflows
columns.

Diff against backups confirmed the changes are confined to exactly the 6 planned edit sites per
file (abstract, intro contribution list, Fig. 1 caption, sign-test paragraph, "no new estimator"
sentence — 5 sites — plus the new family-test provenance comment block), with no incidental changes
elsewhere.

---

## Abstract: before / after

**Before:**
> Frozen geospatial foundation models (GFMs) are increasingly deployed as off-the-shelf encoders for
> land-cover and local-climate-zone (LCZ) monitoring, yet practitioners lack guidance on which frozen
> encoder to trust after a regional move, or on how to restore a reliability guarantee once shift breaks
> it. We supply both through a distribution-free reliability audit (split-conformal, finite-sample
> guarantees) of frozen GFMs under real cross-region shift (thirteen encoders on GEO-Bench BigEarthNet-S2
> for the FNR analysis; five on EuroSAT-MS and non-European m-so2sat; the EuroSAT shift is partly a
> within-Europe label-prior shift, ruled out by a class-balanced control as the sole driver). **Every
> frozen encoder meets a multi-label false-negative-rate (FNR) risk-control guarantee in-distribution**,
> yet all thirteen incur a real geographic debt under shift (FNR 2.6–4.7× nominal), bought back with
> larger sets, not a better encoder: FNR robustness rises with set size (Spearman ρ=−0.66, p=0.017), the
> paper's one adequately powered cross-encoder result. [... unchanged through to ...] The audit is
> diagnostic, reusing existing conformal estimators; the preregistration outcome and exploratory-analysis
> disclosures are in §V.

**After:**
> Frozen geospatial foundation models (GFMs) are increasingly deployed as off-the-shelf encoders for
> land-cover and local-climate-zone (LCZ) monitoring, yet practitioners lack guidance on which frozen
> encoder to trust after a regional move, or on how to restore a reliability guarantee once shift breaks
> it. We supply both through a distribution-free reliability audit (split-conformal, finite-sample
> guarantees) of frozen GFMs under real cross-region shift (thirteen encoders on GEO-Bench BigEarthNet-S2
> for the FNR analysis; five on EuroSAT-MS and non-European m-so2sat; the EuroSAT shift is partly a
> within-Europe label-prior shift, ruled out by a class-balanced control as the sole driver). **This audit
> is packaged as a reusable pre-deployment reliability report-card protocol (§IV-B): for any frozen GFM,
> it returns four practitioner-facing numbers before deployment—the in-distribution FNR guarantee, the
> geographic debt that guarantee incurs under shift, the labeled-data cost of repairing that debt with a
> target-region slice, and the worst-class coverage a marginal guarantee alone would hide.** Every frozen
> encoder meets a multi-label false-negative-rate (FNR) risk-control guarantee in-distribution, yet all
> thirteen incur a real geographic debt under shift (FNR 2.6–4.7× nominal), bought back with larger sets,
> not a better encoder: FNR robustness rises with set size (Spearman ρ=−0.66, p=0.017), the paper's one
> adequately powered cross-encoder result. [... unchanged through to ...] The audit is diagnostic, reusing
> existing conformal estimators; the preregistration outcome and exploratory-analysis disclosures are in
> §V.

(Bold marks the only substantive change; everything else in the abstract is byte-identical.)
