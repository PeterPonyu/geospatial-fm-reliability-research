"""Tests for the weighted-conformal + class-conditional Mondrian baselines
(NEXT-EXPERIMENTS.md item 3 -- already executed on real data, see
experiments/results/eurosat_conformal_baselines/; these tests cover the
underlying math on synthetic data, independent of that real-data run).

All synthetic: no GPU, no network, no cached feature arrays required.
"""
from __future__ import annotations

import numpy as np
import pytest

import run_boundary_sweep as bs


# --------------------------------------------------------------------------- #
# weighted_conformal_qhat: reduces to plain split conformal under uniform
# weights (the sanity check the module's own docstring/findings claim).
# --------------------------------------------------------------------------- #
def test_weighted_conformal_reduces_to_plain_split_under_uniform_weights():
    rng = np.random.default_rng(0)
    n_cal, n_test, alpha = 500, 200, 0.1
    s_cal = rng.exponential(size=n_cal)
    w_cal = np.ones(n_cal)
    w_test = np.ones(n_test)

    qhat_weighted = bs.weighted_conformal_qhat(s_cal, w_cal, w_test, alpha)

    # plain split-conformal threshold: ceil((n+1)(1-alpha))-th order statistic
    n = len(s_cal)
    rank = int(np.ceil((n + 1) * (1 - alpha)))
    plain_thr = np.sort(s_cal)[min(rank, n) - 1]

    assert np.allclose(qhat_weighted, plain_thr, atol=1e-9)


def test_weighted_conformal_qhat_monotone_in_alpha():
    """Smaller alpha (higher target coverage) must give a >= threshold."""
    rng = np.random.default_rng(1)
    s_cal = rng.exponential(size=300)
    w_cal = rng.uniform(0.5, 2.0, size=300)
    w_test = np.ones(50)
    q_tight = bs.weighted_conformal_qhat(s_cal, w_cal, w_test, alpha=0.20)
    q_loose = bs.weighted_conformal_qhat(s_cal, w_cal, w_test, alpha=0.05)
    assert np.all(q_loose >= q_tight - 1e-12)


def test_weighted_conformal_restores_coverage_under_known_covariate_shift():
    """Construct a 1-D covariate-shift toy problem with a KNOWN true density
    ratio; plain split conformal (unweighted) should under- or over-cover
    under the shift, while weighting by the TRUE likelihood ratio should
    land close to nominal coverage. This isolates the weighting math from
    the (separately-documented, real-data) domain-classifier estimation
    error that the findings note limits real-world recovery."""
    rng = np.random.default_rng(42)
    n_cal, n_test, alpha = 4000, 4000, 0.1
    nominal = 1 - alpha

    # source (calibration) ~ N(0,1); target (test) ~ N(1.5, 1) -- covariate
    # shift in x, but the nonconformity score is |x - x0| for a fixed x0 so
    # coverage genuinely depends on which population produced the score.
    x_cal = rng.normal(0, 1, n_cal)
    x_test = rng.normal(1.5, 1, n_test)
    x0 = 0.0
    s_cal = np.abs(x_cal - x0)
    s_test = np.abs(x_test - x0)

    # TRUE density ratio w(x) = f_target(x) / f_source(x) for N(1.5,1)/N(0,1)
    def true_ratio(x):
        return np.exp(-0.5 * ((x - 1.5) ** 2 - x ** 2))

    w_cal = true_ratio(x_cal)
    w_test = true_ratio(x_test)

    qhat = bs.weighted_conformal_qhat(s_cal, w_cal, w_test, alpha)
    covered = s_test <= qhat
    cov_weighted = covered.mean()

    # unweighted (uniform-weight) split conformal for comparison
    qhat_plain = bs.weighted_conformal_qhat(s_cal, np.ones(n_cal), np.ones(n_test), alpha)
    cov_plain = (s_test <= qhat_plain).mean()

    assert abs(cov_weighted - nominal) < abs(cov_plain - nominal), (
        f"weighted coverage {cov_weighted:.3f} should be closer to nominal "
        f"{nominal} than plain {cov_plain:.3f} under a KNOWN correct ratio")
    assert abs(cov_weighted - nominal) < 0.04


