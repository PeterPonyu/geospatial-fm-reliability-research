"""Tests for experiments/geobench_battery/geobench_v1_io.py -- the GEO-Bench
v1.0 per-sample HDF5 reader (pickled-attrs-as-REPR-STRING contract).

Two tiers, per the "8-band lesson" (fixtures must mimic the real format
exactly, not a simplified stand-in):

1. Mocked-boundary unit tests of the pure logic (band-description
   classification, canonical-slot resolution) -- no I/O at all.
2. Caller-shaped REAL-PATH tests that write an actual .hdf5 file to disk
   using the EXACT geobench v1.0 write convention this module must decode:
       fp.attrs["pickle"] = str(pickle.dumps(attr_dict))
   (confirmed against the installed `geobench.dataset.write_sample_hdf5` /
   `load_sample_hdf5` source, and against
   `experiments/bigearthnet_coverage_debt/build_ben_arrays.py`, which reads
   real m-bigearthnet v1.0 data with the identical
   `pickle.loads(ast.literal_eval(fp.attrs["pickle"]))` line) -- then reads
   it back through `geobench_v1_io` and checks round-trip correctness.
"""
from __future__ import annotations

import ast
import json
import pickle

import numpy as np
import pytest

h5py = pytest.importorskip("h5py")
pytest.importorskip("geobench")

import geobench_v1_io as gio


# --------------------------------------------------------------------------- #
# Tier 1: pure-logic unit tests (no I/O)
# --------------------------------------------------------------------------- #
@pytest.mark.parametrize("descriptor,expected", [
    ("02 - Blue", "blue"),
    ("03 - Green", "green"),
    ("04 - Red", "red"),
    ("08 - NIR", "nir"),
    ("08A - Vegetation Red Edge", "nir08"),
    ("01 - Coastal aerosol", "coastal"),
    ("09 - Water vapour", "watervapor"),
    ("10 - Cirrus", "cirrus"),
    ("11 - SWIR", None),   # ambiguous SWIR1/2 without a digit -- see next cases
    ("11 - SWIR 1", "swir1"),
    ("12 - SWIR 2", "swir2"),
    ("01 - VH.Real", None),          # SAR band: not part of the optical cube
    ("thermal band 10", None),
])
def test_classify_band_description(descriptor, expected):
    assert gio.classify_band_description(descriptor) == expected


def test_classify_red_edge_is_ambiguous_pending_ordering():
    assert gio.classify_band_description("05 - Vegetation Red Edge") == "re_ambiguous"
    assert gio.classify_band_description("06 - Vegetation Red Edge") == "re_ambiguous"
    assert gio.classify_band_description("07 - Vegetation Red Edge") == "re_ambiguous"


def test_resolve_band_indices_disambiguates_three_red_edge_bands_by_order():
    bands_order = ["02 - Blue", "03 - Green", "04 - Red",
                   "05 - Vegetation Red Edge", "06 - Vegetation Red Edge",
                   "07 - Vegetation Red Edge", "08 - NIR",
                   "08A - Vegetation Red Edge", "11 - SWIR 1", "12 - SWIR 2"]
    resolved = gio.resolve_band_indices(bands_order)
    assert resolved[gio.CANON_TO_IDX["re1"]] == "05 - Vegetation Red Edge"
    assert resolved[gio.CANON_TO_IDX["re2"]] == "06 - Vegetation Red Edge"
    assert resolved[gio.CANON_TO_IDX["re3"]] == "07 - Vegetation Red Edge"
    assert resolved[gio.CANON_TO_IDX["nir08"]] == "08A - Vegetation Red Edge"
    assert resolved[gio.CANON_TO_IDX["blue"]] == "02 - Blue"
    assert resolved[gio.CANON_TO_IDX["swir1"]] == "11 - SWIR 1"
    assert resolved[gio.CANON_TO_IDX["swir2"]] == "12 - SWIR 2"
    # SAR/thermal-only bands_order lists resolve to nothing (documented, not crashed)
    assert gio.resolve_band_indices(["01 - VH.Real", "02 - VH.Imaginary"]) == {}


def test_is_multilabel():
    assert gio.is_multilabel(np.zeros(43, dtype=np.int64)) is True
    assert gio.is_multilabel(3) is False
    assert gio.is_multilabel(np.int64(3)) is False


def test_decode_pickle_attrs_rejects_non_bytes_literal():
    with pytest.raises(ValueError):
        gio.decode_pickle_attrs("'not bytes, just a string'")


# --------------------------------------------------------------------------- #
# Tier 2: real-path tests against an on-disk .hdf5 written with the EXACT
# geobench v1.0 convention (str(pickle.dumps(attr_dict)) as an hdf5 attr).
# --------------------------------------------------------------------------- #
def _write_v1_sample(path, bands: dict, label, extra_attr_meta=None):
    """Write one v1.0-format sample .hdf5, mimicking
    geobench.dataset.write_sample_hdf5 byte-for-byte:
        fp.create_dataset(band_descriptor, data=array)
        fp.attrs["pickle"] = str(pickle.dumps(attr_dict))
    """
    attr_dict = {"bands_order": list(bands.keys()), "label": label}
    for descriptor in bands:
        meta = {"date": None, "date_id": None, "spatial_resolution": 10.0,
               "band_info": None, "meta_info": {}, "transform": None, "crs": None}
        if extra_attr_meta:
            meta.update(extra_attr_meta.get(descriptor, {}))
        attr_dict[descriptor] = meta
    with h5py.File(str(path), "w") as fp:
        for descriptor, arr in bands.items():
            fp.create_dataset(descriptor, data=arr)
        fp.attrs["pickle"] = str(pickle.dumps(attr_dict))


