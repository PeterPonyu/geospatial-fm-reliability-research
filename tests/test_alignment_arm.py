"""Tests for experiments/xsensor_real/run_alignment_arm.py -- the cross-
encoder alignment arm (EXPANSION-PLAN-2026-07-09.md Sec 2.3 deliverable 3).

Synthetic embeddings throughout -- no GEO-Bench download, no GPU, no real
checkpoints. Mirrors the repo's existing xsensor_real test conventions
(so2sat/xsensor_real modules have no dedicated pre-existing test file, so
this establishes the pattern for this module specifically).
"""
from __future__ import annotations

import numpy as np
import pytest

import run_alignment_arm as aa
import run_real_xsensor_calib as xr


def _make_paired_source_target(rng, n_train=500, n_valid=150, n_test=300,
                               d=20, n_classes=6, s1_noise=2.5):
    """S2-native features drive the labels; S1-native features are a random
    LINEAR transform of S2 plus noise -- i.e. genuinely recoverable by a
    ridge alignment map, but NOT identical (so 'unaligned' transfer should
    be poor while 'aligned' transfer should be much better)."""
    R = rng.normal(size=(d, d))
    w = rng.normal(size=(d, n_classes))

    F_s2_train = rng.normal(size=(n_train, d))
    F_s2_valid = rng.normal(size=(n_valid, d))
    F_s2_test = rng.normal(size=(n_test, d))
    F_s1_train = F_s2_train @ R + rng.normal(scale=s1_noise, size=(n_train, d))
    F_s1_test = F_s2_test @ R + rng.normal(scale=s1_noise, size=(n_test, d))

    y_train = (F_s2_train @ w).argmax(1)
    y_valid = (F_s2_valid @ w).argmax(1)
    y_test = (F_s2_test @ w).argmax(1)
    return (F_s2_train, y_train, F_s2_valid, y_valid, F_s2_test, y_test,
           F_s1_train, F_s1_test)


# --------------------------------------------------------------------------- #
# fit_alignment / align_features: pure ridge-regression contract
# --------------------------------------------------------------------------- #
def test_fit_alignment_recovers_a_known_linear_map():
    rng = np.random.default_rng(0)
    d = 10
    R = rng.normal(size=(d, d))
    F_s1 = rng.normal(size=(2000, d))
    F_s2 = F_s1 @ R  # noiseless linear relationship

    reg = aa.fit_alignment(F_s1, F_s2, ridge_alpha=1e-6)
    F_s2_hat = aa.align_features(reg, F_s1)
    np.testing.assert_allclose(F_s2_hat, F_s2, atol=1e-2)
    assert reg.score(F_s1, F_s2) > 0.999


def test_fit_alignment_low_r2_when_s1_uninformative_about_s2():
    rng = np.random.default_rng(1)
    d = 10
    F_s1 = rng.normal(size=(2000, d))          # independent of F_s2
    F_s2 = rng.normal(size=(2000, d))
    reg = aa.fit_alignment(F_s1, F_s2, ridge_alpha=1.0)
    assert reg.score(F_s1, F_s2) < 0.05


# --------------------------------------------------------------------------- #
# run_seed / summarize: alignment restores coverage vs the unaligned baseline
# --------------------------------------------------------------------------- #
def test_run_seed_returns_all_three_conditions_with_expected_shape():
    rng = np.random.default_rng(2)
    (F_s2_tr, y_tr, F_s2_va, y_va, F_s2_te, y_te,
     F_s1_tr, F_s1_te) = _make_paired_source_target(rng)
    r = aa.run_seed(F_s2_tr, y_tr, F_s2_va, y_va, F_s2_te, y_te,
                    F_s1_tr, F_s1_te, seed=0, alpha=0.1, use_torch_temp=False)
    for cond in ("in_dist_s2", "cross_sensor_s1_unaligned", "cross_sensor_s1_aligned"):
        assert cond in r
        assert "conformal_split" in r[cond]
        assert "coverage" in r[cond]["conformal_split"]
    assert 0.0 <= r["alignment_r2_train"] <= 1.0 or r["alignment_r2_train"] < 0


