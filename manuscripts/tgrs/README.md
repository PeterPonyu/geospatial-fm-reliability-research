# TGRS (IEEEtran) submission package

IEEE Transactions on Geoscience and Remote Sensing (TGRS) two-column port of the canonical
manuscript `../paper.tex`. Forked 2026-07-16 from `../jstars/` (created 2026-07-11 as the JSTARS
port) following a user-ratified venue switch from JSTARS to TGRS — see "Venue switch
(2026-07-16)" below and `../../FRAMING-MEMO-2026-07-10.md`. The `../jstars/` kit is kept intact as
the fallback.

## Canonical source
`../paper.tex` (journal-agnostic `article` class) remains the single source of
truth for content and numbers. `paper_ieeetran.tex` re-expresses the **same**
content in IEEEtran journal format; it does not modify the canonical file.
Every quantitative claim keeps its `% source:` provenance comment pointing at
the on-disk result JSON under `../../experiments/results/`.

## Build
```
latexmk -pdf paper_ieeetran.tex
```
Status at port time: **clean** — `latexmk` exit 0, 0 undefined
citations/references, 0 overfull boxes above ~12 pt, **7 pages** two-column.

## Class / style provenance
- `IEEEtran.cls` (V1.8b 2015/08/26) and `IEEEtran.bst` are provided
  **system-wide by TeX Live** (`texlive-publishers`); they are **not vendored**
  in this directory. On a system without them, install `texlive-publishers` or
  fetch from CTAN: `https://ctan.org/pkg/ieeetran`. TGRS is a subscription IEEE journal (open
  access optional, APC-funded) and uses the standard `\documentclass[journal]{IEEEtran}` — the
  same class/format as JSTARS, so no class-level changes were needed in the port.
- Bibliography style `\bibliographystyle{IEEEtran}` (numeric). Citations use
  natbib in `[numbers]` mode so the shared `\citep`/`\citet` macros render as
  IEEE-style bracketed numbers.

## Bibliography
`shared.bib` and `refs.bib` are **snapshots copied from `../shared.bib` and
`../refs.bib` on 2026-07-11** so this directory is self-contained for
submission. If the upstream bib changes, re-copy them (`../Makefile`'s
`make bib` regenerates `../shared.bib` from the portfolio `shared.bib`).

## Figures
Read from `../figures/` via `\graphicspath{{../figures/}}`; the figure PDFs
(F1, F2, F3, F5, F6) are **not duplicated** here. They are regenerated from the
frozen result JSONs by `../figures/*.R` (`make figures`). Figure numbering
intentionally skips "Figure 4" (former F4 consolidated into Fig. 3).

**Five-encoder F1/F2/F3 (2026-07-13).** F1/F2/F3 now plot all five encoders
(DOFA added as the fifth series, distinctly colored/labeled), closing the review
finding that DOFA was absent from the panels. `../figures/p3_figs.R` reads the
deep-merged figure input
`../../experiments/results/eurosat_stage2_multifm_multialpha/results_fivefm_figures_2026-07-13.json`
(the four battery encoders from the **protected** canonical `results.json`,
byte-equivalent, plus the corrected DOFA block from
`eurosat_stage2_dofa_corrected_2026-07-13/results.json`; the canonical file is
never modified). The prior "DOFA is not shown in this panel" caption signposts
were removed in both twins; captions now describe five encoders and cite the
merged input. Plotted DOFA sanity: α=0.10 split coverage 0.851, spatial-Mondrian
0.913 (matches `DOFA-SUMMARY-corrected-2026-07-13.json`).

## Two-column reflow notes (what changed vs the single-column canonical)
- **Double-column (`table*`)**: the wide tables — boundary-sensitivity sweep
  (`tab:boundary`), CRC (`tab:crc`), and the balanced-probe control
  (`tab:balanced`) — span both columns to fit their many/whitespace-heavy cells.
- **`\resizebox{\columnwidth}{!}{...}`**: the single-column tables that slightly
  exceeded one column — weighted-conformal baseline (`tab:weighted`), m-so2sat
  (`tab:so2sat`), and the class-prior table (`tab:classprior`) — are scaled to
  the column width.
- **Long file paths**: a preamble tweak makes text-mode `\_` breakable, and a
  few `\slash` insertions let long `\texttt{...}` result-JSON paths wrap inside
  the narrow columns (affects rendering only, never math subscripts).
- Nothing content-bearing was dropped in the class change; all 6 tables and 5
  figures, the abstract, keywords, appendix, and Data/Code Availability port
  intact.

## Packaging status (2026-07-13)

- **Compiles clean.** `latexmk -pdf -interaction=nonstopmode paper_ieeetran.tex` → exit 0,
  **8 pages**, 0 undefined references/citations. One overfull hbox at 5.3 pt (well under the
  ~12 pt bar; cosmetic, no fix needed). Bibliography renders in IEEEtran numeric style; all
  figures (F1, F2, F3, F5, F6) resolve from `../figures/`.
