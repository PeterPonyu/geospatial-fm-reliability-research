"""Tests for the variance-repair fix (EXPANSION-PLAN-2026-07-09.md Sec 2.3
deliverable 2): `experiments/xsensor_real/run_real_xsensor_calib.py`'s
`bootstrap_resample` + `run_seed(vary_seed=...)`, and
`experiments/eurosat_xsensor_calib/report_stage2_variance.py`'s honest
per-seed-spread reporting.

Synthetic data throughout -- no GPU, no network, no real checkpoints.
"""
from __future__ import annotations

import numpy as np
import pytest

import run_real_xsensor_calib as xr


# --------------------------------------------------------------------------- #
# Root-cause confirmation: sklearn LogisticRegression(solver='lbfgs') ignores
# random_state on UNCHANGED data (the actual mechanism, not "torch seeding").
# --------------------------------------------------------------------------- #
def test_lbfgs_logistic_regression_ignores_random_state_on_fixed_data():
    rng = np.random.default_rng(0)
    F = rng.normal(size=(300, 8))
    w = rng.normal(size=(8, 4))
    y = (F @ w).argmax(1)
    coefs = []
    for seed in range(5):
        sc, clf = xr.fit_logistic(F, y, seed)
        coefs.append(clf.coef_.copy())
    for c in coefs[1:]:
        np.testing.assert_allclose(coefs[0], c)  # bit-identical: confirms the root cause


# --------------------------------------------------------------------------- #
# bootstrap_resample: pure resampling utility
# --------------------------------------------------------------------------- #
def test_bootstrap_resample_shape_preserved_and_seed_varies_composition():
    rng = np.random.default_rng(0)
    F = rng.normal(size=(50, 4))
    y = np.arange(50)
    F0, y0 = xr.bootstrap_resample(F, y, seed=0)
    F1, y1 = xr.bootstrap_resample(F, y, seed=1)
    assert F0.shape == F.shape and y0.shape == y.shape
    # with replacement -> some duplicate indices expected (not identical to original order)
    assert not np.array_equal(y0, y)
    assert not np.array_equal(y0, y1), "different seeds must draw different bootstrap samples"


def test_bootstrap_resample_is_deterministic_given_same_seed():
    rng = np.random.default_rng(0)
    F = rng.normal(size=(50, 4))
    y = np.arange(50)
    F0, y0 = xr.bootstrap_resample(F, y, seed=7)
    F0b, y0b = xr.bootstrap_resample(F, y, seed=7)
    np.testing.assert_array_equal(y0, y0b)
    np.testing.assert_allclose(F0, F0b)


# --------------------------------------------------------------------------- #
# run_seed(vary_seed=True) produces genuinely different fitted probes/results
# across seeds on otherwise-FIXED train/valid/test arrays (the exact
# xsensor_real_calib scenario that was previously bit-identical).
# --------------------------------------------------------------------------- #
def _make_fixed_arrays(rng, n_tr=400, n_va=150, n_te=200, d=10, n_classes=5):
    w = rng.normal(size=(d, n_classes))
    F_s2_tr = rng.normal(size=(n_tr, d))
    F_s2_va = rng.normal(size=(n_va, d))
    F_s2_te = rng.normal(size=(n_te, d))
    F_s1_te = rng.normal(loc=1.5, size=(n_te, d))  # some cross-sensor shift
    y_tr = (F_s2_tr @ w).argmax(1)
    y_va = (F_s2_va @ w).argmax(1)
    y_te = (F_s2_te @ w).argmax(1)
    return F_s2_tr, y_tr, F_s2_va, y_va, F_s2_te, y_te, F_s1_te


def test_run_seed_default_vary_seed_off_is_bit_identical_across_seeds():
    """Documents/locks in the ORIGINAL (pre-fix) behaviour when vary_seed is
    left at its default False -- this is the exact anomaly POST-ANALYSIS
    flagged, reproduced deliberately here so the fix's effect (next test) is
    a clean before/after comparison."""
    rng = np.random.default_rng(0)
    arrays = _make_fixed_arrays(rng)
    accs = []
    for seed in range(4):
        r = xr.run_seed(*arrays, seed=seed, alpha=0.1, use_torch_temp=False)
        accs.append(r["in_dist_s2"]["accuracy"])
    assert len(set(accs)) == 1, (
        f"expected bit-identical accuracy across seeds with vary_seed=False, got {accs}")


def test_run_seed_vary_seed_true_produces_genuine_per_seed_variance():
    rng = np.random.default_rng(0)
    arrays = _make_fixed_arrays(rng)
    accs = []
    for seed in range(6):
        r = xr.run_seed(*arrays, seed=seed, alpha=0.1, use_torch_temp=False, vary_seed=True)
        accs.append(r["in_dist_s2"]["accuracy"])
    assert len(set(accs)) > 1, (
        f"vary_seed=True must produce non-identical per-seed accuracy, got {accs}")


def test_run_seed_vary_seed_true_leaves_held_out_test_arrays_untouched():
    """The fix must only perturb the FITTING/CALIBRATION data, never the
    evaluation arrays (F_s2_test/F_s1_test/y_test) -- otherwise cross-seed
    results would no longer be comparable against a fixed yardstick."""
    rng = np.random.default_rng(0)
    F_s2_tr, y_tr, F_s2_va, y_va, F_s2_te, y_te, F_s1_te = _make_fixed_arrays(rng)
    F_s2_te_orig = F_s2_te.copy()
    y_te_orig = y_te.copy()
    F_s1_te_orig = F_s1_te.copy()
    xr.run_seed(F_s2_tr, y_tr, F_s2_va, y_va, F_s2_te, y_te, F_s1_te,
               seed=3, alpha=0.1, use_torch_temp=False, vary_seed=True)
    np.testing.assert_array_equal(F_s2_te, F_s2_te_orig)
    np.testing.assert_array_equal(y_te, y_te_orig)
    np.testing.assert_array_equal(F_s1_te, F_s1_te_orig)


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__, "-v"]))