def _make_bands(rng, h=8, w=8):
    names = ["02 - Blue", "03 - Green", "04 - Red", "05 - Vegetation Red Edge",
            "06 - Vegetation Red Edge", "07 - Vegetation Red Edge", "08 - NIR",
            "08A - Vegetation Red Edge", "09 - Water vapour", "10 - Cirrus",
            "11 - SWIR 1", "12 - SWIR 2"]
    return {n: rng.normal(size=(h, w)).astype(np.float32) for n in names}


def test_real_path_decode_pickle_attrs_round_trips_the_repr_string_bytes():
    """The exact mechanism this module exists for: h5py attrs store
    str(pickle.dumps(...)), NOT raw bytes -- verify ast.literal_eval +
    pickle.loads recovers the original dict."""
    payload = {"bands_order": ["02 - Blue"], "label": 4}
    raw_attr_str = str(pickle.dumps(payload))
    # sanity: this is genuinely a string-of-a-bytes-repr, not bytes itself
    assert isinstance(raw_attr_str, str)
    assert raw_attr_str.startswith("b'") or raw_attr_str.startswith('b"')
    decoded = gio.decode_pickle_attrs(raw_attr_str)
    assert decoded == payload


def test_real_path_read_sample_v1_single_label(tmp_path):
    rng = np.random.default_rng(0)
    bands = _make_bands(rng)
    p = tmp_path / "id_0001.hdf5"
    _write_v1_sample(p, bands, label=7)

    cube, label, resolved = gio.read_sample_v1(p)
    assert cube.shape == (gio.N_CANON, 8, 8)
    assert label == 7
    assert not gio.is_multilabel(label)
    # blue/green/red/nir slots must carry the REAL data, not zeros
    np.testing.assert_allclose(cube[gio.CANON_TO_IDX["blue"]], bands["02 - Blue"])
    np.testing.assert_allclose(cube[gio.CANON_TO_IDX["nir"]], bands["08 - NIR"])
    # coastal (B01) absent from this fixture -> zero-filled, disclosed via `resolved`
    assert gio.CANON_TO_IDX["coastal"] not in resolved
    assert np.all(cube[gio.CANON_TO_IDX["coastal"]] == 0.0)


def test_real_path_read_sample_v1_multilabel(tmp_path):
    rng = np.random.default_rng(1)
    bands = _make_bands(rng)
    multihot = np.zeros(43, dtype=np.int64)
    multihot[[2, 9, 40]] = 1
    p = tmp_path / "id_0002.hdf5"
    _write_v1_sample(p, bands, label=multihot)

    cube, label, resolved = gio.read_sample_v1(p)
    assert gio.is_multilabel(label)
    np.testing.assert_array_equal(np.asarray(label), multihot)


def test_real_path_load_task_split_single_label(tmp_path):
    rng = np.random.default_rng(2)
    dataset_dir = tmp_path
    ids = [f"id_{i:04d}" for i in range(6)]
    labels = [0, 1, 2, 1, 0, 2]
    for sid, lab in zip(ids, labels):
        _write_v1_sample(dataset_dir / f"{sid}.hdf5", _make_bands(rng), label=lab)
    (dataset_dir / "default_partition.json").write_text(json.dumps({
        "train": ids[:4], "valid": [], "test": ids[4:],
    }))

    X, y, kept_ids, resolved_union = gio.load_task_split(dataset_dir, "train")
    assert X.shape == (4, gio.N_CANON, 8, 8)
    assert y.shape == (4,)
    assert y.dtype == np.int64
    assert list(y) == labels[:4]
    assert kept_ids == ids[:4]
    assert gio.CANON_TO_IDX["blue"] in resolved_union


def test_real_path_load_task_split_multilabel(tmp_path):
    rng = np.random.default_rng(3)
    dataset_dir = tmp_path
    ids = [f"id_{i:04d}" for i in range(3)]
    for i, sid in enumerate(ids):
        mh = np.zeros(43, dtype=np.int64)
        mh[i] = 1
        _write_v1_sample(dataset_dir / f"{sid}.hdf5", _make_bands(rng), label=mh)
    (dataset_dir / "default_partition.json").write_text(json.dumps({
        "train": ids, "valid": [], "test": [],
    }))

    X, y, kept_ids, _ = gio.load_task_split(dataset_dir, "train")
    assert X.shape == (3, gio.N_CANON, 8, 8)
    assert y.shape == (3, 43)
    assert y.dtype == np.int64


def test_real_path_synthesize_label_map(tmp_path):
    rng = np.random.default_rng(4)
    dataset_dir = tmp_path
    ids = [f"id_{i:04d}" for i in range(5)]
    labels = [0, 0, 1, 1, 1]
    for sid, lab in zip(ids, labels):
        _write_v1_sample(dataset_dir / f"{sid}.hdf5", _make_bands(rng), label=lab)

    label_map = gio.synthesize_label_map(dataset_dir, ids)
    assert sorted(label_map["0"]) == sorted(ids[:2])
    assert sorted(label_map["1"]) == sorted(ids[2:])
    assert label_map["_synthesis_meta"]["n_samples"] == 5
    assert label_map["_synthesis_meta"]["n_failed"] == 0


def test_real_path_synthesize_label_map_rejects_multilabel(tmp_path):
    rng = np.random.default_rng(5)
    dataset_dir = tmp_path
    sid = "id_0000"
    mh = np.zeros(43, dtype=np.int64)
    mh[0] = 1
    _write_v1_sample(dataset_dir / f"{sid}.hdf5", _make_bands(rng), label=mh)
    with pytest.raises(ValueError):
        gio.synthesize_label_map(dataset_dir, [sid])


def test_real_path_load_partition_missing_file_raises(tmp_path):
    with pytest.raises(FileNotFoundError):
        gio.load_partition(tmp_path, "train")


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__, "-v"]))
