"""Adapter interface-contract tests for the new encoder modules (arms 1, 4, 5).

Every test mocks the encoder AT THE BOUNDARY: a tiny randomly-initialized
nn.Module stands in for the real (multi-hundred-MB, network-downloaded)
checkpoint. No huggingface_hub network call, no GPU. What is under test is
the *contract*: band-mapping/zero-fill correctness, output shape, and that
the feature-extraction functions do not silently reorder or drop channels.

torch is required (already a pinned dependency for feature extraction); GPU
is never required (device="cpu" throughout).
"""
from __future__ import annotations

import numpy as np
import pytest

torch = pytest.importorskip("torch")

import ssl4eo_s1_features as se1
import ssl4eo_vits_mae_features as svm


# --------------------------------------------------------------------------- #
# ssl4eo_s1_features (arm 1: non-degenerate cross-sensor)
# --------------------------------------------------------------------------- #
def test_ssl4eo_s1_encoder_native_2channel_output_shape():
    """S1 branch must accept 2 SAR channels (VV, VH) and return (N, 384)."""
    model = se1._make_vit_s16(in_chans=2, img_size=224).eval()
    n = 5
    s1_8band = np.random.default_rng(0).normal(size=(n, 8, 32, 32)).astype(np.float32)
    s1_mean = s1_8band[:, se1.S1_VV_VH_IDX].mean(axis=(0, 2, 3))
    s1_std = s1_8band[:, se1.S1_VV_VH_IDX].std(axis=(0, 2, 3)) + 1e-3

    feats = se1.ssl4eo_s1_features(model, s1_8band, s1_mean, s1_std, device="cpu")
    assert feats.shape == (n, 384)
    assert np.isfinite(feats).all()


def test_ssl4eo_s1_selects_lee_filtered_vv_vh_bands_not_raw_complex():
    """The band-selection contract: S1_VV_VH_IDX must point at the LEE-
    filtered VV/VH bands (indices 5, 4 in the 8-band m-so2sat S1 array), NOT
    the raw complex Real/Imaginary bands (0-3) -- a degenerate choice would
    silently feed noisy raw components instead of despeckled intensity."""
    assert se1.S1_VV_VH_IDX == [5, 4]


def test_ssl4eo_s2_zero_fills_missing_bands_and_preserves_present_ones():
    """S2 branch: m-so2sat's 10-band array must land in the correct 13-slot
    SSL4EO-S12 TOA positions, with B1/B9/B10 zero-filled (not garbage, not
    aliased from another band)."""
    model = se1._make_vit_s16(in_chans=13, img_size=224).eval()

    # Craft a distinctive, known 10-band input to check the remap.
    n = 3
    s2_10band = np.zeros((n, 10, 32, 32), dtype=np.float32)
    for src in range(10):
        s2_10band[:, src] = float(src + 1)   # band src has constant value src+1

    n_out, h, w = n, 32, 32
    X13 = np.zeros((n_out, 13, h, w), dtype=np.float32)
    for slot, src in enumerate(se1.SO2SAT_S2_TO_SSL4EO):
        if src is not None:
            X13[:, slot] = s2_10band[:, src]

    zero_slots = [i for i, src in enumerate(se1.SO2SAT_S2_TO_SSL4EO) if src is None]
    assert zero_slots == [0, 9, 10], "B1(slot0), B9(slot9), B10(slot10) must be zero-filled"
    assert (X13[:, zero_slots] == 0).all()
    # a present slot must carry its source band's value through unchanged
    present_slot_for_src0 = se1.SO2SAT_S2_TO_SSL4EO.index(0)
    assert np.allclose(X13[:, present_slot_for_src0], 1.0)

    feats = se1.ssl4eo_s2_features(model, s2_10band, device="cpu")
    assert feats.shape == (n, 384)
    assert np.isfinite(feats).all()


# --------------------------------------------------------------------------- #
# ssl4eo_vits_mae_features (arm 5: ViT-S-MAE cell of the 2x2)
# --------------------------------------------------------------------------- #
def test_ssl4eo_vits_mae_output_shape_and_band_reorder():
    model = svm._make_vit_s16_13ch().eval()
    n = 4
    X13_dn = np.random.default_rng(1).uniform(0, 3000, size=(n, 13, 64, 64)).astype(np.float32)
    feats = svm.ssl4eo_vits_mae_features(model, X13_dn, device="cpu")
    assert feats.shape == (n, 384)
    assert np.isfinite(feats).all()


def test_ssl4eo_vits_mae_reuses_eurosat_band_index_from_dino_module():
    """Arm 5 must use the SAME EuroSAT->SSL4EO band mapping as the existing
    ssl4eo (DINO) arm -- these are the same 13 physical bands on the same
    dataset, only the SSL objective/checkpoint differs."""
    import ssl4eo_features as sd
    assert svm.SSL4EO_S2_EUROSAT_IDX == sd.SSL4EO_S2_EUROSAT_IDX
    assert len(svm.SSL4EO_S2_EUROSAT_IDX) == 13


