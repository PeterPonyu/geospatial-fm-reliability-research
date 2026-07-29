#!/usr/bin/env bash
# fetch_data.sh — data + checkpoint acquisition for the decisive-experiment
# arms (NEXT-EXPERIMENTS.md items 1, 2, 4, 5; item 3 already executed, no
# download needed). Idempotent: every step checks for its output before
# downloading/extracting again.
#
# Run from the repo root on a fresh container:
#   bash fetch_data.sh                 # everything
#   bash fetch_data.sh eurosat         # just the EuroSAT-MS asset
#   bash fetch_data.sh so2sat          # just GEO-Bench m-so2sat
#   bash fetch_data.sh checkpoints     # just the HF FM checkpoints
#
# HF acceleration: on AutoDL, prefer academic acceleration:
#   source /etc/network_turbo          # AutoDL-provided proxy (if present)
# Otherwise use the hf-mirror endpoint:
#   export HF_ENDPOINT=https://hf-mirror.com
# Both are safe to leave set for the whole session; huggingface_hub and
# `hf` respect HF_ENDPOINT automatically. See RUNME_CONTAINER.md.
set -euo pipefail
cd "$(dirname "$0")"

WHAT="${1:-all}"

log() { echo "[fetch_data] $*"; }

# --------------------------------------------------------------------------- #
# EuroSAT-MS (needed for arms 4 + 5: DOFA and ViT-S-MAE both re-extract from
# raw EuroSAT-MS tiles; the OTHER encoders' features are already cached on
# disk in experiments/results/eurosat_*/cache/ and DO NOT need this).
# --------------------------------------------------------------------------- #
fetch_eurosat() {
  local zip="data/eurosat_ms/EuroSAT_MS.zip"
  local extracted="data/eurosat_ms/extracted"
  local arr="experiments/results/eurosat_spatial/images_ms.npy"
  if [ -f "$arr" ]; then
    log "EuroSAT-MS already prepared -> $arr (skip)"
    return
  fi
  mkdir -p data/eurosat_ms
  if [ ! -f "$zip" ]; then
    log "downloading EuroSAT_MS.zip (Zenodo 7711810, ~2.0 GB)"
    curl -L -o "$zip" "https://zenodo.org/records/7711810/files/EuroSAT_MS.zip"
  fi
  if [ ! -d "$extracted" ]; then
    log "unzipping EuroSAT_MS.zip"
    mkdir -p "$extracted"
    unzip -q "$zip" -d "$extracted"
  fi
  log "running prepare_eurosat.py (builds images_ms.npy + coords.npy)"
  python3 experiments/eurosat_spatial/prepare_eurosat.py
}

# --------------------------------------------------------------------------- #
# GEO-Bench m-so2sat (needed for arms 1 + 2). If the paired S1/S2 arrays
# already exist under experiments/xsensor_real/arrays/, skip entirely.
# --------------------------------------------------------------------------- #
fetch_so2sat() {
  local arr_dir="experiments/xsensor_real/arrays"
  if [ -f "$arr_dir/s2_train.npy" ] && [ -f "$arr_dir/s1_train.npy" ] \
     && [ -f "$arr_dir/s2_valid.npy" ] && [ -f "$arr_dir/s2_test.npy" ]; then
    log "m-so2sat arrays already prepared -> $arr_dir (skip)"
    return
  fi
  python3 -c "pip" >/dev/null 2>&1 || true
  python3 -c "import geobench" 2>/dev/null || pip install -q geobench
  local data_root="${DATA_ROOT:-$HOME/dataset}"
  local dset_dir="$data_root/geobench/classification_v0.9.1/m-so2sat"
  if [ ! -f "$dset_dir/done.txt" ]; then
    log "downloading GEO-Bench m-so2sat (Zenodo 8276566, ~0.97 GB) -> $dset_dir"
    python3 -c "
from geobench.geobench_download import get_zenodo_record_by_url, download_dataset, IDENTIFIERS
from pathlib import Path
record = get_zenodo_record_by_url(IDENTIFIERS['m-so2sat'])
download_dataset(record['files'], Path('$dset_dir'))
"
  fi
  log "running prep_so2sat.py for train/valid/test"
  DATA_ROOT="$data_root" python3 experiments/xsensor_real/prep_so2sat.py --split train
  DATA_ROOT="$data_root" python3 experiments/xsensor_real/prep_so2sat.py --split valid
  DATA_ROOT="$data_root" python3 experiments/xsensor_real/prep_so2sat.py --split test
}

