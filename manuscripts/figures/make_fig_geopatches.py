#!/usr/bin/env python3
"""F9_geopatches.pdf — geographic shift at patch level (expanded).

3 x 6 panel grid:
  rows  = source (lon >= P33) / boundary-near (|lon-P33| <= 1.5°) / target (lon < P33)
  cols  = six EuroSAT land-cover classes

True-color tiles keyed to the frozen MS centroid manifest. Prefer the
EuroSAT RGB JPEG for consistent on-page appearance across all classes;
fall back to EuroSAT-MS GeoTIFF (B04/B03/B02) when the RGB twin is missing.

P33 cut science unchanged (source n=18090, target n=8910).
"""
from __future__ import annotations

from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import rasterio
from matplotlib.gridspec import GridSpec
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
    "Residential": "Residential",
    "Highway": "Highway",
    "SeaLake": "SeaLake",
}
BOUNDARY_W = 1.5

# Match ~ISPRS single-column \linewidth so fonts are not shrunk at include time.
FIG_W = 7.15
FIG_H = 5.85
UPSAMPLE = 480  # native EuroSAT is 64×64; Lanczos upsample for print DPI (raised 2026-08-12 for print legibility)
C_INK = "#111111"
ROW_FACE = {
    "source": "#EEF4FA",
    "boundary": "#F7F3E8",
    "target": "#F3EEEA",
}


def _style():
    plt.rcParams.update(
        {
            "font.size": 10,
            "axes.titlesize": 10,
            "axes.labelsize": 9,
            "figure.facecolor": "white",
            "axes.facecolor": "white",
            "savefig.facecolor": "white",
            "text.color": C_INK,
            "pdf.fonttype": 42,
            "ps.fonttype": 42,
        }
    )


def rgb_path_from_rel(rel: str) -> Path:
    # EuroSAT_MS/Class/Class_n.tif -> eurosat/2750/Class/Class_n.jpg
    name = Path(rel).name.replace(".tif", ".jpg")
    cls = Path(rel).parts[-2]
    return RGB_ROOT / cls / name


def upsample_rgb(img: np.ndarray) -> np.ndarray:
    """Lanczos-upsample 64×64 tiles so print embedding keeps texture."""
    u8 = np.clip(np.round(img * 255.0), 0, 255).astype(np.uint8)
    pil = Image.fromarray(u8).resize((UPSAMPLE, UPSAMPLE), Image.Resampling.LANCZOS)
    return np.asarray(pil, dtype=np.float32) / 255.0


def read_rgb(rel: str) -> tuple[np.ndarray, str]:
    """Return (HxWx3 float image in [0,1], source_tag).

    RGB-first so all six classes share the same display transfer; MS is
    only a fallback when the matching JPEG is absent.
    """
    jp = rgb_path_from_rel(rel)
    if jp.is_file():
        arr = np.asarray(Image.open(jp).convert("RGB"), dtype=np.float32) / 255.0
        return upsample_rgb(arr), "RGB"
    ms = MS_ROOT / rel
    if ms.is_file():
        with rasterio.open(ms) as ds:
            a = ds.read([4, 3, 2]).astype(np.float32)
        img = np.clip(a / 3000.0, 0, 1).transpose(1, 2, 0) ** 0.75
        return upsample_rgb(img), "MS"
    raise FileNotFoundError(rel)


def pick_patch(df: pd.DataFrame, rng: np.random.Generator, used: set[str]):
    if len(df) == 0:
        return None, None
    pool = df[~df.relpath.isin(used)]
    if len(pool) == 0:
        pool = df
    rec, best, tag = None, 1e9, None
    n_try = min(24, len(pool))
    for _ in range(n_try):
        cand = pool.iloc[int(rng.integers(len(pool)))]
        try:
            img, src = read_rgb(cand.relpath)
        except FileNotFoundError:
            continue
        score = abs(float(img.mean()) - 0.35)
        if score < best:
            rec, best, tag = cand, score, src
    if rec is not None:
        used.add(str(rec.relpath))
    return rec, tag


def side_pool(pool: pd.DataFrame, side: str, P33: float) -> pd.DataFrame:
    if side == "source":
        return pool[pool.lon >= P33]
    if side == "target":
        return pool[pool.lon < P33]
    return pool[(pool.lon - P33).abs() <= BOUNDARY_W]


def fmt_ll(lon: float, lat: float) -> str:
    """Human-readable lon/lat with explicit hemisphere."""
    ew = "E" if lon >= 0 else "W"
    ns = "N" if lat >= 0 else "S"
    return f"{abs(lon):.1f}°{ew}  {abs(lat):.1f}°{ns}"


