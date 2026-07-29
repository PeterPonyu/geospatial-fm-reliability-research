# RUNME_CONTAINER.md — decisive-experiment arms on a fresh AutoDL 4090D container

This is the run sequence for the strengthening arms specified in
`NEXT-EXPERIMENTS.md` (closing the "GRSL-ready now; under-scoped for TGRS"
gap). It assumes a **fresh** AutoDL 4090D container (24 GB VRAM) with only
this repo cloned and `reliability-commons` as a sibling checkout. Every step
is idempotent — re-running skips work whose output already exists.

## 0. What's already done vs what this runbook produces

| Arm | NEXT-EXPERIMENTS item | Status |
|---|---|---|
| Weighted-conformal + class-Mondrian baselines | 3 | **Already executed** (CPU, committed) — `experiments/results/eurosat_conformal_baselines/results.json`. This runbook does NOT re-run it. |
| Non-degenerate cross-sensor (SSL4EO-S12 native S1) | 1 | Code implemented, **not run** (needs GPU + ~1.5 GB checkpoints) |
| Non-European validation (GEO-Bench m-so2sat) | 2 | Code implemented, **not run** (needs GPU + ~1 GB download) |
| 5th encoder (DOFA) | 4 | Code implemented, **not run** (needs GPU + ~445 MB checkpoint) |
| 2x2 backbone cell (ViT-S-MAE / ViT-B-DINO) | 5 | ViT-S-MAE implemented, **not run**. ViT-B-DINO is **verified BLOCKED** — no public Sentinel-2 DINO checkpoint exists for ViT-B anywhere in the SSL4EO-S12 release (checked against the official pretrained-model table on 2026-07-08: DINO is released only for ResNet50 and ViT-S/16). The code raises a documented `RuntimeError` for this cell rather than substituting or fabricating a checkpoint. |

Every new script has a `--smoke` (or `--dry-run`) mode that runs the full
pipeline on synthetic/random data, CPU-only, no network — already verified
in the authoring environment (see the pytest suite in `tests/`, which mocks
every new encoder at the boundary; `python -m pytest` is green with zero
GPU/network dependency).

## 1. Environment

```bash
cd geospatial-fm-reliability-research
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt
pip install -e ../reliability-commons        # or: export RELIABILITY_COMMONS=/path/to/reliability-commons
pip install geobench                          # GEO-Bench download (m-so2sat, m-bigearthnet)
pip install torchgeo                          # NEW: DOFA weights (arm 4) — not in requirements.txt
```

### HuggingFace acceleration (do this before any download)

AutoDL academic acceleration (fastest, if the container image provides it):

```bash
source /etc/network_turbo
```

Otherwise use the hf-mirror endpoint (works everywhere):

```bash
export HF_ENDPOINT=https://hf-mirror.com
```

Either is safe to leave set for the whole session — `huggingface_hub` (and
the `hf` CLI) read `HF_ENDPOINT` automatically; every checkpoint pulled by
this repo is public/no-auth.

## 2. Data + checkpoints

```bash
bash fetch_data.sh          # everything: EuroSAT-MS, GEO-Bench m-so2sat, HF checkpoint warm-up
# or piecewise:
bash fetch_data.sh eurosat       # only needed for arms 4 + 5 (DOFA, ViT-S-MAE re-extract EuroSAT)
bash fetch_data.sh so2sat        # only needed for arms 1 + 2
bash fetch_data.sh checkpoints   # pre-warm HF cache so GPU runs don't stall mid-run
```

Exact sources (see `DATA_MANIFEST.md` for the pre-existing assets; new ones
added by this pass):

