#!/usr/bin/env python3
"""F9_geopatches.pdf — geographic shift at patch level (expanded).

3 x 6 panel grid:
  rows  = source (lon >= P33) / boundary-near (|lon-P33| <= 1.5°) / target (lon < P33)
  cols  = six EuroSAT land-cover classes

True-color tiles keyed to the frozen MS centroid manifest. Prefer local
EuroSAT-MS GeoTIFF (B04/B03/B02) when present; otherwise the matching
EuroSAT RGB JPEG (same Class_N tile ID).

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

C_INK = "#000000"
COL_W = 7.2


def _style():
    plt.rcParams.update(
        {
            "font.size": 8,
            "axes.titlesize": 8,
            "axes.labelsize": 7.5,
            "figure.facecolor": "white",
            "axes.facecolor": "white",
            "savefig.facecolor": "white",
            "text.color": C_INK,
        }
    )


def rgb_path_from_rel(rel: str) -> Path:
    # EuroSAT_MS/Class/Class_n.tif -> eurosat/2750/Class/Class_n.jpg
    name = Path(rel).name.replace(".tif", ".jpg")
    cls = Path(rel).parts[-2]
    return RGB_ROOT / cls / name


def read_rgb(rel: str) -> tuple[np.ndarray, str]:
    """Return (HxWx3 float image in [0,1], source_tag)."""
    ms = MS_ROOT / rel
    if ms.is_file():
        with rasterio.open(ms) as ds:
            a = ds.read([4, 3, 2]).astype(np.float32)
        img = np.clip(a / 3000.0, 0, 1).transpose(1, 2, 0) ** 0.75
        return img, "MS"
    jp = rgb_path_from_rel(rel)
    if jp.is_file():
        arr = np.asarray(Image.open(jp).convert("RGB"), dtype=np.float32) / 255.0
        return arr, "RGB"
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
        ("source", "source\n" + r"lon $\geq$ P33"),
        ("boundary", "boundary\n" + rf"$|$lon$-$P33$|\!\leq\!{BOUNDARY_W}^\circ$"),
        ("target", "target\n" + r"lon $<$ P33"),
    )

    fig, axes = plt.subplots(
        3,
        len(CLASSES),
        figsize=(COL_W, 4.35),
        gridspec_kw={"hspace": 0.18, "wspace": 0.05},
    )

    missing = []
    src_tags = set()
    used: set[str] = set()
    for col, cls in enumerate(CLASSES):
        pool = m[m.label == cls]
        for row, (side, ylab) in enumerate(sides):
            ax = axes[row, col]
            df = side_pool(pool, side, P33)
            rec, tag = pick_patch(df, rng, used)
            ax.set_xticks([])
            ax.set_yticks([])
            for sp in ax.spines.values():
                sp.set_visible(False)
            if rec is None:
                ax.set_facecolor("#EEEEEE")
                ax.text(
                    0.5,
                    0.5,
                    "n/a",
                    ha="center",
                    va="center",
                    fontsize=7,
                    color="#666666",
                )
                missing.append(f"{side}/{cls}")
            else:
                img, tag = read_rgb(rec.relpath)
                src_tags.add(tag)
                ax.imshow(img, interpolation="nearest")
                ax.text(
                    0.04,
                    0.94,
                    f"{rec.lon:.1f}E {rec.lat:.1f}N",
                    transform=ax.transAxes,
                    fontsize=5.2,
                    color="white",
                    va="top",
                    ha="left",
                    bbox=dict(facecolor="black", alpha=0.45, pad=0.55, lw=0),
                )
            if row == 0:
                ax.set_title(SHORT[cls], fontsize=7.5, pad=2)
            if col == 0:
                ax.set_ylabel(ylab, fontsize=6.5)

    mode = "+".join(sorted(src_tags)) if src_tags else "none"
    fig.suptitle(
        rf"Geographic shift at patch level (true-color; $P_{{33}}$={P33:.1f}$^\circ$E)",
        fontsize=9,
        y=0.995,
    )
    fig.text(
        0.5,
        0.01,
        rf"source $n$={n_src}; target $n$={n_tgt}; boundary $\pm${BOUNDARY_W}$^\circ$; "
        rf"tiles={mode} (seeded; same IDs as frozen MS manifest)",
        ha="center",
        fontsize=6.5,
        color="#333333",
    )

    pdf = OUT / "F9_geopatches.pdf"
    png = ART / "F9_geopatches.png"
    fig.savefig(pdf, bbox_inches="tight")
    fig.savefig(png, dpi=200, bbox_inches="tight")
    plt.close(fig)
    print(f"wrote {pdf}; missing={missing or 'none'}; mode={mode}; P33={P33:.3f}")


if __name__ == "__main__":
    main()
