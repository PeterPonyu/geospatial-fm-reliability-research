#!/usr/bin/env python3
"""F15_shift_fingerprint.pdf — source vs target spectral fingerprint.

Companion geographic-shift visual (not a class-prior duplicate of F14):
  For six EuroSAT classes, mean RGB channel levels and a greenness / NDVI-like
  index comparing source (lon>=P33) vs target (lon<P33).

Prefers local EuroSAT-MS GeoTIFF (B04/B03/B02 + B08 NDVI). Falls back to
EuroSAT RGB JPEGs with a greenness index (G-R)/(G+R) when MS is unavailable.
Uses a seeded subsample of existing local tiles only; P33 cut unchanged.
"""
from __future__ import annotations

from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import rasterio
from matplotlib.patches import Patch
from PIL import Image

GEO = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
ART = Path(
    "/home/zeyufu/Desktop/ml-reliability-research/.omc/artifacts/"
    "visual-ralph/geo-rotcert-expand/geo"
)
ART.mkdir(parents=True, exist_ok=True)

MANIFEST = GEO / "experiments" / "results" / "eurosat_spatial" / "manifest.csv"
MS_ROOT = GEO / "data" / "eurosat_ms" / "extracted"
RGB_ROOT = GEO / "data" / "eurosat_rgb" / "eurosat" / "2750"

CLASSES = [
    "AnnualCrop",
    "Forest",
    "PermanentCrop",
    "Residential",
    "Highway",
    "SeaLake",
]
SHORT = {
    "AnnualCrop": "AnnualCrop",
    "Forest": "Forest",
    "PermanentCrop": "Perm.Crop",
    "Residential": "Resid.",
    "Highway": "Highway",
    "SeaLake": "SeaLake",
}

C_SRC = "#009E73"
C_TGT = "#0072B2"
C_INK = "#000000"
N_PER = 80
COL_W = 7.2


def _style():
    plt.rcParams.update(
        {
            "font.size": 8,
            "axes.titlesize": 8,
            "axes.labelsize": 7.5,
            "xtick.labelsize": 6.5,
            "ytick.labelsize": 6.5,
            "legend.fontsize": 6.5,
            "figure.facecolor": "white",
            "axes.facecolor": "white",
            "savefig.facecolor": "white",
            "text.color": C_INK,
        }
    )


def _tag(ax, letter: str):
    ax.text(
        0.02,
        0.98,
        letter,
        transform=ax.transAxes,
        fontweight="bold",
        fontsize=10,
        va="top",
        ha="left",
        color=C_INK,
    )


def rgb_path_from_rel(rel: str) -> Path:
    name = Path(rel).name.replace(".tif", ".jpg")
    cls = Path(rel).parts[-2]
    return RGB_ROOT / cls / name


def sample_stats(df: pd.DataFrame, rng: np.random.Generator, n: int):
    """Aggregate per-tile mean R,G,B and greenness/NDVI over up to n tiles."""
    if len(df) == 0:
        return None
    take = min(n, len(df))
    idx = rng.choice(len(df), size=take, replace=False)
    rs, gs, bs, greens = [], [], [], []
    mode = None
    for i in idx:
        rel = df.iloc[int(i)].relpath
        ms = MS_ROOT / rel
        if ms.is_file():
            with rasterio.open(ms) as ds:
                bands = ds.read([4, 3, 2, 8]).astype(np.float32)
            r, g, b, nir = bands
            rs.append(float(r.mean()))
            gs.append(float(g.mean()))
            bs.append(float(b.mean()))
            denom = nir + r
            nd = np.where(denom > 0, (nir - r) / denom, np.nan)
            greens.append(float(np.nanmean(nd)))
            mode = "MS"
            continue
        jp = rgb_path_from_rel(rel)
        if not jp.is_file():
            continue
        arr = np.asarray(Image.open(jp).convert("RGB"), dtype=np.float32)
        r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
        rs.append(float(r.mean()))
        gs.append(float(g.mean()))
        bs.append(float(b.mean()))
        denom = g + r
        grn = np.where(denom > 0, (g - r) / denom, np.nan)
        greens.append(float(np.nanmean(grn)))
        mode = mode or "RGB"
    if not rs:
        return None
    return {
        "R": np.asarray(rs),
        "G": np.asarray(gs),
        "B": np.asarray(bs),
        "GREEN": np.asarray(greens),
        "mode": mode,
    }


