# Geographic coverage debt of frozen Earth-observation foundation models

Code and frozen-feature archive for a coverage-debt audit of frozen optical
geospatial foundation models, with a conditional target-side conformal
repair. The audit is diagnostic: it prices a labeled target-region slice. It is
not a label-free universal fix.

Public archive: Zenodo DOI [10.5281/zenodo.21130299](https://doi.org/10.5281/zenodo.21130299).

Companion report card:
[peterponyu.github.io/geospatial-fm-reliability-research](https://peterponyu.github.io/geospatial-fm-reliability-research/).

## Thesis

Frozen geospatial foundation models (Prithvi-EO-2.0-300M, Clay v1.5, SSL4EO-S12
DINO and MAE) used as off-the-shelf encoders lose conformal-prediction coverage
under a real East-to-West Europe geographic shift — a "geographic coverage
debt" that is encoder-dependent (Prithvi heaviest, Clay lightest) and monotone
in the encoder's calibration degradation (shift-ECE). A Mondrian conformal arm
calibrated on a labeled target-region slice restores near-nominal coverage
exactly where debt exists; the 2026-07-02 label-access ablation shows the
restoration comes from the labeled target-region calibration access rather than
the spatial binning per se, so the claim is deliberately conditional and
diagnostic, not a universal spatial fix. The result replicates on GEO-Bench
m-bigearthnet (per-label multi-label conformal + a CRC/FNR arm), and the
2026-07-02 boundary sweep (P25/P33/P40/P50 longitude cuts) shows the headline
is robust to the split-boundary choice.

## Code and data

This repository holds the audit code and frozen statistics used to rebuild the
figures. Bulk imagery is not redistributed. Software license: MIT.
