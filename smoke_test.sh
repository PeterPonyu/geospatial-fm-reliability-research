#!/usr/bin/env bash
# smoke_test.sh — fast (<2 min, CPU-only, no network) sanity check that:
#   1. every Python experiment script byte-compiles,
#   2. the core conformal/calibration analysis code imports and produces
#      correct coverage on a tiny synthetic fixture,
#   3. the key on-disk result JSONs parse and contain their expected
#      top-level keys (READ-ONLY: this script never writes to results).
# Usage:  bash smoke_test.sh
set -euo pipefail
cd "$(dirname "$0")"

echo "== [1/3] byte-compile all experiment Python =="
python3 - <<'EOF'
import py_compile, pathlib, sys
bad = []
for p in sorted(pathlib.Path("experiments").rglob("*.py")):
    if "__pycache__" in p.parts:
        continue
    try:
        py_compile.compile(str(p), doraise=True)
    except Exception as e:
        bad.append((str(p), e))
for p, e in bad:
    print("COMPILE FAIL:", p, e)
sys.exit(1 if bad else 0)
EOF
echo "OK"

echo "== [2/3] core analysis code on tiny synthetic fixture =="
python3 - <<'EOF'
import sys
sys.path.insert(0, "experiments/eurosat_xsensor_calib")
import numpy as np
import run_real_geo_shift_calib as s1  # core single-source-of-truth module

rng = np.random.default_rng(0)
n, k, alpha = 4000, 10, 0.10
# synthetic well-specified probabilistic classifier: labels drawn FROM probs
logits = rng.normal(size=(n, k)) * 2.0
probs = s1.softmax(logits)
y = np.array([rng.choice(k, p=p) for p in probs])
cal, test = slice(0, 2000), slice(2000, None)

# LAC split conformal: empirical coverage must be near 1-alpha on iid data
q = s1.lac_quantile(probs[cal], y[cal], alpha)
sets = s1.lac_predict_sets(probs[test], q)
cov, size = s1.conformal_coverage(sets, y[test])
assert abs(cov - (1 - alpha)) < 0.03, f"LAC coverage {cov} not near {1-alpha}"
print(f"LAC split-conformal coverage on iid fixture: {cov:.3f} (nominal {1-alpha}), avg set size {size:.2f}")

# APS split conformal: guarantee is a LOWER bound; non-randomized APS overcovers
qa = s1.aps_quantile(probs[cal], y[cal], alpha)
sets_a = s1.aps_predict_sets(probs[test], qa)
cov_a, size_a = s1.conformal_coverage(sets_a, y[test])
assert (1 - alpha) - 0.02 <= cov_a <= 1.0, f"APS coverage {cov_a} below nominal {1-alpha}"
print(f"APS split-conformal coverage on iid fixture: {cov_a:.3f} (nominal >= {1-alpha}, non-randomized so conservative), avg set size {size_a:.2f}")

# ECE of a perfectly calibrated synthetic model must be small
e = s1.ece(probs, y)
assert e < 0.05, f"ECE {e} unexpectedly large on calibrated fixture"
print(f"ECE on calibrated fixture: {e:.4f}")

# Mondrian spatial binning round-trip
coords = rng.uniform(low=[35, -10], high=[60, 30], size=(500, 2))  # (lat, lon)
bins0, edges = s1.mondrian_bins(coords)
bins = s1.assign_bins(coords, edges)
assert (bins == bins0).all(), "assign_bins does not reproduce mondrian_bins"
assert bins.shape == (500,) and bins.min() >= 0, "bin assignment failed"
print(f"Mondrian binning: {len(np.unique(bins))} occupied bins (grid {s1.MONDRIAN_GRID}x{s1.MONDRIAN_GRID})")

# boundary-sweep module imports (env-var path indirection intact)
sys.path.insert(0, "experiments/eurosat_xsensor_calib")
import run_boundary_sweep  # noqa: F401
print("run_boundary_sweep imports OK")
EOF

echo "== [3/3] key result JSONs parse with expected top-level keys =="
python3 - <<'EOF'
import json, sys
EXPECT = {
    "experiments/results/eurosat_stage2_multifm_multialpha/results.json":
        {"metadata", "fm_results", "gate", "overall_verdict"},
    "experiments/results/eurosat_boundary_sweep/results.json":
        {"metadata", "fm_results", "gate", "provenance"},
    "experiments/results/eurosat_real_geo_shift_calib/results.json":
        {"metadata", "conformal", "gate", "overall_verdict", "per_seed"},
    "experiments/results/bigearthnet_coverage_debt.json":
        {"metadata", "fm_results", "gate", "overall_verdict"},
    "experiments/results/bigearthnet_perlabel_conformal.json":
        {"experiment", "dataset", "method", "fm_results", "gate"},
    "experiments/results/bigearthnet_crc_arm-exec-2026-06-29.json":
        {"experiment", "dataset", "method", "fm_results", "gate"},
    "experiments/results/xsensor_real_calib/results_prithvi.json":
        {"metadata", "summary", "gate", "overall_verdict", "per_seed"},
}
fail = False
for path, keys in EXPECT.items():
    try:
        with open(path) as f:
            d = json.load(f)
    except Exception as e:
        print(f"FAIL {path}: {e}"); fail = True; continue
    missing = keys - set(d)
    if missing:
        print(f"FAIL {path}: missing top-level keys {sorted(missing)}"); fail = True
    else:
        print(f"OK   {path}")
sys.exit(1 if fail else 0)
EOF

echo "SMOKE TEST PASS"
