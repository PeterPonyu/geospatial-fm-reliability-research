"""Tests for experiments/geobench_battery/run_geobench_battery.py -- the
GEO-Bench task battery (EXPANSION-PLAN-2026-07-09.md Sec 2.3 deliverable 1).

Synthetic embeddings/labels throughout for the conformal-math tests (no
GEO-Bench download, no GPU); mocked encoders at the boundary for the
get_features adapter-contract test; real v1.0-format hdf5 fixtures (via
geobench_v1_io, already tested in test_geobench_v1_io.py) for the
end-to-end multilabel/single-label task-loading integration test.
"""
from __future__ import annotations

import json
import pickle

import numpy as np
import pytest

h5py = pytest.importorskip("h5py")
pytest.importorskip("geobench")

import run_geobench_battery as rb


# --------------------------------------------------------------------------- #
# Multilabel per-label conformal arm: synthetic data with a controlled shift
# --------------------------------------------------------------------------- #
def _make_multilabel_source_target(rng, n_train=500, n_valid=150, n_test=400,
                                   d=16, n_classes=10, shift=0.0):
    w = rng.normal(size=(d, n_classes))
    F_train = rng.normal(size=(n_train, d))
    F_valid = rng.normal(size=(n_valid, d))
    F_test = rng.normal(loc=shift, size=(n_test, d))
    y_train = (F_train @ w > 0.4).astype(np.int64)
    y_valid = (F_valid @ w > 0.4).astype(np.int64)
    y_test = (F_test @ w > 0.4).astype(np.int64)
    return F_train, y_train, F_valid, y_valid, F_test, y_test


def test_run_seed_multilabel_no_shift_gives_near_nominal_split_coverage():
    rng = np.random.default_rng(0)
    F_tr, y_tr, F_va, y_va, F_te, y_te = _make_multilabel_source_target(rng, shift=0.0)
    global_freq = np.concatenate([y_tr, y_va, y_te]).sum(0)
    active = [int(c) for c in range(y_tr.shape[1]) if global_freq[c] >= 30]
    assert len(active) > 0
    seed_runs = [rb.run_seed_multilabel(F_tr, y_tr, F_va, y_va, F_te, y_te, s, [0.1], active)
                for s in range(8)]
    cell = rb.summarize_cell_multilabel(seed_runs, 0.1)
    assert abs(cell["conformal_split"]["coverage"]["mean"] - 0.9) < 0.08


def test_run_seed_multilabel_under_shift_split_undercovers_and_target_global_restores():
    rng = np.random.default_rng(1)
    F_tr, y_tr, F_va, y_va, F_te, y_te = _make_multilabel_source_target(rng, shift=2.5)
    global_freq = np.concatenate([y_tr, y_va, y_te]).sum(0)
    active = [int(c) for c in range(y_tr.shape[1]) if global_freq[c] >= 30]
    seed_runs = [rb.run_seed_multilabel(F_tr, y_tr, F_va, y_va, F_te, y_te, s, [0.1], active)
                for s in range(8)]
    cell = rb.summarize_cell_multilabel(seed_runs, 0.1)

    split_cov = cell["conformal_split"]["coverage"]["mean"]
    tg_cov = cell["conformal_target_global"]["coverage"]["mean"]
    nominal = 0.9
    assert abs(tg_cov - nominal) < abs(split_cov - nominal), (
        f"target_global coverage {tg_cov:.3f} should be closer to nominal than "
        f"split {split_cov:.3f} under a real target shift")


def test_summarize_cell_multilabel_shape_matches_single_label_cell():
    """The multilabel cell JSON must have the SAME top-level keys as
    sd.summarize_cell's single-label cell, so verify_battery.py can validate
    both uniformly."""
    import run_so2sat_coverage_debt as sd
    rng = np.random.default_rng(2)
    F_tr, y_tr, F_va, y_va, F_te, y_te = _make_multilabel_source_target(rng, shift=1.0)
    global_freq = np.concatenate([y_tr, y_va, y_te]).sum(0)
    active = [int(c) for c in range(y_tr.shape[1]) if global_freq[c] >= 30]
    seed_runs = [rb.run_seed_multilabel(F_tr, y_tr, F_va, y_va, F_te, y_te, s, [0.1], active)
                for s in range(4)]
    ml_cell = rb.summarize_cell_multilabel(seed_runs, 0.1)

    d, n_classes = 16, 6
    w = rng.normal(size=(d, n_classes))
    F_tr2 = rng.normal(size=(500, d)); F_va2 = rng.normal(size=(150, d))
    F_te2 = rng.normal(loc=1.0, size=(400, d))
    y_tr2 = (F_tr2 @ w).argmax(1); y_va2 = (F_va2 @ w).argmax(1); y_te2 = (F_te2 @ w).argmax(1)
    sl_seed_runs = [sd.run_seed(F_tr2, y_tr2, F_va2, y_va2, F_te2, y_te2, s, [0.1])
                    for s in range(4)]
    sl_cell = sd.summarize_cell(sl_seed_runs, 0.1)

    for key in ("conformal_split", "conformal_target_global", "restoration",
               "split_undercovers_debt", "alpha", "nominal_coverage"):
        assert key in ml_cell, f"multilabel cell missing key {key!r}"
        assert key in sl_cell, f"single-label cell missing key {key!r}"
    for arm in ("conformal_split", "conformal_target_global"):
        assert "coverage" in ml_cell[arm] and "set_size" in ml_cell[arm]
        assert "coverage" in sl_cell[arm] and "set_size" in sl_cell[arm]


