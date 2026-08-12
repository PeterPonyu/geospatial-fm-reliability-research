#!/usr/bin/env python3
"""F9_geopatches.pdf — geographic shift at patch level (expanded).

3 x 6 panel grid:
  rows  = source (lon >= P33) / boundary-near (|lon-P33| <= 1.5°) / target (lon < P33)
  cols  = six EuroSAT land-cover classes

True-color tiles keyed to the frozen MS centroid manifest. Prefer local
EuroSAT-MS GeoTIFF (B04/B03/B02) when present; otherwise the matching
EuroSAT RGB JPEG (same Class_N tile ID).

P33 cut science unchanged (source n=18090, target n=8910).

Typography: Nimbus Roman (same Times-compatible stack as ggtheme.R /
PAPER_FONT). No decorative A/B/C/D panel letters.
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
from matplotlib.patches import FancyBboxPatch, Rectangle
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
# Keep gridspec cells ~square so aspect='equal' does not letterbox (the main
# source of huge row gaps). Leave hspace room for lon/lat xlabels only.
FIG_H = 3.85
UPSAMPLE = 480  # native EuroSAT is 64×64; Lanczos upsample for print DPI
C_INK = "#111111"

# Okabe–Ito semantics (match F8 geomap source/target; boundary distinct).
ROW_ACCENT = {
    "source": "#009E73",  # bluish green
    "boundary": "#E69F00",  # orange — not the target tan
    "target": "#0072B2",  # blue
}
ROW_FACE = {
    "source": "#E8F5F0",
    "boundary": "#FFF6E0",
    "target": "#E6F0F8",
}

# Manuscript-consistent Times clone (ggtheme.R PAPER_FONT).
PAPER_FONT = "Nimbus Roman"


def _style():
    plt.rcParams.update(
        {
            "font.family": PAPER_FONT,
            "font.size": 11,
            "axes.titlesize": 11,
            "axes.labelsize": 9.5,
            "mathtext.fontset": "stix",
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

    Prefer EuroSAT-MS B04/B03/B02; fall back to the matching RGB JPEG.
    """
    ms = MS_ROOT / rel
    if ms.is_file():
        with rasterio.open(ms) as ds:
            a = ds.read([4, 3, 2]).astype(np.float32)
        img = np.clip(a / 3000.0, 0, 1).transpose(1, 2, 0) ** 0.75
        return upsample_rgb(img), "MS"
    jp = rgb_path_from_rel(rel)
    if jp.is_file():
        arr = np.asarray(Image.open(jp).convert("RGB"), dtype=np.float32) / 255.0
        return upsample_rgb(arr), "RGB"
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