def main():
    _style()
    if not MANIFEST.is_file():
        raise FileNotFoundError(MANIFEST)
    if not RGB_ROOT.is_dir() and not (MS_ROOT / "EuroSAT_MS").is_dir():
        raise FileNotFoundError("Need EuroSAT RGB and/or MS tiles on disk")

    m = pd.read_csv(MANIFEST)
    P33 = float(m.lon.quantile(0.33))
    n_src = int((m.lon >= P33).sum())
    n_tgt = int((m.lon < P33).sum())
    assert n_src == 18090 and n_tgt == 8910, (n_src, n_tgt)

    rng = np.random.default_rng(7)
    sides = (
        ("source", "Source", rf"lon $\geq P_{{33}}$"),
        (
            "boundary",
            "Boundary",
            rf"$|\mathrm{{lon}}-P_{{33}}|\leq {BOUNDARY_W:.1f}^\circ$",
        ),
        ("target", "Target", rf"lon $< P_{{33}}$"),
    )

    fig = plt.figure(figsize=(FIG_W, FIG_H))
    # Left gutter for horizontal row labels; 3×6 patch grid.
    gs = GridSpec(
        3,
        7,
        figure=fig,
        width_ratios=[1.05] + [1.0] * 6,
        height_ratios=[1, 1, 1],
        wspace=0.08,
        hspace=0.28,
        left=0.02,
        right=0.995,
        top=0.90,
        bottom=0.05,
    )

    missing = []
    src_tags = set()
    used: set[str] = set()

    for row, (side, title, cond) in enumerate(sides):
        lab_ax = fig.add_subplot(gs[row, 0])
        lab_ax.set_xlim(0, 1)
        lab_ax.set_ylim(0, 1)
        lab_ax.set_xticks([])
        lab_ax.set_yticks([])
        for sp in lab_ax.spines.values():
            sp.set_visible(False)
        lab_ax.set_facecolor(ROW_FACE[side])
        lab_ax.text(
            0.5,
            0.60,
            title,
            ha="center",
            va="center",
            fontsize=9.5,
            fontweight="bold",
            color=C_INK,
            transform=lab_ax.transAxes,
        )
        lab_ax.text(
            0.5,
            0.28,
            cond,
            ha="center",
            va="center",
            fontsize=7.2,
            color="#333333",
            transform=lab_ax.transAxes,
        )

        for col, cls in enumerate(CLASSES):
            ax = fig.add_subplot(gs[row, col + 1])
            pool = m[m.label == cls]
            df = side_pool(pool, side, P33)
            rec, tag = pick_patch(df, rng, used)
            ax.set_xticks([])
            ax.set_yticks([])
            for sp in ax.spines.values():
                sp.set_color("#CCCCCC")
                sp.set_linewidth(0.6)
            if rec is None:
                ax.set_facecolor("#EEEEEE")
                ax.text(
                    0.5,
                    0.5,
                    "n/a",
                    ha="center",
                    va="center",
                    fontsize=9,
                    color="#666666",
                )
                missing.append(f"{side}/{cls}")
            else:
                img, tag = read_rgb(rec.relpath)
                src_tags.add(tag)
                ax.imshow(img, interpolation="bilinear", aspect="equal")
                # Place lat/lon under the patch (not over imagery) for print legibility.
                ax.set_xlabel(
                    fmt_ll(float(rec.lon), float(rec.lat)),
                    fontsize=7.4,
                    labelpad=2.5,
                    color=C_INK,
                )
            if row == 0:
                ax.set_title(SHORT[cls], fontsize=9.0, pad=3, fontweight="bold")

    fig.suptitle(
        rf"Geographic shift at patch level "
        rf"(true-color Sentinel-2; $P_{{33}}={P33:.1f}^\circ$E)",
        fontsize=10.5,
        y=0.975,
        fontweight="bold",
    )
    # Manuscript caption carries n / boundary science; keep figure chrome leak-free.
    fig.text(
        0.5,
        0.012,
        "Illustrative tiles (seeded); centroids annotated",
        ha="center",
        fontsize=7.2,
        color="#444444",
    )

    pdf = OUT / "F9_geopatches.pdf"
    png = ART / "F9_geopatches.png"
    # dpi=400 (raised 2026-08-12) for print-grade raster fallback when the
    # PDF is rasterised downstream; vector PDF is the authoritative output.
    fig.savefig(pdf, dpi=400, bbox_inches="tight", pad_inches=0.04)
    fig.savefig(png, dpi=400, bbox_inches="tight", pad_inches=0.04)
    plt.close(fig)
    mode = "+".join(sorted(src_tags)) if src_tags else "none"
    print(f"wrote {pdf}; missing={missing or 'none'}; mode={mode}; P33={P33:.3f}")


if __name__ == "__main__":
    main()
