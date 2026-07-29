"""Tests for experiments/eurosat_xsensor_calib/report_stage2_variance.py --
the honest per-seed-spread report (EXPANSION-PLAN-2026-07-09.md Sec 2.3
deliverable 2)."""
from __future__ import annotations

import json

import pytest

import report_stage2_variance as rv


def _fake_results(seed_covs, seed_accs=None):
    """Build a minimal results.json-shaped dict with one fm/alpha cell whose
    real_shift split-conformal coverage takes the given per-seed values."""
    seed_accs = seed_accs or [0.7] * len(seed_covs)
    per_seed = []
    for i, (cov, acc) in enumerate(zip(seed_covs, seed_accs)):
        per_seed.append({
            "seed": i,
            "in_dist": {"accuracy": acc},
            "real_shift": {
                "accuracy": acc,
                "conformal_split": {"coverage": cov, "set_size": 1.0},
                "conformal_spatial_mondrian": {"coverage": cov + 0.02, "set_size": 1.1},
            },
        })
    return {"fm_results": {"prithvi": {"0.10": {"per_seed": per_seed}}}}


def test_analyze_extracts_per_seed_values_and_stats():
    results = _fake_results([0.80, 0.81, 0.79, 0.82, 0.83])
    report = rv.analyze(results)
    cell = report["prithvi"]["0.10"]["metrics"]["real_shift_split_coverage"]
    assert cell["n_distinct_values"] == 5
    assert cell["std"] > 0
    assert not cell["spread_near_zero"]


def test_analyze_flags_bit_identical_seeds_as_degenerate():
    results = _fake_results([0.80, 0.80, 0.80, 0.80, 0.80])
    report = rv.analyze(results)
    cell = report["prithvi"]["0.10"]["metrics"]["real_shift_split_coverage"]
    assert cell["n_distinct_values"] == 1
    assert cell["std"] == 0.0
    assert cell["spread_near_zero"]


def test_summarize_honestly_reports_genuine_spread():
    results = _fake_results([0.80, 0.81, 0.79, 0.82, 0.80])
    report = rv.analyze(results)
    summary = rv.summarize_honestly(report)
    assert summary["n_degenerate_cells"] == 0
    assert "GENUINE" in summary["honest_finding"]


def test_summarize_honestly_reports_degenerate_finding_never_as_replication():
    results = _fake_results([0.80] * 5)
    report = rv.analyze(results)
    summary = rv.summarize_honestly(report)
    assert summary["n_degenerate_cells"] == 1
    assert "DEGENERATE" in summary["honest_finding"]
    assert "prithvi/alpha=0.10" in summary["degenerate_cells"]


def test_main_end_to_end_writes_report(tmp_path):
    import argparse
    results = _fake_results([0.80, 0.81, 0.79, 0.82, 0.80])
    results_path = tmp_path / "results.json"
    results_path.write_text(json.dumps(results))
    out_path = tmp_path / "variance_report.json"

    import sys
    old_argv = sys.argv
    try:
        sys.argv = ["report_stage2_variance.py", "--results-json", str(results_path),
                   "--out", str(out_path)]
        rv.main()
    finally:
        sys.argv = old_argv

    assert out_path.exists()
    payload = json.loads(out_path.read_text())
    assert payload["summary"]["n_degenerate_cells"] == 0
    assert "prithvi" in payload["per_fm_alpha"]


def test_main_raises_on_missing_results_json(tmp_path):
    import argparse
    import sys
    old_argv = sys.argv
    try:
        sys.argv = ["report_stage2_variance.py", "--results-json",
                   str(tmp_path / "does_not_exist.json")]
        with pytest.raises(FileNotFoundError):
            rv.main()
    finally:
        sys.argv = old_argv


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__, "-v"]))
