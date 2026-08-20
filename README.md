# geospatial-fm-reliability-research

Code archive: Zenodo DOI 10.5281/zenodo.21130299.

Geographic coverage debt of frozen Earth-observation foundation models, and a
conditional target-side conformal repair.

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

## Repository layout

| Path | What it is |
|---|---|
| `manuscripts/paper.tex` | Manuscript source (builds with `lualatex`, 9 pages); `paper.pdf` committed |
| `manuscripts/figures/` | R figure scripts (`p3_figs.R`, `p3_bigearthnet.R`) + vendored `ggtheme.R`; figures F1/F2/F3/F6 are generated ONLY from on-disk result JSONs |
| `experiments/eurosat_xsensor_calib/` | Core EuroSAT-MS runners: `run_real_geo_shift_calib.py` (single source of truth for the conformal/calibration primitives), `run_stage2_multi_fm_alpha.py` (4-FM x 3-alpha headline), `run_boundary_sweep.py` (boundary sweep + label-access ablation), feature extractors (`*_features.py`, `vendor_clay/`) |
| `experiments/eurosat_spatial/` | EuroSAT-MS data prep (`prepare_eurosat.py`) and lat/lon recovery |
| `experiments/bigearthnet_coverage_debt/` | GEO-Bench m-bigearthnet arm: `build_ben_arrays.py`, `run_ben_perlabel_conformal.py`, `run_ben_crc_arm.py` |
| `experiments/xsensor_real/` | So2Sat S2/S1 prep + cross-sensor runner (Stage-0 only; see honest status) |
| `experiments/results/` | All result JSONs, findings files, run logs, and the Stage-2 preregistration (`eurosat_stage2_multifm_multialpha/PREREGISTRATION-stage2.md`) |
| `DATA_MANIFEST.md` | Sizes + SHA256 and re-download sources for every gitignored bulk-data artifact |
| `NEXT-EXPERIMENTS.md` | Deferred experiments (GPU / bulk-download) with costs and exact commands |
| `directions/`, `research/` | Direction documents and research notes |

## Reproducing

### 1. Environment

Python 3.13 (results produced on 3.13.5, Linux):

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt
# provenance stamping (optional but used by run_boundary_sweep.py):
pip install -e ../reliability-commons   # or: export RELIABILITY_COMMONS=/path/to/reliability-commons
```

R (figures only): R >= 4.3 with `ggplot2`, `jsonlite`, `scales`
(figures regenerated 2026-07-02 with R 4.3.3, ggplot2 4.0.3, jsonlite 2.0.0, scales 1.4.0).

### 2. Data

Bulk data is gitignored; every artifact's size, SHA256, and source is in
`DATA_MANIFEST.md`. Datasets live at repo-relative paths except the GEO-Bench
m-so2sat HDF5 source, which is resolved via the `DATA_ROOT` environment
variable (default `${DATA_ROOT}`; layout
`$DATA_ROOT/geobench/classification_v0.9.1/m-so2sat`):

- EuroSAT-MS zip (Zenodo 7711810) -> `data/eurosat_ms/`, unzip to `data/eurosat_ms/extracted/`, then `python experiments/eurosat_spatial/prepare_eurosat.py`
- GEO-Bench m-bigearthnet zip (HF `recursix/geo-bench-1.0`) -> `experiments/bigearthnet_coverage_debt/data/`, then `python experiments/bigearthnet_coverage_debt/build_ben_arrays.py`
- GEO-Bench m-so2sat (via `geobench.geobench_download`) -> `$DATA_ROOT/geobench/...`, then `python experiments/xsensor_real/prep_so2sat.py`

Frozen FM checkpoints are NOT retained on disk; cached frozen-encoder feature
arrays for all headline results are (hashes in `DATA_MANIFEST.md`), so the
conformal analyses below re-run CPU-only without any FM download.

### 3. Run order (headline results)

```bash
# EuroSAT 4-FM x 3-alpha headline (writes experiments/results/eurosat_stage2_multifm_multialpha/)
python experiments/eurosat_xsensor_calib/run_stage2_multi_fm_alpha.py

# Boundary sweep + label-access ablation (CPU, cached features; ~15 min/FM)
python experiments/eurosat_xsensor_calib/run_boundary_sweep.py

# BigEarthNet per-label conformal + CRC arm
python experiments/bigearthnet_coverage_debt/run_ben_perlabel_conformal.py
python experiments/bigearthnet_coverage_debt/run_ben_crc_arm.py
```

### 4. Figures and paper

```bash
cd manuscripts/figures && Rscript p3_figs.R && Rscript p3_bigearthnet.R
cd manuscripts && lualatex paper.tex && lualatex paper.tex
```

### 5. Smoke test

```bash
bash smoke_test.sh   # <1 min, CPU-only, read-only w.r.t. results
```

Byte-compiles all experiment code, exercises the core conformal/calibration
primitives on a synthetic fixture, and validates the key result JSONs.

## Honest status (read before citing anything)

- **Preregistration vs paper:** the Stage-2 machine gate
  (`experiments/results/eurosat_stage2_multifm_multialpha/PREREGISTRATION-stage2.md`)
  returned **KILL** against the original universal-restoration criterion (Clay
  failed the >=2-alpha restoration test). The paper reports the honest
  exploratory *conditional* reframe; any submission must disclose the original
  gate verdict and the reframe.
- **Label-access confound, resolved honestly:** the 2026-07-02 ablation shows
  the coverage restoration is driven by labeled target-region calibration
  access, not spatial binning; `paper.tex` says this explicitly and future
  framing (including the title) must not re-inflate the spatial claim.
- **So2Sat S1 cross-sensor result is degenerate** (Prithvi fed SAR into optical
  slots; S1 accuracy 0.064 vs 17-class chance 0.059, 3 seeds, collapsed CIs).
  It must NOT be cited as a finding; a proper S1-capable rerun is specified in
  `NEXT-EXPERIMENTS.md`.
  merge anything from it into manuscripts.
- Results only change by re-running the analysis code; result JSONs are never
  hand-edited, and figures are generated only from on-disk result JSONs.
- Remaining experimental lift (weighted-conformal baseline, S1-capable
  cross-sensor arm, non-European arm, 5th encoder) is specified with exact
  commands and cost estimates in `NEXT-EXPERIMENTS.md` — not run.

## Citation and license

See `CITATION.cff`. Code is MIT-licensed (`LICENSE`). Datasets keep their own
licenses/terms: EuroSAT (Zenodo record 7711810) and GEO-Bench
(`recursix/geo-bench-1.0`) are public benchmark releases — check their
respective license statements before redistribution; raw data is not
redistributed in this repo.