| Asset | Source | Size |
|---|---|---|
| EuroSAT-MS zip | Zenodo record 7711810 | ~2.0 GB |
| GEO-Bench m-so2sat | Zenodo 8276566 via `geobench.geobench_download` | ~0.97 GB |
| `wangyi111/SSL4EO-S12` `B13_vits16_mae_ep99_enc.pth` (NEW, arms 1+5, S2 ViT-S MAE) | HF, public | 90.7 MB |
| `wangyi111/SSL4EO-S12` `B2_vits16_mae_ep99_enc.pth` (NEW, arm 1, native S1 SAR ViT-S MAE) | HF, public | 86.3 MB |
| `torchgeo/dofa` `DOFABase16_Weights.DOFA_MAE` (NEW, arm 4) | HF, public, fetched lazily by `torchgeo.models.dofa_base_patch16_224(weights=...)` | ~445 MB |
| Clay v1.5 checkpoint (reused, arm 2's `clay` FM) | `made-with-clay/Clay`, see `clay_features.find_clay_ckpt()` | ~5.16 GB |
| Prithvi-EO-2.0-300M (reused, arms 1+2's `prithvi` FM) | `ibm-nasa-geospatial/Prithvi-EO-2.0-300M` | ~1.2 GB |

`torchgeo/dofa` has TWO files matching `dofa_base_patch16_224-*.pth`
(`-7cc0f413` and `-a0275954`); `DOFABase16_Weights.DOFA_MAE` resolves to the
correct one internally — do not hardcode a filename for it.

## 3. Run order (CPU first, then GPU smallest-first)

```bash
bash run_all_arms.sh          # everything, in the order below
# or one arm at a time:
bash run_all_arms.sh test     # pytest + smoke_test.sh (CPU, ~30s, run this first always)
bash run_all_arms.sh arm3     # prints a note only — already executed, not re-run
bash run_all_arms.sh arm4     # DOFA 5th encoder            (~1 GPU-h,   ~445 MB dl)
bash run_all_arms.sh arm5     # ViT-S-MAE + BLOCKED ViT-B-DINO check (~1 GPU-h, ~91 MB dl)
bash run_all_arms.sh arm1     # SSL4EO-S1 non-degenerate cross-sensor (~1-2 GPU-h, ~177 MB dl)
bash run_all_arms.sh arm2     # non-European m-so2sat coverage debt   (~2-4 GPU-h, largest)
```

Rationale for the order: `test` catches wiring regressions for ~0 GPU cost
before anything expensive runs; arm 3 needs nothing (already done); arms 4
and 5 are the smallest new GPU jobs (single small checkpoint, EuroSAT
tiles already cached on disk from prior runs so only the NEW encoder needs
feature extraction); arm 1 pulls two new checkpoints and extracts over the
~22k-tile So2Sat set for two sensors; arm 2 is the largest (three encoders
over the full So2Sat train/valid/test, ~41k tiles combined).

## 4. Outputs

Every arm writes a **new**, provenance-stamped result JSON — no existing
result JSON is ever hand-edited or overwritten by this runbook:

- `experiments/results/eurosat_stage2_multifm_multialpha/results.json` — arms 4 + 5 `--merge` into this (adds `dofa` / `ssl4eo_vits_mae` FM cells alongside the existing 4; `ssl4eo_vitb_dino` recorded as `blocked_fms`, not a cell).
- `experiments/results/xsensor_real_calib/results_ssl4eo_s1.json` — arm 1 (new file, sibling to the existing `results_prithvi.json`).
- `experiments/results/so2sat_coverage_debt/results.json` — arm 2 (new directory).

Before merging any of these back into the canonical repo checkout that
already has `eurosat_stage2_multifm_multialpha/results.json` committed,
diff the two and confirm the pre-existing FM cells (`prithvi`, `clay`,
`ssl4eo`, `ssl4eo_mae`) are byte-identical — `--merge` is designed to
guarantee this, but verify before treating the container's output as
authoritative.

## 5. Figures / manuscript

Out of scope for this pass — regenerate per the main `README.md` `Figures
and paper` section only after deciding which new arms' results should be
folded into the manuscript.