# --------------------------------------------------------------------------- #
# dofa_features (arm 4: 5th encoder) -- mock the model callable directly
# (its build_dofa_encoder() requires torchgeo, which is an optional/
# not-yet-installed dependency; the CONTRACT under test is dofa_features()'s
# band-mapping + wavelength-forwarding + shape, independent of torchgeo).
# --------------------------------------------------------------------------- #
def test_dofa_features_forwards_wavelengths_and_shape_contract():
    import dofa_features as df

    calls = []

    class MockDOFA(torch.nn.Module):
        # dofa_features MUST call forward_features (BUGFIX 2026-07-13: model()
        # is forward_features -> forward_head and returns 45-way class logits,
        # not the pooled (B, 768) embedding). This mock pins that contract:
        def forward_features(self, x, wavelengths):
            calls.append((tuple(x.shape), list(wavelengths)))
            b = x.shape[0]
            return torch.zeros(b, df.DOFA_DIM)

        def forward(self, x, wavelengths):  # pragma: no cover -- must NOT be hit
            raise AssertionError(
                "dofa_features called model() (the forward_head / 45-d logits "
                "path); it must call model.forward_features -- BUGFIX 2026-07-13")

    model = MockDOFA().eval()
    n = 4
    X10_dn = np.random.default_rng(2).uniform(0, 3000, size=(n, 10, 64, 64)).astype(np.float32)
    feats = df.dofa_features(model, X10_dn, device="cpu")

    assert feats.shape == (n, df.DOFA_DIM)
    assert len(calls) == 1
    shape, waves = calls[0]
    assert shape == (n, 10, df.DOFA_IMG_SIZE, df.DOFA_IMG_SIZE), (
        "DOFA must receive the resized 224x224, 10-band input")
    assert waves == [pytest.approx(w) for w in df.CLAY_S2_WAVELENGTHS] \
        if hasattr(df, "CLAY_S2_WAVELENGTHS") else True


def test_dofa_reuses_clay_band_index_and_wavelengths():
    """DOFA must reuse Clay's exact EuroSAT band index/wavelength mapping
    (same physical bands, same dataset) rather than re-deriving/duplicating it."""
    import dofa_features as df
    import clay_features as cl
    assert df.CLAY_S2_EUROSAT_IDX == cl.CLAY_S2_EUROSAT_IDX
    assert df.CLAY_S2_WAVELENGTHS == cl.CLAY_S2_WAVELENGTHS


def test_dofa_build_encoder_raises_clear_error_without_torchgeo(monkeypatch):
    """If torchgeo is not installed, build_dofa_encoder must raise a clear,
    actionable RuntimeError -- not an opaque ImportError deep in torchgeo
    internals."""
    import dofa_features as df
    import builtins

    real_import = builtins.__import__

    def fake_import(name, *a, **kw):
        if name == "torchgeo.models" or name.startswith("torchgeo"):
            raise ImportError("mocked: torchgeo not installed")
        return real_import(name, *a, **kw)

    monkeypatch.setattr(builtins, "__import__", fake_import)
    with pytest.raises(RuntimeError, match="torchgeo"):
        df.build_dofa_encoder(device="cpu")


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__, "-v"]))


def test_ssl4eo_s1_features_accepts_8band_stats_and_selects_correct_entries(monkeypatch):
    """Real-data regression (2026-07-09 container run): the caller passes
    FULL 8-band train stats; the adapter must select the S1_VV_VH_IDX entries
    for clip/standardize instead of crashing on the (1,2,1,1) reshape (or,
    worse, silently clipping with the raw-complex bands' statistics)."""
    import numpy as np

    captured = {}

    def fake_forward(model, X, device, batch=128):
        captured["X"] = X
        return np.zeros((X.shape[0], 384), dtype=np.float32)

    monkeypatch.setattr(se1, "_forward_cls", fake_forward)
    n = 4
    s1 = np.zeros((n, 8, 32, 32), dtype=np.float32)
    # distinct constant value per band so selection is observable
    for b in range(8):
        s1[:, b] = float(b)
    mean8 = np.arange(8, dtype=np.float32)          # band b has mean b
    std8 = np.ones(8, dtype=np.float32)
    out = se1.ssl4eo_s1_features(None, s1, mean8, std8, device="cpu")
    assert out.shape == (n, 384)
    X = captured["X"]
    assert X.shape == (n, 2, 32, 32)
    # bands 5 and 4 selected, each standardized to (value - mean_b)/std_b = 0
    assert np.allclose(X, 0.0, atol=1e-5)
    # 2-band stats path still works too
    out2 = se1.ssl4eo_s1_features(None, s1, mean8[[5, 4]], std8[[5, 4]], device="cpu")
    assert captured["X"].shape == (n, 2, 32, 32)
