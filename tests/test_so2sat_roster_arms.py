"""Interface-contract tests for the m-so2sat roster-completion arms
(so2sat_roster_stage_2026-07-13: `ssl4eo_mae` + `dofa` in
run_so2sat_coverage_debt.get_features) and the per-class conditional-coverage
metric added for the re-scoped Move B (Exp-0 Test-B axis).

Same discipline as test_adapter_contracts.py: the encoder is mocked AT THE
BOUNDARY (tiny nn.Module, no checkpoint, no network, CPU-only). Under test is
the contract only: so2sat 10-band -> encoder input mapping, normalization
passthrough, wavelength passthrough, output shape, and the per-class coverage
arithmetic on a hand-checkable case.
"""
from __future__ import annotations

import numpy as np
import pytest

torch = pytest.importorskip("torch")

import run_so2sat_coverage_debt as R  # noqa: E402  (sys.path via conftest)
import run_real_xsensor_calib as xr  # noqa: E402


@pytest.fixture()
def s2_10band():
    return np.random.default_rng(0).uniform(
        0.01, 0.9, size=(5, 10, 32, 32)).astype(np.float32)


def test_ssl4eo_mae_so2sat_zero_fill_and_shape(s2_10band):
    """10->13 SSL4EO-S12 slot mapping: B1/B9/B10 (slots 0, 9, 10) zero-filled,
    the 10 real bands carry signal, input resized to 224, cls-token (N, 768)."""

    class FakeViTB(torch.nn.Module):
        def forward_features(self, x):
            assert x.shape[1] == 13 and x.shape[2] == 224, x.shape
            for slot in (0, 9, 10):
                assert torch.count_nonzero(x[:, slot]) == 0, f"slot {slot} not zero"
            for slot in (1, 2, 3, 4, 5, 6, 7, 8, 11, 12):
                assert torch.count_nonzero(x[:, slot]) > 0, f"slot {slot} empty"
            return torch.zeros(x.shape[0], 197, 768)

    F = R._ssl4eo_mae_so2sat_features(FakeViTB(), s2_10band, "cpu", batch=3)
    assert F.shape == (5, 768)


def test_ssl4eo_mae_so2sat_band_order(s2_10band):
    """so2sat channel c must land in SSL4EO slot per SO2SAT_S2_TO_SSL4EO --
    verified by marking one source channel and finding it in the right slot."""
    import ssl4eo_s1_features as se1

    marked = np.zeros_like(s2_10band)
    marked[:, 6] = 1.0  # so2sat idx 6 = "08 - NIR"
    expect_slot = se1.SO2SAT_S2_TO_SSL4EO.index(6)  # SSL4EO B8 slot

    class Probe(torch.nn.Module):
        def forward_features(self, x):
            nz = [s for s in range(13) if torch.count_nonzero(x[:, s]) > 0]
            assert nz == [expect_slot], (nz, expect_slot)
            return torch.zeros(x.shape[0], 197, 768)

    R._ssl4eo_mae_so2sat_features(Probe(), marked, "cpu")


def test_dofa_so2sat_waves_and_shape(s2_10band):
    """DOFA arm: 10 channels straight through (no reorder -- so2sat order IS
    Clay's 10-band order), CLAY_S2_WAVELENGTHS as plain floats, resize to 224,
    pooled (N, 768) via forward_features (NOT the 45-way head)."""

    class FakeDOFA(torch.nn.Module):
        def forward_features(self, x, waves):
            assert x.shape[1] == 10 and x.shape[2] == 224, x.shape
            assert len(waves) == 10
            assert all(isinstance(w, float) for w in waves)
            assert waves == [float(w) for w in xr.CLAY_S2_WAVELENGTHS]
            return torch.zeros(x.shape[0], 768)

    mean, std = xr.compute_stats(s2_10band)
    s2n = xr.normalize_s2(s2_10band, mean, std).astype(np.float32)
    F = R._dofa_so2sat_features(FakeDOFA(), s2n, xr.CLAY_S2_WAVELENGTHS,
                                "cpu", batch=2)
    assert F.shape == (5, 768)


def test_fm_labels_registered():
    assert R.FM_LABELS["ssl4eo_mae"] == "ssl4eo_s12_vit_base_mae_ep99_frozen"
    assert R.FM_LABELS["dofa"] == "dofa_base_patch16_224_mae_frozen"


def test_per_class_coverage_hand_case():
    sets = np.zeros((6, R.N_CLASSES), bool)
    y = np.array([0, 0, 1, 1, 2, 2])
    sets[0, 0] = True
    sets[1, 0] = True   # class 0: 2/2 covered
    sets[2, 1] = True   # class 1: 1/2 covered
    #                     class 2: 0/2 covered
    pc = R._per_class_coverage(sets, y)
    assert pc["coverage"][0] == 1.0
    assert pc["coverage"][1] == 0.5
    assert pc["coverage"][2] == 0.0
    assert pc["worst"] == 0.0
    assert pc["spread"] == pytest.approx(1.0)
    assert pc["n"][:3] == [2, 2, 2]
    assert all(v is None for v in pc["coverage"][3:])
    assert all(n == 0 for n in pc["n"][3:])


def test_per_class_coverage_absent_classes_all_none():
    sets = np.ones((3, R.N_CLASSES), bool)
    y = np.array([4, 4, 4])
    pc = R._per_class_coverage(sets, y)
    assert pc["coverage"][4] == 1.0 and pc["worst"] == 1.0 and pc["spread"] == 0.0
    assert sum(v is not None for v in pc["coverage"]) == 1