def test_alignment_restores_coverage_toward_nominal_under_recoverable_shift():
    """The core constructive claim: when S1 IS a (noisy) linear function of
    S2, ridge alignment should bring cross-sensor split-conformal coverage
    substantially closer to nominal than the unaligned baseline."""
    rng = np.random.default_rng(3)
    (F_s2_tr, y_tr, F_s2_va, y_va, F_s2_te, y_te,
     F_s1_tr, F_s1_te) = _make_paired_source_target(rng, s1_noise=1.0)
    seed_runs = [aa.run_seed(F_s2_tr, y_tr, F_s2_va, y_va, F_s2_te, y_te,
                             F_s1_tr, F_s1_te, s, 0.1, use_torch_temp=False)
                for s in range(6)]
    summary = aa.summarize(seed_runs, 0.1)

    nominal = 0.9
    unaligned_cov = summary["cross_sensor_s1_unaligned"]["conformal_split_coverage"]["mean"]
    aligned_cov = summary["cross_sensor_s1_aligned"]["conformal_split_coverage"]["mean"]
    assert abs(aligned_cov - nominal) < abs(unaligned_cov - nominal)
    assert summary["restoration"]["alignment_restores_coverage_CI_excludes_0"] is True


def test_alignment_does_not_fabricate_restoration_when_s1_is_pure_noise():
    """Null-result honesty: when S1 carries NO information about S2 (pure
    independent noise -- the closest synthetic analogue of the real
    'separately-pretrained encoders' collapse), alignment must NOT report a
    spurious restoration."""
    rng = np.random.default_rng(4)
    n_train, n_valid, n_test, d, n_classes = 500, 150, 300, 20, 6
    w = rng.normal(size=(d, n_classes))
    F_s2_tr = rng.normal(size=(n_train, d))
    F_s2_va = rng.normal(size=(n_valid, d))
    F_s2_te = rng.normal(size=(n_test, d))
    F_s1_tr = rng.normal(size=(n_train, d))   # independent of F_s2_tr
    F_s1_te = rng.normal(size=(n_test, d))    # independent of F_s2_te
    y_tr = (F_s2_tr @ w).argmax(1)
    y_va = (F_s2_va @ w).argmax(1)
    y_te = (F_s2_te @ w).argmax(1)

    seed_runs = [aa.run_seed(F_s2_tr, y_tr, F_s2_va, y_va, F_s2_te, y_te,
                             F_s1_tr, F_s1_te, s, 0.1, use_torch_temp=False)
                for s in range(6)]
    summary = aa.summarize(seed_runs, 0.1)
    assert summary["restoration"]["alignment_restores_coverage_CI_excludes_0"] is False
    assert summary["alignment_r2_train"]["mean"] < 0.1


# --------------------------------------------------------------------------- #
# Variance repair reuse: --vary-seed must produce genuine per-seed spread
# --------------------------------------------------------------------------- #
def test_run_seed_vary_seed_true_produces_nonidentical_results():
    rng = np.random.default_rng(5)
    (F_s2_tr, y_tr, F_s2_va, y_va, F_s2_te, y_te,
     F_s1_tr, F_s1_te) = _make_paired_source_target(rng)
    accs = []
    for seed in range(6):
        r = aa.run_seed(F_s2_tr, y_tr, F_s2_va, y_va, F_s2_te, y_te,
                        F_s1_tr, F_s1_te, seed, 0.1, use_torch_temp=False,
                        vary_seed=True)
        accs.append(r["in_dist_s2"]["accuracy"])
    assert len(set(accs)) > 1


def test_run_seed_default_vary_seed_off_is_bit_identical_across_seeds():
    rng = np.random.default_rng(6)
    (F_s2_tr, y_tr, F_s2_va, y_va, F_s2_te, y_te,
     F_s1_tr, F_s1_te) = _make_paired_source_target(rng)
    accs = []
    for seed in range(4):
        r = aa.run_seed(F_s2_tr, y_tr, F_s2_va, y_va, F_s2_te, y_te,
                        F_s1_tr, F_s1_te, seed, 0.1, use_torch_temp=False)
        accs.append(r["in_dist_s2"]["accuracy"])
    assert len(set(accs)) == 1


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__, "-v"]))
