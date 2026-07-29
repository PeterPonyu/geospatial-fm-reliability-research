# R3 lever execution — population sign test over the 13-encoder debt-and-repair (2026-07-16)

**Lever executed:** FINAL-SCORE-R3-2026-07-16.md, "Single highest-leverage remaining lever" (elevate
within-encoder debt-and-repair from descriptive prose to a stated confirmatory positive).

## Computation
Script: `roster_analysis_2026-07-16/population_test.py` -> `roster_analysis_2026-07-16/population_test.json`.
Input: `roster_pulled_2026-07-16/bigearthnet_crc_arm_roster_2026-07-16.json` (13-encoder bootstrap arm, alpha=0.05).

| test | n_successes | two-sided p | one-sided p | Wilcoxon (one-sided) |
|---|---|---|---|---|
| debt: fnr_sh_crc > nominal (0.05), all 13 | 13/13 | 2.441e-4 | 1.221e-4 | 1.221e-4 |
| repair: fnr_sh_mond <= nominal (0.05), all 13 | 13/13 | 2.441e-4 | 1.221e-4 | 1.221e-4 |

Bootstrap-CI cross-check: all 13 per-encoder `fnr_sh_crc` CIs have `ci_low > 0.05` (debt direction);
all 13 `fnr_sh_mond` CIs have `ci_high < 0.05` (repair direction) — confirms the R3 report's claim.

**Directionality:** used the two-sided p-value as the headline (already decisive, needs no defense).
Verified the one-sided justification against `GEO-ROSTER-EXPANSION-2026-07-16.md` (written before the
n=13 chain launched, ~11:26Z) which already commits to "re-state per-encoder FNR-debt-under-guarantee
as the within-encoder headline" — i.e. the debt-and-repair direction is inherited from the original
n=5 confirmatory arm, not discovered post-hoc in the roster run. Reported as a sensitivity check only.

## Manuscript edits (identical in both builds: `paper.tex` and `jstars/paper_ieeetran.tex`)

**1. Results §III-A** (after "...is restored only with a labeled target-region slice."): added an
~11-sentence paragraph reporting the sign test, Wilcoxon sensitivity check, and bootstrap-CI exclusion
count, explicitly labeled as "a population-level summary computed post-hoc over the frozen,
preregistered per-encoder estimates — the per-encoder numbers are prereg and frozen, but the
population test itself is not."

**2. Limitations §** (after "...the encoder-dependent account built on top of it is hypothesis-generating."):
added one clause: "A distinct firm positive stands beside that negative: the within-encoder
FNR-debt-and-repair pattern is not itself a preregistered population claim, but a distribution-free
sign test computed post-hoc over the thirteen frozen per-encoder estimates confirms it at
p≈2.4×10⁻⁴ in both the debt and the repair direction (§Results)."

No changes to abstract, affiliation/dates block (left as-is per standing decision), or any other section.

## Build verification
- `latexmk -pdf` on both `manuscripts/paper.tex` and `manuscripts/jstars/paper_ieeetran.tex`: exit 0.
- Page counts unchanged: `paper.pdf` 26 pp, `paper_ieeetran.pdf` 17 pp.
- `jstars/paper_ieeetran.pdf` build log: 0 Overfull/Underfull warnings (clean).
- `paper.pdf` build log: 2 Overfull \hbox warnings, both at lines 752–776 (a pre-existing wide table,
  unrelated to this edit — same location/cause before and after).
- Confirmed via `pdftotext` that the new paragraph renders correctly in the built JSTARS PDF.

## Files touched
- `roster_analysis_2026-07-16/population_test.py` (new)
- `roster_analysis_2026-07-16/population_test.json` (new, generated)
- `manuscripts/paper.tex` (2 edits)
- `manuscripts/jstars/paper_ieeetran.tex` (2 edits)