# --------------------------------------------------------------------------- #
# get_features(): adapter-contract test with a MOCKED encoder at the boundary
# --------------------------------------------------------------------------- #
def test_get_features_ssl4eo_contract_with_mocked_encoder(monkeypatch, tmp_path):
    import ssl4eo_features as ss

    monkeypatch.setattr(ss, "find_ssl4eo_ckpt", lambda: "mock_ckpt")

    class _FakeModel:
        pass

    def fake_build(ckpt_path, device):
        assert ckpt_path == "mock_ckpt"
        return _FakeModel()

    def fake_features(model, X13_dn, device, batch=128):
        assert isinstance(model, _FakeModel)
        return np.zeros((len(X13_dn), 384), dtype=np.float32)

    monkeypatch.setattr(ss, "build_ssl4eo_encoder", fake_build)
    monkeypatch.setattr(ss, "ssl4eo_features", fake_features)

    n = 6
    X13 = np.zeros((n, 13, 32, 32), dtype=np.float32)
    F_all, label = rb.get_features("ssl4eo", X13, device="cpu", cache_dir=tmp_path)
    assert F_all.shape == (n, 384)
    assert label == rb.FM_LABELS["ssl4eo"]

    cache_files = list(tmp_path.glob("feats_ssl4eo_*.npy"))
    assert len(cache_files) == 1


def test_get_features_unknown_backbone_raises(tmp_path):
    with pytest.raises(ValueError):
        rb.get_features("not_a_real_fm", np.zeros((2, 13, 4, 4), np.float32),
                        device="cpu", cache_dir=tmp_path)


def test_get_features_cache_is_task_scoped_not_global(monkeypatch, tmp_path):
    """Regression test for the deliberate cache-collision fix documented in
    run_geobench_battery.get_features's docstring: two different callers
    with the SAME sample count `n` but DIFFERENT cache_dir must not collide."""
    import ssl4eo_features as ss
    monkeypatch.setattr(ss, "find_ssl4eo_ckpt", lambda: "mock_ckpt")

    class _FakeModel:
        pass
    monkeypatch.setattr(ss, "build_ssl4eo_encoder", lambda ckpt, device: _FakeModel())

    calls = {"n": 0}

    def fake_features(model, X13_dn, device, batch=128):
        calls["n"] += 1
        return np.full((len(X13_dn), 384), float(calls["n"]), dtype=np.float32)

    monkeypatch.setattr(ss, "ssl4eo_features", fake_features)

    n = 5
    X13 = np.zeros((n, 13, 8, 8), dtype=np.float32)
    dir_a = tmp_path / "task_a" / "cache"
    dir_b = tmp_path / "task_b" / "cache"
    F_a, _ = rb.get_features("ssl4eo", X13, device="cpu", cache_dir=dir_a)
    F_b, _ = rb.get_features("ssl4eo", X13, device="cpu", cache_dir=dir_b)
    assert calls["n"] == 2, "each task-scoped cache_dir must trigger its own extraction"
    assert not np.array_equal(F_a, F_b)


# --------------------------------------------------------------------------- #
# End-to-end task loading (real v1.0-format hdf5 fixtures) + blocked-dataset path
# --------------------------------------------------------------------------- #
def _write_v1_sample(path, bands, label):
    attr_dict = {"bands_order": list(bands.keys()), "label": label}
    for descriptor in bands:
        attr_dict[descriptor] = {"date": None, "date_id": None,
                                 "spatial_resolution": 10.0, "band_info": None,
                                 "meta_info": {}, "transform": None, "crs": None}
    with h5py.File(str(path), "w") as fp:
        for descriptor, arr in bands.items():
            fp.create_dataset(descriptor, data=arr)
        fp.attrs["pickle"] = str(pickle.dumps(attr_dict))


def _make_bands(rng, h=8, w=8):
    names = ["02 - Blue", "03 - Green", "04 - Red", "08 - NIR",
            "11 - SWIR 1", "12 - SWIR 2"]
    return {n: rng.normal(size=(h, w)).astype(np.float32) for n in names}


def test_run_task_reports_missing_dataset_dir_as_blocked(tmp_path):
    import argparse
    args = argparse.Namespace(data_root=str(tmp_path), limit=0, min_pos=5,
                              alphas=[0.1], seeds=2, fms=["prithvi"])
    result, err = rb.run_task(args, "m-eurosat", device="cpu")
    assert result is None
    assert "not found" in err