def draw_row_label(ax, side: str, title: str, cond: str) -> None:
    """Semantic row label: accent bar + equal-height chip for every row.

    Source / Boundary / Target share one chip box (same y/h) so visual weight
    matches. Multi-line conditions keep a slightly smaller condition font;
    single-line rows use the extra vertical room for title/condition spacing.
    """
    accent = ROW_ACCENT[side]
    face = ROW_FACE[side]
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.set_xticks([])
    ax.set_yticks([])
    for sp in ax.spines.values():
        sp.set_visible(False)
    ax.set_facecolor("white")

    # Uniform chip geometry across all three rows (match Boundary visual weight).
    chip_x, chip_y, chip_w, chip_h = 0.00, 0.12, 1.00, 0.76
    bar_w = 0.06
    n_cond_lines = cond.count("\n") + 1
    if n_cond_lines >= 2:
        title_y, cond_y, cond_fs = 0.74, 0.34, 7.4
    else:
        # Same box; space title / condition evenly inside the shared height.
        title_y, cond_y, cond_fs = 0.66, 0.36, 8.2

    # Full-width chip; clip_on keeps any residual glyphs inside the axes frame.
    chip = FancyBboxPatch(
        (chip_x, chip_y),
        chip_w,
        chip_h,
        boxstyle="round,pad=0.012,rounding_size=0.03",
        linewidth=1.0,
        edgecolor=accent,
        facecolor=face,
        transform=ax.transAxes,
        clip_on=True,
        zorder=1,
    )
    ax.add_patch(chip)
    bar = Rectangle(
        (chip_x, chip_y),
        bar_w,
        chip_h,
        linewidth=0,
        facecolor=accent,
        transform=ax.transAxes,
        clip_on=True,
        zorder=2,
    )
    ax.add_patch(bar)
    text_x = chip_x + bar_w + (chip_w - bar_w) / 2.0
    ax.text(
        text_x,
        title_y,
        title,
        ha="center",
        va="center",
        fontsize=11.5,
        fontweight="bold",
        fontfamily=PAPER_FONT,
        color=C_INK,
        transform=ax.transAxes,
        zorder=3,
        clip_on=True,
    )
    ax.text(
        text_x,
        cond_y,
        cond,
        ha="center",
        va="center",
        fontsize=cond_fs,
        fontfamily=PAPER_FONT,
        color="#222222",
        transform=ax.transAxes,
        zorder=3,
        linespacing=1.05,
        clip_on=True,
    )


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
    # STIX mathtext for P_{33} (Nimbus Roman lacks Unicode subscripts; avoids DejaVu).
    sides = (
        ("source", "Source", r"lon $\geq P_{33}$"),
        (
            "boundary",
            "Boundary",
            # Two-line explicit band (matches caption science); stays inside chip.
            rf"$|\mathrm{{lon}}\!-\!P_{{33}}|$"
            + "\n"
            + rf"$\leq\!{BOUNDARY_W:.1f}^\circ$",
        ),
        ("target", "Target", r"lon $< P_{33}$"),
    )

    fig = plt.figure(figsize=(FIG_W, FIG_H))
    # Wider left gutter for Boundary chip; hspace only for lon/lat under patches.
    gs = GridSpec(
        3,
        7,
        figure=fig,
        width_ratios=[1.18] + [1.0] * 6,
        height_ratios=[1, 1, 1],
        wspace=0.07,
        hspace=0.14,
        left=0.012,
        right=0.995,
        top=0.88,
        bottom=0.04,
    )

    missing = []
    src_tags = set()
    used: set[str] = set()

    for row, (side, title, cond) in enumerate(sides):
        lab_ax = fig.add_subplot(gs[row, 0])
        draw_row_label(lab_ax, side, title, cond)

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
                    fontsize=10,
                    fontfamily=PAPER_FONT,
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
                    fontsize=8.0,
                    labelpad=0.8,
                    color=C_INK,
                    fontfamily=PAPER_FONT,
                )
            if row == 0:
                ax.set_title(
                    SHORT[cls],
                    fontsize=10.5,
                    pad=4,
                    fontweight="bold",
                    fontfamily=PAPER_FONT,
                )

    # Title-only chrome; secondary “illustrative tiles…” lives in the manuscript caption.
    fig.suptitle(
        rf"Geographic shift at patch level "
        rf"(true-color Sentinel-2; $P_{{33}}={P33:.1f}^\circ$E)",
        fontsize=12.5,
        y=0.975,
        fontweight="bold",
        fontfamily=PAPER_FONT,
    )

    pdf = OUT / "F9_geopatches.pdf"
    png = ART / "F9_geopatches.png"
    # dpi=400 for print-grade raster fallback; vector PDF is authoritative.
    fig.savefig(pdf, dpi=400, bbox_inches="tight", pad_inches=0.02)
    fig.savefig(png, dpi=400, bbox_inches="tight", pad_inches=0.02)
    plt.close(fig)
    mode = "+".join(sorted(src_tags)) if src_tags else "none"
    print(f"wrote {pdf}; missing={missing or 'none'}; mode={mode}; P33={P33:.3f}")


if __name__ == "__main__":
    main()
