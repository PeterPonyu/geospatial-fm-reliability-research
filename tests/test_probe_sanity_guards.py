"""Tests for the probe-sanity and feature-validity guards added after the
2026-07-11 incident (experiments/results/DEBUG-ALIGNMENT-2026-07-11.md):
`xsensor_real_alignment_arm/results.json` reported a "0.059->0.9998
coverage restoration" headline that was entirely a pipeline artifact -- the
in-distribution S2 control was silently dead (accuracy at chance), and
nothing caught it before the numbers were written to a result JSON.

`experiments/xsensor_real/run_real_xsensor_calib.check_probe_sanity` /
`check_feature_validity` are the guards; `run_alignment_arm.py` shares the
same code path and reuses `check_probe_sanity` for its own in-distribution
S2 control.

Synthetic data throughout -- no GPU, no network, no real checkpoints.
"""
from __future__ import annotations

import numpy as np
import pytest

import run_alignment_arm as aa
import run_real_xsensor_calib as xr


# --------------------------------------------------------------------------- #
# check_probe_sanity: unit tests
# --------------------------------------------------------------------------- #
def test_check_probe_sanity_healthy_accuracy_passes():
    # well above chance*1.5 for 10 classes (chance=0.10, threshold=0.15)
    xr.check_probe_sanity(0.62, n_classes=10, label="in_dist_s2")  # must not raise


def test_check_probe_sanity_chance_level_raises():
    with pytest.raises(RuntimeError) as exc:
        xr.check_probe_sanity(0.0598, n_classes=17, label="in_dist_s2")
    msg = str(exc.value)
    assert "0.0598" in msg
    assert "in_dist_s2" in msg
    assert "chance" in msg.lower()
    assert "2026-07-11" in msg


def test_check_probe_sanity_boundary_exactly_at_threshold_raises():
    # chance=0.2 for 5 classes; default multiplier 1.5 -> threshold=0.3
    with pytest.raises(RuntimeError):
        xr.check_probe_sanity(0.30, n_classes=5, label="in_dist_s2")


def test_check_probe_sanity_just_above_threshold_passes():
    xr.check_probe_sanity(0.301, n_classes=5, label="in_dist_s2")  # must not raise


def test_check_probe_sanity_waiver_via_arg_disables_check():
    # non-positive multiplier explicitly disables the guard
    xr.check_probe_sanity(0.0598, n_classes=17, label="in_dist_s2",
                          chance_multiplier=-1.0)  # must not raise
    xr.check_probe_sanity(0.0598, n_classes=17, label="in_dist_s2",
                          chance_multiplier=0.0)  # must not raise


def test_check_probe_sanity_waiver_via_env_var_disables_check(monkeypatch):
    monkeypatch.setenv(xr.CHANCE_MULTIPLIER_ENV, "-1")
    xr.check_probe_sanity(0.0598, n_classes=17, label="in_dist_s2")  # must not raise


def test_check_probe_sanity_explicit_arg_overrides_env_var(monkeypatch):
    # env says "waive"; explicit arg re-enables at a strict multiplier
    monkeypatch.setenv(xr.CHANCE_MULTIPLIER_ENV, "-1")
    with pytest.raises(RuntimeError):
        xr.check_probe_sanity(0.0598, n_classes=17, label="in_dist_s2",
                              chance_multiplier=1.5)


# --------------------------------------------------------------------------- #
# check_feature_validity: unit tests
# --------------------------------------------------------------------------- #
def test_check_feature_validity_healthy_features_pass():
    rng = np.random.default_rng(0)
    F = rng.normal(size=(300, 50)).astype(np.float32)
    xr.check_feature_validity(F, "healthy")  # must not raise


def test_check_feature_validity_nonfinite_raises():
    rng = np.random.default_rng(0)
    F = rng.normal(size=(300, 50)).astype(np.float32)
    F[10, 3] = np.nan
    F[20, 4] = np.inf
    with pytest.raises(RuntimeError) as exc:
        xr.check_feature_validity(F, "nonfinite_case")
    msg = str(exc.value)
    assert "non-finite" in msg
    assert "nonfinite_case" in msg
    assert "2026-07-11" in msg


def test_check_feature_validity_all_constant_columns_raises():
    F = np.full((300, 50), 5.0, dtype=np.float32)  # every row identical
    with pytest.raises(RuntimeError) as exc:
        xr.check_feature_validity(F, "constant_case")
    msg = str(exc.value)
    assert "constant" in msg.lower()
    assert "constant_case" in msg


def test_check_feature_validity_degenerate_row_norms_raises():
    rng = np.random.default_rng(0)
    F = rng.normal(size=(300, 50)).astype(np.float32)
    F[: int(0.95 * 300)] = 0.0  # 95% zero rows, well beyond the 1% default budget
    with pytest.raises(RuntimeError) as exc:
        xr.check_feature_validity(F, "zero_rows_case")
    msg = str(exc.value)
    assert "near-zero L2 norm" in msg
    assert "zero_rows_case" in msg