# --------------------------------------------------------------------------- #
# lac_sets_per_thr: per-row threshold contract (always >=1 class included).
# --------------------------------------------------------------------------- #
def test_lac_sets_per_thr_always_includes_top1():
    rng = np.random.default_rng(2)
    probs = rng.dirichlet(np.ones(5), size=100)
    qhat = np.zeros(100)   # qhat=0 -> thr=1.0 -> normally nothing included
    sets = bs.lac_sets_per_thr(probs, qhat)
    assert sets.any(axis=1).all(), "every row must include at least the top-1 class"
    # with qhat=0, the included class per row must be the argmax
    assert np.array_equal(sets.argmax(axis=1), probs.argmax(axis=1))


def test_lac_sets_per_thr_inf_qhat_includes_everything():
    rng = np.random.default_rng(3)
    probs = rng.dirichlet(np.ones(4), size=20)
    qhat = np.full(20, np.inf)
    sets = bs.lac_sets_per_thr(probs, qhat)
    assert sets.all()


# --------------------------------------------------------------------------- #
# run_seed_baselines: integration test on synthetic F_all/labels/coords --
# exercises BOTH new arms (conformal_weighted, conformal_class_mondrian)
# through the real code path (not a reimplementation).
# --------------------------------------------------------------------------- #
def _synthetic_dataset(rng, n=1200, d=16, n_classes=6):
    F = rng.normal(size=(n, d)).astype(np.float64)
    w_true = rng.normal(size=(d, n_classes))
    logits = F @ w_true
    y = logits.argmax(1)
    # lon in [0, 10]; west (target) = lon < median
    lon = rng.uniform(0, 10, n)
    lat = rng.uniform(0, 10, n)
    coords = np.stack([lat, lon], axis=1)
    return F, y, coords


def test_run_seed_baselines_structure_and_arms_present():
    rng = np.random.default_rng(7)
    F, y, coords = _synthetic_dataset(rng, n=1500, n_classes=6)
    alphas = [0.1, 0.2]
    out = bs.run_seed_baselines(F, y, coords, seed=0, alphas=alphas, pctl=33.0,
                                n_classes=6)
    assert set(out["per_alpha"].keys()) == {"0.10", "0.20"}
    for a in alphas:
        cell = out["per_alpha"][f"{a:.2f}"]
        for arm in bs.BASELINE_ARMS:
            assert arm in cell
            assert 0.0 <= cell[arm]["coverage"] <= 1.0
            assert cell[arm]["set_size"] >= 1.0 - 1e-9
    assert "domain_classifier" in out
    assert 0.0 <= out["domain_classifier"]["auc_heldout25"] <= 1.0 or np.isnan(
        out["domain_classifier"]["auc_heldout25"])


def test_class_mondrian_falls_back_when_a_class_is_absent_from_target_calib():
    """Class-conditional Mondrian stratification correctness: a class with
    fewer than MIN(20) target-calib points must fall back to the
    target-global quantile (tested via n_class_fallback > 0), not crash or
    silently produce an unguaranteed empty stratum."""
    rng = np.random.default_rng(11)
    n = 900
    d = 8
    n_classes = 8
    F = rng.normal(size=(n, d))
    w_true = rng.normal(size=(d, n_classes))
    y = (F @ w_true).argmax(1)
    # Force class (n_classes - 1) to be extremely rare so it is very likely
    # absent (or <20) from the 30% target-calib slice.
    rare_mask = y == (n_classes - 1)
    if rare_mask.sum() > 5:
        keep = np.where(rare_mask)[0][5:]
        drop_mask = np.zeros(n, dtype=bool)
        drop_mask[keep] = True
        F, y = F[~drop_mask], y[~drop_mask]
    lon = rng.uniform(0, 10, len(y))
    lat = rng.uniform(0, 10, len(y))
    coords = np.stack([lat, lon], axis=1)

    out = bs.run_seed_baselines(F, y, coords, seed=0, alphas=[0.1], pctl=33.0,
                                n_classes=n_classes)
    cell = out["per_alpha"]["0.10"]["conformal_class_mondrian"]
    assert "n_class_fallback" in cell
    assert cell["n_class_fallback"] >= 1
    assert 0.0 <= cell["coverage"] <= 1.0


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__, "-v"]))