- **Cover letter (`cover_letter.md`): refreshed and aligned to the current twin.** Updated
  from **four to five frozen GFMs** (added DOFA: ViT-B/16, `DOFA_MAE`), and replaced the
  "ordering of the four encoders" claim with the corrected 2026-07-13 ranking
  **Prithvi > DOFA > SSL4EO-DINO > SSL4EO-MAE > Clay**, noting the boundary-sweep /
  balanced-control robustness holds for the original four and that DOFA carries the
  second-heaviest debt and is repaired at 2/3 risk levels at the fixed P33 boundary. The
  withheld DOFA m-brick-kiln cell is deliberately not mentioned. Preregistered-criterion
  phrasing (universal restoration for Prithvi and Clay → KILL) verified against the twin, no
  change needed.
- **Keywords:** `\begin{IEEEkeywords}` present, 7 terms (Earth observation; geospatial
  foundation models; conformal prediction; distribution shift; uncertainty quantification;
  reliability; calibration). `\IEEEPARstart` present; section/appendix numbering sane; figure
  numbering intentionally skips "Figure 4" (documented below).
- **Abstract length: trim TAKEN (2026-07-13).** Reduced from ~488 to **249 words** (within the
  IEEE ~250 norm), applied identically to both twins. No disclosed claim was dropped that is not
  still present in the body: the five-encoder ranking (Prithvi > DOFA > SSL4EO-DINO > SSL4EO-MAE >
  Clay), the KILL disclosure (honest exploratory reframe), the label-access negative-control
  result, and the m-so2sat external-validity win all survive in compressed form. The
  temperature-scaling and BBSE/label-shift/class-prior baseline sentences were compressed or moved
  out (all verified present in the body: §"Temperature scaling is insufficient", §"A
  label-shift-adjusted control rules out the class-prior confound"); numeric ECE/set-size ranges
  now live in the body tables. Phrasing was tightened rather than content excised wherever possible.

## Framing decision (2026-07-13, venue re-targeted 2026-07-16)
Per `../../FRAMING-MEMO-2026-07-10.md`, the framing is **CONFIRMED: standalone, no title
change.** (Originally ratified for JSTARS 2026-07-13; the venue itself switched to TGRS on
2026-07-16 — see the memo's "Venue switch (2026-07-16)" section — but the standalone-vs-atlas
framing call and title are venue-independent and carry over unchanged.) The abstract and
Introduction both **lead with the
positive contribution** (the encoder-robustness reliability diagnostic plus the
debt-targeted conditional target-recalibration remedy); the preregistration-KILL
is disclosed *after* the positive contribution, not as the lead. Verified
2026-07-13 in both twins — no reordering was required (the lead was already
positive). Abstract trim decision recorded as **taken** (see above).

## Venue switch (2026-07-16)
Re-targeted from IEEE JSTARS to **IEEE TGRS** (user-ratified). Rationale: JSTARS is mandatory
open-access (~US$1,800 APC); TGRS is subscription-first (APC of US$2,800 only if OA is elected,
otherwise no publication-side fee beyond overlength pages), has a far larger circulation/citation
base within GRSS, and a comparable or faster review cycle. See
`../../FRAMING-MEMO-2026-07-10.md` → "Venue switch (2026-07-16)" for the full rationale and fee
comparison, and `VENUE-MEMO-TGRS-2026-07-16.md` in this directory for the live gate-0/gate-1 audit.
No content, class, or framing changes were required by the switch (same `IEEEtran` journal class,
same standalone framing) — only the running-header (`\markboth`), header comments, and the
Data/Code Availability sentence's venue name, plus the cover letter's scope pitch.

**Overlength fee estimate (2026-07-16):** current build is **17 pages** (`latexmk -pdf`, verified
this session, exit 0). TGRS's 2026 policy gives **10 free pages**; pages 11–17 (7 pages) incur the
**Overlength Page Charge of \$230/page (non-member) or \$200/page (GRSS member)** →
**≈\$1,610 (non-member) / ≈\$1,400 (GRSS member)** if submitted as-is. This is a *submission-time*
estimate on the current draft length, not a floor — final billed length depends on the
post-review camera-ready page count. Trimming toward 10 pages would avoid the OPC entirely; TODO-USER
to decide whether to trim or accept the fee.

## TODO-USER before submission
- Complete the `\author{...}`/`\thanks{...}` block: full name, affiliation
  (department, institution, city, country), contact e-mail, and
  received/revised dates / funding. Placeholders are marked `TODO-USER` in
  `paper_ieeetran.tex`.
- Title / standalone-vs-atlas framing: **resolved** — standalone, no title change
  (see "Framing decision" above and `../../FRAMING-MEMO-2026-07-10.md`).
- Decide whether to trim the manuscript toward TGRS's 10-page free limit or accept the
  overlength charge (see "Venue switch (2026-07-16)" above).
- Optional: elect open access (US$2,800 APC) or submit subscription-only (no APC, reader-side
  paywall) — TGRS, unlike JSTARS, does not mandate OA.