def test_check_feature_validity_tolerates_small_fraction_of_zero_rows():
    rng = np.random.default_rng(0)
    F = rng.normal(size=(300, 50)).astype(np.float32)
    F[:2] = 0.0  # well under the 1% default budget (3/300)
    xr.check_feature_validity(F, "few_zero_rows")  # must not raise


# --------------------------------------------------------------------------- #
# Integration: run_seed refuses to complete past a dead in-distribution probe
# --------------------------------------------------------------------------- #
def _degenerate_indist_arrays(n_classes=5, per_class=20, d=10):
    """Constant (zero) S2 features -> a logistic probe has no signal to fit
    and collapses to predicting a single class; against a class-balanced
    test set that lands accuracy EXACTLY at chance (1/n_classes),
    deterministically reproducing the extraction-collapse scenario from the
    2026-07-11 incident without depending on RNG luck."""
    n = n_classes * per_class
    y = np.repeat(np.arange(n_classes), per_class)
    F_s2_train = np.zeros((n, d), dtype=np.float32)
    F_s2_valid = np.zeros((n, d), dtype=np.float32)
    F_s2_test = np.zeros((n, d), dtype=np.float32)
    F_s1_test = np.zeros((n, d), dtype=np.float32)
    return F_s2_train, y.copy(), F_s2_valid, y.copy(), F_s2_test, y.copy(), F_s1_test


def test_run_seed_raises_on_dead_in_distribution_probe():
    arrays = _degenerate_indist_arrays()
    with pytest.raises(RuntimeError) as exc:
        xr.run_seed(*arrays, seed=0, alpha=0.1, use_torch_temp=False)
    msg = str(exc.value)
    assert "in_dist_s2" in msg
    assert "2026-07-11" in msg


def test_run_seed_waiver_lets_dead_probe_through_when_explicitly_disabled():
    arrays = _degenerate_indist_arrays()
    r = xr.run_seed(*arrays, seed=0, alpha=0.1, use_torch_temp=False,
                    chance_multiplier=-1.0)
    assert "in_dist_s2" in r
    assert r["in_dist_s2"]["accuracy"] == pytest.approx(1.0 / 5)


def test_run_seed_waiver_via_env_var_lets_dead_probe_through(monkeypatch):
    monkeypatch.setenv(xr.CHANCE_MULTIPLIER_ENV, "0")
    arrays = _degenerate_indist_arrays()
    r = xr.run_seed(*arrays, seed=0, alpha=0.1, use_torch_temp=False)
    assert "in_dist_s2" in r


def test_run_seed_healthy_informative_data_does_not_raise():
    """Sanity check that the guard doesn't false-positive on a probe that
    genuinely works (mirrors the existing variance-repair test fixtures)."""
    rng = np.random.default_rng(1)
    d, n_classes = 10, 5
    w = rng.normal(size=(d, n_classes))
    F_s2_tr = rng.normal(size=(400, d))
    F_s2_va = rng.normal(size=(150, d))
    F_s2_te = rng.normal(size=(200, d))
    F_s1_te = rng.normal(size=(200, d))
    y_tr = (F_s2_tr @ w).argmax(1)
    y_va = (F_s2_va @ w).argmax(1)
    y_te = (F_s2_te @ w).argmax(1)
    r = xr.run_seed(F_s2_tr, y_tr, F_s2_va, y_va, F_s2_te, y_te, F_s1_te,
                    seed=0, alpha=0.1, use_torch_temp=False)
    assert r["in_dist_s2"]["accuracy"] > 0.5


# --------------------------------------------------------------------------- #
# Integration: the alignment arm shares the same guard on its own in-dist
# S2 control (evaluated before either S1 condition).
# --------------------------------------------------------------------------- #
def test_alignment_arm_run_seed_raises_on_dead_in_distribution_probe():
    (F_s2_train, y_train, F_s2_valid, y_valid, F_s2_test, y_test,
     F_s1_test) = _degenerate_indist_arrays()
    F_s1_train = np.zeros_like(F_s2_train)
    with pytest.raises(RuntimeError) as exc:
        aa.run_seed(F_s2_train, y_train, F_s2_valid, y_valid, F_s2_test, y_test,
                    F_s1_train, F_s1_test, seed=0, alpha=0.1, use_torch_temp=False)
    msg = str(exc.value)
    assert "in_dist_s2" in msg
    assert "2026-07-11" in msg


def test_alignment_arm_run_seed_waiver_lets_dead_probe_through():
    (F_s2_train, y_train, F_s2_valid, y_valid, F_s2_test, y_test,
     F_s1_test) = _degenerate_indist_arrays()
    F_s1_train = np.zeros_like(F_s2_train)
    r = aa.run_seed(F_s2_train, y_train, F_s2_valid, y_valid, F_s2_test, y_test,
                    F_s1_train, F_s1_test, seed=0, alpha=0.1, use_torch_temp=False,
                    chance_multiplier=-1.0)
    assert "in_dist_s2" in r
    assert "cross_sensor_s1_unaligned" in r  # execution proceeded past the guard


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__, "-v"]))
