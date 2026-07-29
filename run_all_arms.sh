#!/usr/bin/env bash
# run_all_arms.sh — execute the decisive-experiment arms on a fresh AutoDL
# 4090D container, in cost order: pytest sanity -> CPU arms -> GPU arms
# smallest-first. Idempotent: each step skips if its results.json already
# exists (delete the specific results.json / cache file to force a rerun --
# never hand-edit one in place, per this repo's provenance rule).
#
# Prereqs: bash fetch_data.sh (or run individual arms and let each script's
# own lazy checkpoint/data fetch handle it -- slower, no pre-warmed cache).
#
# Usage:
#   bash run_all_arms.sh              # everything, in order
#   bash run_all_arms.sh test         # pytest only
#   bash run_all_arms.sh arm4         # DOFA 5th encoder only
#   bash run_all_arms.sh arm5         # ViT-S-MAE (+ documented-BLOCKED ViT-B-DINO)
#   bash run_all_arms.sh arm1         # non-degenerate cross-sensor (SSL4EO S1)
#   bash run_all_arms.sh arm2         # non-European m-so2sat coverage debt
set -euo pipefail
cd "$(dirname "$0")"

STEP="${1:-all}"
log() { echo; echo "===== [run_all_arms] $* ====="; }

skip_if_exists() {
  # $1 = path to check; returns 0 (skip) if present
  if [ -f "$1" ]; then
    log "already present -> $1 (skip; delete it to force a rerun)"
    return 0
  fi
  return 1
}

run_tests() {
  log "pytest (arm-agnostic sanity: conformal math + adapter contracts, CPU, synthetic data)"
  python3 -m pytest tests/ -v
  log "smoke_test.sh (repo-wide byte-compile + core-analysis fixture + result-JSON parse)"
  bash smoke_test.sh
}

run_arm3_note() {
  log "arm 3 (weighted-conformal + class-Mondrian baselines): ALREADY EXECUTED"
  echo "  See experiments/results/eurosat_conformal_baselines/results.json"
  echo "  and experiments/results/findings-conformal-baselines-2026-07-02.md."
  echo "  Not re-run here (would overwrite a committed, provenance-stamped result)."
  echo "  To reproduce independently in a scratch location:"
  echo "    python experiments/eurosat_xsensor_calib/run_boundary_sweep.py \\"
  echo "        --mode conformal_baselines --fms prithvi,clay,ssl4eo,ssl4eo_mae"
}

run_arm4() {
  # 5th encoder (DOFA), ~1 GPU-h, ~445 MB checkpoint. Smallest new GPU job.
  local out="experiments/results/eurosat_stage2_multifm_multialpha/results.json"
  log "arm 4: 5th encoder (DOFA) -- densify the debt-vs-robustness curve"
  python3 -c "import torchgeo" 2>/dev/null || pip install -q torchgeo
  python3 experiments/eurosat_xsensor_calib/run_stage2_multi_fm_alpha.py \
    --fms dofa --seeds 5 --alphas 0.05,0.10,0.20 --merge
  echo "  merged into $out (--merge carries over prior FMs; existing FM cells untouched)"
}

run_arm5() {
  # 2x2 backbone-size/objective cell: ViT-S-MAE (real) + ViT-B-DINO
  # (VERIFIED BLOCKED -- no checkpoint exists; the script documents this and
  # exits with verdict=BLOCKED for that FM rather than fabricating one).
  log "arm 5: 2x2 backbone-size/objective cell (ViT-S-MAE; ViT-B-DINO verified BLOCKED)"
  python3 experiments/eurosat_xsensor_calib/run_stage2_multi_fm_alpha.py \
    --fms ssl4eo_vits_mae --seeds 5 --alphas 0.05,0.10,0.20 --merge
  log "arm 5b: confirm ViT-B-DINO is BLOCKED (documented, no download attempted)"
  python3 experiments/eurosat_xsensor_calib/run_stage2_multi_fm_alpha.py \
    --smoke --fms ssl4eo_vitb_dino --limit 2000 || true
}

run_arm1() {
  # Non-degenerate cross-sensor arm, ~1.5 GB total checkpoints (2 x SSL4EO-S12
  # ViT-S/16 MAE), 5 seeds over the So2Sat S1/S2 arrays.
  local out="experiments/results/xsensor_real_calib/results_ssl4eo_s1.json"
  if skip_if_exists "$out"; then return; fi
  log "arm 1: non-degenerate cross-sensor (SSL4EO-S12 native S1 SAR encoder)"
  python3 experiments/xsensor_real/run_real_xsensor_calib.py \
    --backbone ssl4eo_s1 --arrays-dir experiments/xsensor_real/arrays/ \
    --seeds 5 --n-boot 2000
}

run_arm2() {
  # Non-European validation arm: largest new GPU job (3 encoders x ~22k tiles).
  local out="experiments/results/so2sat_coverage_debt/results.json"
  if skip_if_exists "$out"; then return; fi
  log "arm 2: non-European validation (GEO-Bench m-so2sat coverage debt)"
  python3 experiments/so2sat_coverage_debt/run_so2sat_coverage_debt.py \
    --fms prithvi,clay,ssl4eo --alphas 0.05,0.10,0.20 --seeds 5
}

case "$STEP" in
  test) run_tests ;;
  arm3) run_arm3_note ;;
  arm4) run_tests && run_arm4 ;;
  arm5) run_arm5 ;;
  arm1) run_arm1 ;;
  arm2) run_arm2 ;;
  all)
    run_tests
    run_arm3_note
    run_arm4
    run_arm5
    run_arm1
    run_arm2
    log "all arms done"
    ;;
  *)
    echo "usage: bash run_all_arms.sh [all|test|arm3|arm4|arm5|arm1|arm2]" >&2
    exit 1
    ;;
esac
