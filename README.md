# Geographic coverage debt of frozen Earth-observation foundation models

Code and frozen-feature archive for a **coverage-debt** audit of frozen optical
geospatial foundation models, with a **conditional** target-side conformal
repair. The audit is diagnostic: it prices a labeled target-region slice. It is
not a label-free universal fix.

Reserved DOI: [10.5281/zenodo.21130299](https://doi.org/10.5281/zenodo.21130299)
(draft record; activates on publish).

Companion report card:
[peterponyu.github.io/geospatial-fm-reliability-research](https://peterponyu.github.io/geospatial-fm-reliability-research/).

## Claim

Frozen optical encoders used as off-the-shelf feature extractors lose
conformal-prediction coverage under a real East→West Europe geographic shift.
That loss is **geographic coverage debt**. It is encoder-dependent and is not
the same ranking as accuracy or expected calibration error (ECE).

In-distribution multi-label false-negative rate (FNR) holds at the nominal risk
level. The same conformal risk-control (CRC) arm under the shift does not.
A Mondrian / spatial-Mondrian arm calibrated on a **labeled target-region
slice** restores near-nominal coverage where debt exists. Label-access
ablation attributes the restoration to target-region calibration access, not
to spatial binning by itself.

A preregistered Stage-2 gate required universal restoration (Prithvi and Clay
at two or more risk levels). The gate returned **KILL**. Encoder-dependent
repair is an exploratory reframe of that falsified universal-restoration
hypothesis.

## Geographic split (P33)

The shift is a longitude percentile cut on EuroSAT-MS tile centroids, not an
abstract out-of-distribution slogan.

| Split | Definition | *n* |
| --- | --- | ---: |
| Source | east of **P33 = 4.2°E** (East / Central Europe) | 18,090 |
| Target | west of the cut (Iberian–Atlantic Europe) | 8,910 |

P25 and P50 are percentile guides only. A boundary sweep at P25 / P33 / P40 /
P50 leaves the headline intact. Class priors move across the cut (Pasture is
enriched in the target; Forest, River, and SeaLake are depleted); unlabeled
label-shift corrections still fail to restore coverage.

## Conformal protocol

1. Freeze the encoder (no fine-tuning).
2. Fit a linear probe on frozen features.
3. Run split conformal under the geographic cut.
4. Read a four-number report card before a regional move.

Arms used in the frozen tables:

- **Split (source)** — calibrate on the source region; evaluate on the target.
- **Target-global** — calibrate on a labeled target slice (no spatial bins).
- **Spatial-Mondrian / Mondrian-CRC** — same labeled target slice, with spatial
  or class-conditional bins where the construction supplies them.

Unlabeled remedies in the frozen tables do not close the debt.
Covariate-shift-weighted conformal collapses effective sample size to
0.1–1.6% of the calibration set. Oracle and BBSE label-shift corrections
remain below target-global coverage.

## Report card (Clay v1.5 illustration, α = 0.05)

Clay is the median-accuracy encoder on the five-encoder EuroSAT battery
(mAP 0.502). Cells below are frozen; intervals are seed / bootstrap intervals
from the same tables.

| Question | Value |
| --- | --- |
| In-distribution multi-label FNR (CRC, BigEarthNet-S2) | 0.053 [0.049, 0.056] |
| Geographic debt if deployed uncalibrated (same CRC arm, E→W) | 0.175 [0.143, 0.208] ≈ 3.5× the 0.05 target |
| FNR after a 30% labeled target slice (Mondrian-CRC) | 0.022 [0.015, 0.029]; set size 13.3 → 23.8 of 27 labels |
| Worst class under a healthy marginal (So2Sat LCZ42, LCZ-17, split) | 0.732 [0.692, 0.772]; marginal 0.891 |

On the thirteen-encoder BigEarthNet roster, **13/13** encoders meet the
in-distribution FNR guarantee and **13/13** incur shift debt (FNR 0.130–0.234,
about 2.6–4.7× nominal). Larger prediction sets, not a “better” encoder, buy
FNR back. At *n* = 13 the accuracy–FNR association is Spearman ρ = +0.32
(*p* = 0.28); a five-encoder inversion does not survive the roster.

EuroSAT integrated geographic-debt order (largest to smallest): Prithvi,
DOFA, SSL4EO-DINO, SSL4EO-MAE, Clay. Split coverage at α = 0.05 ranges from
0.833 (Prithvi) to 0.918 (Clay); spatial-Mondrian restores each to
0.951–0.962.

## Encoders

Headline EuroSAT / CRC battery: Clay v1.5, Prithvi-EO-2.0-300M, SSL4EO-S12
DINO, SSL4EO-S12 MAE, DOFA. The BigEarthNet roster adds eight further frozen
optical encoders (SoftCon, CROMA, ResNet50-MoCo/DINO, SSL4EO-MoCo, SSL4EO-MAE
ViT-L). Checkpoints are not stored here; cached frozen features support
CPU-only conformal re-analysis.

## Datasets

| Dataset | Role | Notes |
| --- | --- | --- |
| EuroSAT-MS | Headline geographic split | Optical Sentinel-2 land-cover tiles; P33 construction above. Upstream: Zenodo 7711810. |
| GEO-Bench BigEarthNet-S2 | Multi-label CRC / FNR replication | 27 labels; in-distribution hold, East→West debt, Mondrian-CRC repair. |
| So2Sat LCZ42 | Non-European city-holdout | Local-climate-zone labels. No per-tile lat/lon, so no spatial-Mondrian arm. Worst-class coverage can collapse while the marginal looks healthy. |

Raw tiles are not redistributed. Each dataset keeps its upstream license.
See `DATA_MANIFEST.md` for sizes, SHA-256, and re-download sources of
gitignored bulk artifacts.

## Scope and withheld arms

- Optical Sentinel-2 only.
- Sentinel-1 (optical→SAR) is **withheld**: the in-distribution control failed
  a probe-sanity guard. It is not a negative finding in this archive.
- An optical shift-fingerprint module is omitted until the EuroSAT-MS
  fingerprint is complete. Mixing incomplete multispectral tiles with RGB
  would be dishonest.
- Cross-encoder rankings, planning curves, and the report-card illustration
  are post-hoc on frozen features.

## Code and license

Code is MIT-licensed (`LICENSE`). Citation metadata is in `CITATION.cff`.
Python dependencies are in `requirements.txt`. Figures in the companion are
redrawn from the frozen tables; they are not a dump of experiment outputs.