def main():
    _style()
    if not MANIFEST.is_file():
        raise FileNotFoundError(MANIFEST)

    m = pd.read_csv(MANIFEST)
    P33 = float(m.lon.quantile(0.33))
    n_src = int((m.lon >= P33).sum())
    n_tgt = int((m.lon < P33).sum())
    assert n_src == 18090 and n_tgt == 8910

    rng = np.random.default_rng(11)

    fig = plt.figure(figsize=(COL_W, 5.4))
    gs = fig.add_gridspec(2, 1, height_ratios=[1.15, 1.0], hspace=0.38)

    ax_a = fig.add_subplot(gs[0])
    x = np.arange(len(CLASSES))
    width = 0.12
    src_rgb, tgt_rgb = [], []
    modes = set()
    for cls in CLASSES:
        pool = m[m.label == cls]
        s = sample_stats(pool[pool.lon >= P33], rng, N_PER)
        t = sample_stats(pool[pool.lon < P33], rng, N_PER)
        if s:
            modes.add(s["mode"])
        if t:
            modes.add(t["mode"])
        src_rgb.append(
            [s["R"].mean(), s["G"].mean(), s["B"].mean()] if s else [np.nan] * 3
        )
        tgt_rgb.append(
            [t["R"].mean(), t["G"].mean(), t["B"].mean()] if t else [np.nan] * 3
        )
    src_rgb = np.asarray(src_rgb)
    tgt_rgb = np.asarray(tgt_rgb)

    # Scale: MS DN vs RGB 0-255 — normalize each side's display to comparable units
    # by dividing MS by 3000 and RGB by 255 into reflectance-ish [0,1]-ish means.
    def _norm(arr, mode_guess: str):
        if "MS" in modes and "RGB" not in modes:
            return arr / 3000.0
        if "RGB" in modes and "MS" not in modes:
            return arr / 255.0
        # mixed: prefer per-row unknown — use 255 scale if values look like RGB
        return arr / (3000.0 if np.nanmean(arr) > 30 else 255.0)

    src_n = _norm(src_rgb, "auto")
    tgt_n = _norm(tgt_rgb, "auto")

    colors_ch = {"R": "#D55E00", "G": "#009E73", "B": "#0072B2"}
    offsets = {
        ("src", "R"): -2.5,
        ("src", "G"): -1.5,
        ("src", "B"): -0.5,
        ("tgt", "R"): 0.5,
        ("tgt", "G"): 1.5,
        ("tgt", "B"): 2.5,
    }
    for side, arr, alpha in (("src", src_n, 0.95), ("tgt", tgt_n, 0.55)):
        for j, ch in enumerate("RGB"):
            ax_a.bar(
                x + offsets[(side, ch)] * width,
                arr[:, j],
                width=width,
                color=colors_ch[ch],
                alpha=alpha,
                edgecolor="none",
            )
    ax_a.set_xticks(x, [SHORT[c] for c in CLASSES])
    ax_a.set_ylabel("mean channel (scaled)")
    ax_a.spines[["top", "right"]].set_visible(False)
    ax_a.set_title(
        r"Mean true-color channels by class: source vs target ($P_{33}$ cut)",
        loc="left",
        fontsize=8.5,
    )
    handles = [
        Patch(facecolor=colors_ch["R"], edgecolor="none", label="R"),
        Patch(facecolor=colors_ch["G"], edgecolor="none", label="G"),
        Patch(facecolor=colors_ch["B"], edgecolor="none", label="B"),
        Patch(facecolor="#666666", alpha=0.95, edgecolor="none", label="source"),
        Patch(facecolor="#666666", alpha=0.45, edgecolor="none", label="target"),
    ]
    ax_a.legend(handles=handles, frameon=False, ncol=5, loc="upper right", fontsize=6)
    _tag(ax_a, "a")

    ax_b = fig.add_subplot(gs[1])
    data_src, data_tgt = [], []
    positions_src, positions_tgt = [], []
    for i, cls in enumerate(CLASSES):
        pool = m[m.label == cls]
        s = sample_stats(pool[pool.lon >= P33], rng, N_PER)
        t = sample_stats(pool[pool.lon < P33], rng, N_PER)
        positions_src.append(i - 0.18)
        positions_tgt.append(i + 0.18)
        data_src.append(s["GREEN"] if s else np.array([np.nan]))
        data_tgt.append(t["GREEN"] if t else np.array([np.nan]))

    vp_s = ax_b.violinplot(
        data_src, positions=positions_src, widths=0.32, showmeans=True, showextrema=False
    )
    vp_t = ax_b.violinplot(
        data_tgt, positions=positions_tgt, widths=0.32, showmeans=True, showextrema=False
    )
    for b in vp_s["bodies"]:
        b.set_facecolor(C_SRC)
        b.set_alpha(0.65)
        b.set_edgecolor("none")
    for b in vp_t["bodies"]:
        b.set_facecolor(C_TGT)
        b.set_alpha(0.65)
        b.set_edgecolor("none")
    if "cmeans" in vp_s:
        vp_s["cmeans"].set_color(C_SRC)
        vp_t["cmeans"].set_color(C_TGT)

    green_lab = (
        r"NDVI-like $(B08-B04)/(B08+B04)$"
        if modes == {"MS"}
        else r"greenness $(G-R)/(G+R)$"
        if modes == {"RGB"}
        else r"greenness / NDVI-like index"
    )
    ax_b.set_xticks(range(len(CLASSES)), [SHORT[c] for c in CLASSES])
    ax_b.set_ylabel(green_lab)
    ax_b.spines[["top", "right"]].set_visible(False)
    ax_b.set_title(
        r"Per-tile greenness distributions: source vs target (seeded subsample)",
        loc="left",
        fontsize=8.5,
    )
    ax_b.legend(
        handles=[
            Patch(facecolor=C_SRC, alpha=0.65, edgecolor="none", label="source"),
            Patch(facecolor=C_TGT, alpha=0.65, edgecolor="none", label="target"),
        ],
        frameon=False,
        loc="upper right",
    )
    _tag(ax_b, "b")

    mode = "+".join(sorted(modes)) if modes else "none"
    fig.suptitle(
        rf"Spectral fingerprint of the geographic shift (local tiles={mode}; $P_{{33}}$={P33:.1f}$^\circ$E)",
        fontsize=9.5,
        y=0.995,
    )
    fig.text(
        0.5,
        0.005,
        rf"Illustrative subsample ($\leq${N_PER} tiles/class/side); not a new experiment. "
        rf"source $n$={n_src}, target $n$={n_tgt}.",
        ha="center",
        fontsize=6.5,
        color="#333333",
    )

    pdf = OUT / "F15_shift_fingerprint.pdf"
    png = ART / "F15_shift_fingerprint.png"
    fig.savefig(pdf, bbox_inches="tight")
    fig.savefig(png, dpi=200, bbox_inches="tight")
    plt.close(fig)
    print(f"wrote {pdf}; mode={mode}")


if __name__ == "__main__":
    main()