def test_run_task_reports_insufficient_bands_as_blocked(tmp_path):
    """A task whose hdf5 files carry NO recognizable optical bands (e.g. a
    SAR-only or thermal-only release) must be blocked with a clear reason,
    never silently fed zeros into an FM adapter."""
    import argparse
    rng = np.random.default_rng(0)
    dataset_dir = tmp_path / "m-fake-sar-task"
    dataset_dir.mkdir()
    sar_bands = {"01 - VH.Real": rng.normal(size=(8, 8)).astype(np.float32),
                "02 - VH.Imaginary": rng.normal(size=(8, 8)).astype(np.float32)}
    ids = ["id_0000", "id_0001"]
    for sid in ids:
        _write_v1_sample(dataset_dir / f"{sid}.hdf5", sar_bands, label=0)
    (dataset_dir / "default_partition.json").write_text(json.dumps({
        "train": ids, "valid": ids, "test": ids,
    }))
    args = argparse.Namespace(data_root=str(tmp_path), limit=0, min_pos=5,
                              alphas=[0.1], seeds=2, fms=["prithvi"])
    result, err = rb.run_task(args, "m-fake-sar-task", device="cpu")
    assert result is None
    assert "canonical optical bands" in err


# --------------------------------------------------------------------------- #
# End-to-end: run_task() output structure must satisfy verify_battery.py's
# CONTENT gate (the "machine-checkable" completion contract).
# --------------------------------------------------------------------------- #
def _write_task_dataset(dataset_dir, ids_by_split, multilabel, n_classes=8, seed=0):
    rng = np.random.default_rng(seed)
    dataset_dir.mkdir(parents=True, exist_ok=True)
    all_ids = ids_by_split["train"] + ids_by_split["valid"] + ids_by_split["test"]
    for sid in all_ids:
        if multilabel:
            label = (rng.random(n_classes) < 0.35).astype(np.int64)
        else:
            label = int(rng.integers(0, n_classes))
        _write_v1_sample(dataset_dir / f"{sid}.hdf5", _make_bands(rng), label=label)
    (dataset_dir / "default_partition.json").write_text(json.dumps(ids_by_split))


@pytest.mark.parametrize("task,multilabel", [("m-eurosat", False), ("m-bigearthnet", True)])
def test_run_task_end_to_end_output_passes_verify_battery(monkeypatch, tmp_path, task, multilabel):
    import argparse
    import verify_battery as vb

    ids_by_split = {"train": [f"tr_{i}" for i in range(200)],
                    "valid": [f"va_{i}" for i in range(60)],
                    "test": [f"te_{i}" for i in range(120)]}
    _write_task_dataset(tmp_path / task, ids_by_split, multilabel=multilabel)

    def fake_get_features(fm, X, device, cache_dir):
        rng = np.random.default_rng(abs(hash((fm, len(X)))) % (2**32))
        return rng.normal(size=(len(X), 12)).astype(np.float32), f"{fm}_mocked"

    monkeypatch.setattr(rb, "get_features", fake_get_features)

    args = argparse.Namespace(data_root=str(tmp_path), limit=0, min_pos=3,
                              alphas=[0.1, 0.2], seeds=2, fms=["prithvi", "clay"])
    result, err = rb.run_task(args, task, device="cpu")
    assert err is None, f"run_task failed: {err}"
    assert result is not None

    problems = vb.check_task_result(result, task)
    assert problems == [], f"verify_battery found problems: {problems}"


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__, "-v"]))


def test_logits_of_binary_task_returns_2d_sigmoid_equivalent():
    """Real-data regression (m-brick-kiln, 2026-07-09): binary tasks crash the
    multiclass softmax path because sklearn's decision_function is 1-D for 2
    classes. logits_of must return 2-D whose softmax equals predict_proba."""
    import numpy as np
    import sys
    from pathlib import Path
    sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "experiments/eurosat_xsensor_calib"))
    import run_real_geo_shift_calib as s1
    from sklearn.linear_model import LogisticRegression
    from sklearn.preprocessing import StandardScaler

    rng = np.random.default_rng(0)
    X = rng.normal(size=(200, 8)).astype(np.float32)
    y = (X[:, 0] + 0.3 * rng.normal(size=200) > 0).astype(int)  # binary
    sc = StandardScaler().fit(X)
    clf = LogisticRegression(max_iter=200).fit(sc.transform(X), y)
    z = s1.logits_of(sc, clf, X)
    assert z.ndim == 2 and z.shape == (200, 2)
    p = s1.softmax(z)
    assert np.allclose(p, clf.predict_proba(sc.transform(X)), atol=1e-6)
    # multiclass unchanged: 3-class returns sklearn's own 2-D scores
    y3 = rng.integers(0, 3, size=200)
    clf3 = LogisticRegression(max_iter=200).fit(sc.transform(X), y3)
    z3 = s1.logits_of(sc, clf3, X)
    assert z3.shape == (200, 3)
    assert np.allclose(z3, clf3.decision_function(sc.transform(X)))