# --------------------------------------------------------------------------- #
# HF checkpoints. All public/no-auth. hf_hub_download() called inside each
# adapter module already caches to ~/.cache/huggingface/hub -- this function
# just warms that cache up-front so the GPU-arm scripts don't stall mid-run
# on a slow first download. Safe to re-run (hf_hub_download no-ops if cached).
# --------------------------------------------------------------------------- #
fetch_checkpoints() {
  log "warming HF checkpoint cache (Prithvi, Clay, SSL4EO-S12 x2, DOFA)"
  python3 - <<'PYEOF'
import os
for k in list(os.environ):
    if "proxy" in k.lower():
        os.environ.pop(k, None)
from huggingface_hub import hf_hub_download

jobs = [
    # existing arms (already used elsewhere in this repo; re-download is a no-op if cached)
    ("ibm-nasa-geospatial/Prithvi-EO-2.0-300M", "Prithvi_EO_V2_300M.pt"),
    ("wangyi111/SSL4EO-S12", "B13_vitb16_mae_ep99_enc.pth"),
    ("torchgeo/vit_small_patch16_224_sentinel2_all_dino",
     "vit_small_patch16_224_sentinel2_all_dino-36bcc127.pth"),
    # NEW for arms 1 + 5: SSL4EO-S12 ViT-S/16 MAE, S2 (13-band) and S1 (2-band, native SAR)
    ("wangyi111/SSL4EO-S12", "B13_vits16_mae_ep99_enc.pth"),
    ("wangyi111/SSL4EO-S12", "B2_vits16_mae_ep99_enc.pth"),
]
for repo, fn in jobs:
    try:
        p = hf_hub_download(repo, fn)
        print(f"  OK  {repo}/{fn} -> {p}")
    except Exception as e:
        print(f"  FAIL {repo}/{fn}: {type(e).__name__}: {e}")

# Clay v1.5 (gated-ish large file; downloaded via its own repo convention
# elsewhere in this codebase -- see clay_features.find_clay_ckpt()). Not
# fetched here: it is a >4GB manual-agreement asset; see RUNME_CONTAINER.md.

# DOFA: fetched lazily by torchgeo.models.dofa_base_patch16_224(weights=...)
# on first use inside dofa_features.build_dofa_encoder() -- requires
# `pip install torchgeo` (not in requirements.txt, see RUNME_CONTAINER.md).
# Warm it here too if torchgeo is already installed:
try:
    from torchgeo.models import DOFABase16_Weights, dofa_base_patch16_224
    dofa_base_patch16_224(weights=DOFABase16_Weights.DOFA_MAE)
    print("  OK  torchgeo/dofa DOFABase16_Weights.DOFA_MAE")
except ImportError:
    print("  SKIP DOFA weights (torchgeo not installed yet -- pip install torchgeo)")
except Exception as e:
    print(f"  FAIL DOFA weights: {type(e).__name__}: {e}")
PYEOF
}

case "$WHAT" in
  eurosat) fetch_eurosat ;;
  so2sat) fetch_so2sat ;;
  checkpoints) fetch_checkpoints ;;
  all)
    fetch_eurosat
    fetch_so2sat
    fetch_checkpoints
    ;;
  *)
    echo "usage: bash fetch_data.sh [all|eurosat|so2sat|checkpoints]" >&2
    exit 1
    ;;
esac
log "done ($WHAT)"
