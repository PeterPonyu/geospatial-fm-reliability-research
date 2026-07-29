# Reader-Experience Revision — JSTARS geo paper (2026-07-16)

Source: `TYPESET-READER-SCORE-2026-07-16.md` (typesetter 89/100, reader 78/100). Presentation-only pass:
no number, claim, or disclosure changed — only relocated, pointed-to, or made visually clearer. Backups:
`paper.tex.bak-pre-readerpass`, `jstars/paper_ieeetran.tex.bak-pre-readerpass`, and figure PDFs
(`*.bak-pre-readerpass`).

## 1. Stat-dense sentences trimmed to headline + table pointer

Applied to Introduction and Discussion (the Results-section instance next to Table I/II is kept as the
one full-detail location; Abstract and the Limitations disclosure narrative left untouched by design).

**Before** (Introduction): `...the rank correlation over the full roster is only a weak, non-significant
positive ($\mathrm{Spearman}(\mathrm{FNR}_{\mathrm{sh}},\mathrm{mAP})=+0.32$, $p{=}0.28$, $n{=}13$)---...
A companion FNR-versus-set-size tradeoff ($\mathrm{Spearman}=-0.66$, $p{=}0.017$ at $\alpha{=}0.10$)...
one land-cover class is still covered at only $0.850$ under a $0.956$ marginal (the same class in all five
seeds; range $0.826$--$0.871$)---a failure invisible to accuracy and to ECE ($6$ of $10$ pairwise
inversions; partial correlation $\approx0$), reported as a single load-bearing case ($n{=}5$).`

**After**: `...the rank correlation over the full roster is only a weak, non-significant positive (Spearman
$\rho=+0.32$; Table~\ref{tab:fnrdecouple})---... A companion FNR-versus-set-size tradeoff ($\rho=-0.66$ at
$\alpha{=}0.10$; same table)... one land-cover class is still covered at only $0.850$ under a $0.956$
marginal---a failure invisible to accuracy and to ECE, reported as a single load-bearing case
(Table~\ref{tab:condcov}).`

**Before** (Discussion): `...accuracy does not reliably say which encoder is most robust (the least
accurate is the most robust, but at $n{=}13$ the rank correlation is a weak positive, $\rho{=}+0.32$,
$p{=}0.28$); and on per-class conditional coverage, where restoring the marginal guarantee still leaves
one land-cover class covered at $0.850$ under a $0.956$ marginal (seed-stable; range $0.826$--$0.871$)---
neither predictable...`

**After**: `...accuracy does not reliably say which encoder is most robust---the least accurate is the most
robust, but at $n{=}13$ the rank correlation is a weak positive ($\rho{=}+0.32$; Table~\ref{tab:fnrdecouple})
---and on per-class conditional coverage, where restoring the marginal guarantee still leaves one
land-cover class covered at $0.850$ under a $0.956$ marginal (Table~\ref{tab:condcov}), neither
predictable...`

Every trimmed number remains verbatim in the paper (Table~I/II captions and the Results-section prose).

## 2. Orienting paragraph before Tables IV-VIII

Inserted immediately before Table IV, in both files:

> "Tables IV--VIII are a robustness battery, not five independent findings: each holds the frozen encoders
> and the coverage debt fixed and swaps exactly one variable---the correction method (unlabeled
> covariate-shift reweighting in Table IV; label-shift-adjusted reweighting in Table V), the source/target
> geographic cut (Table VI), or the benchmark itself (BigEarthNet's multi-label FNR arm in Table VII; the
> non-European So2Sat benchmark in Table VIII). In every table the single comparison worth making is the
> same one: at the shared $\alpha=0.05$ row, read the source-only ("split") figure against the labeled
> target-side repair figure in that row---the gap between them is the debt each table is stress-testing,
> and it is the only number that would change the paper's claim if it closed."

Tables were not merged: VII and VIII switch benchmark entirely (not just control arm) and none would fit a
combined column layout at the required width, so the orienting paragraph is the fix per the brief's
fallback instruction.

## 3. Limitations lead paragraph

Added directly after `\section{Limitations}`, before the existing text, in both files (4 sentences,
no shortening of anything below it):

> "This section is a single continuous preregistration-disclosure narrative, not a conventional caveats
> list, and it is deliberately long because it is by design as load-bearing as the results themselves. It
> discloses, in order: (i) the paper's one preregistered outcome and how the encoder-dependent claim
> reported in the main text reframes it (the Stage-2 universal-restoration gate); (ii) the power limits of
> every post-hoc decoupling analysis added after that gate...; and (iii) the audit's scope
> boundaries...together with the negative-control battery run to rule out confounds. A first-time reader
> should treat what follows as the paper's own accounting of what its evidence does and does not license,
> not as an appendix of afterthoughts."

## 4. Figure fixes (regenerated at 220 DPI, verified)

- **Fig. 2** (`F7_ben_inversion_n13.pdf`, script `figures/p3_roster_inversion.R`): the mid-mAP cluster
  (SoftCon-ViT-B, CROMA-L, SSL4EO-MAE, plus SSL4EO-DINO and the near-duplicate-mAP SSL4EO-MAE-L) now each
  route through an individual `geom_text_repel` layer with a distinct fixed nudge (a different clock
  position), instead of one shared auto-repel layer. First pass over-nudged SSL4EO-MAE into SSL4EO-MAE-L's
  auto-placed label (they share mAP 0.5496); fixed by also giving SSL4EO-MAE-L its own opposite-corner
  nudge. Re-rendered and visually confirmed at 220 DPI: all 13 labels legible, no touching/overlapping text.
- **Fig. 7** (`F6_bigearthnet_perlabel.pdf`, script `figures/p3_bigearthnet_perlabel.R`): the nominal-
  coverage marker changed from a `shape=95` grey20 dash (`size=7`) to an explicit `geom_segment` spanning
  each facet's tick width, solid black, `linewidth=1.0`, `linetype="dashed"` — still black-only (no colour
  channel spent), now unambiguous at normal print size.

Both scripts re-run via `Rscript`; outputs copied into `manuscripts/figures/`, `jstars/figures/`, and
`jstars/` (root-level duplicate also present there). Pre-fix PDFs backed up as `*.bak-pre-readerpass`.

## Build verification

- `jstars/paper_ieeetran.tex`: `latexmk -pdf`, exit 0, **17 pages** (unchanged), **0** Overfull/Underfull
  warnings, 0 other LaTeX warnings (fresh grep on the full log).
- `paper.tex`: `latexmk -pdf`, exit 0, 26 pages, 1 Overfull hbox — confirmed pre-existing (identical
  warning reproduced from the unedited `.bak-pre-readerpass` copy; a wide CRC table unrelated to this pass).
- Visually inspected (150-200 DPI page renders): pp. 2, 4, 7-8, 10, 13, 14 of the JSTARS PDF — all edited
  passages render cleanly, no overflow, orienting paragraph and Limitations lead land on the intended pages,
  both regenerated figures display correctly in situ.
