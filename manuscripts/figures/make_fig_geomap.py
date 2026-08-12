#!/usr/bin/env python3
"""F8_geomap.pdf — geographic-shift construction as a 2x2 multi-panel map
(geo ISPRS kit).

Panels (all from frozen manifest centroids; no new experiments):
  (a) Full Europe scatter at the paper's P33 longitude cut
      (source = lon >= P33, n=18090; target = lon < P33, n=8910).
  (b) Zoom: Iberia/Atlantic target vs Central Europe source.
  (c) Class-colored centroids (seeded subsample) — geographic class mix.
  (d) Longitude histograms + P25/P33/P50 guides and source/target counts.

Data: experiments/results/eurosat_spatial/manifest.csv (27,000 patches).
Coastline: local pyogrio naturalearth_lowres fixture (no network).
"""
from __future__ import annotations

from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import pyogrio

GEO = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
ART = Path(
    "/home/zeyufu/Desktop/ml-reliability-research/.omc/artifacts/"
    "visual-ralph/geo-rotcert-expand/geo"
)
ART.mkdir(parents=True, exist_ok=True)

MANIFEST = GEO / "experiments" / "results" / "eurosat_spatial" / "manifest.csv"
SHP = (
    Path.home()
    / "miniconda3/envs/dl/lib/python3.13/site-packages/pyogrio/tests/fixtures/"
    "naturalearth_lowres/naturalearth_lowres.shp"
)

# Print-safe Okabe–Ito (avoid purple AI defaults)
C_SRC = "#009E73"  # bluish green — source
C_TGT = "#0072B2"  # blue — target
C_INK = "#000000"
C_LAND = "#F2F2F2"
C_EDGE = "#BBBBBB"
C_MUTED = "#555555"

# Distinct, print-safe class palette (10 EuroSAT classes)
CLASS_COLORS = {
    "AnnualCrop": "#E69F00",
    "Forest": "#009E73",
    "HerbaceousVegetation": "#56B4E9",
    "Highway": "#000000",
    "Industrial": "#D55E00",
    "Pasture": "#F0E442",
    "PermanentCrop": "#0072B2",
    "Residential": "#CC79A7",
    "River": "#999999",
    "SeaLake": "#44AA99",
}

COL_W = 7.0  # double-column friendly


def _style():
    plt.rcParams.update(
        {
            "font.size": 8,
            "axes.titlesize": 9,
            "axes.labelsize": 8,
            "xtick.labelsize": 7,
            "ytick.labelsize": 7,
            "legend.fontsize": 6.5,
            "axes.edgecolor": C_INK,
            "axes.labelcolor": C_INK,
            "xtick.color": C_INK,
            "ytick.color": C_INK,
            "text.color": C_INK,
            "figure.facecolor": "white",
            "axes.facecolor": "white",
            "savefig.facecolor": "white",
        }
    )


def _tag(ax, letter: str):
    ax.text(
        0.02,
        0.98,
        letter,
        transform=ax.transAxes,
        fontweight="bold",
        fontsize=11,
        va="top",
        ha="left",
        color=C_INK,
        zorder=10,
    )


def _draw_land(ax, lon0, lon1, lat0, lat1, pad=2.0):
    """Draw Natural Earth land polygons clipped to the view (pyogrio)."""
    gdf = pyogrio.read_dataframe(str(SHP))
    for geom in gdf.geometry:
        if geom is None or geom.is_empty:
            continue
        minx, miny, maxx, maxy = geom.bounds
        if maxx < lon0 - pad or minx > lon1 + pad:
            continue
        if maxy < lat0 - pad or miny > lat1 + pad:
            continue
        geoms = list(geom.geoms) if geom.geom_type == "MultiPolygon" else [geom]
        for poly in geoms:
            if poly.is_empty or poly.exterior is None:
                continue
            xs, ys = poly.exterior.xy
            ax.fill(
                xs,
                ys,
                facecolor=C_LAND,
                edgecolor=C_EDGE,
                lw=0.35,
                zorder=1,
            )


def _cut_lines(ax, P25, P33, P50, y_annot=None):
    for cut, ls, lw in ((P33, "--", 1.1), (P25, ":", 0.75), (P50, ":", 0.75)):
        ax.axvline(cut, color=C_INK, lw=lw, ls=ls, zorder=4)
    if y_annot is not None:
        ax.text(
            P33,
            y_annot,
            f"P33 = {P33:.1f}$^\\circ$E",
            fontsize=6.5,
            ha="center",
            va="top",
        )


def main():
    _style()
    if not SHP.is_file():
        raise FileNotFoundError(f"Natural Earth shapefile missing: {SHP}")
    if not MANIFEST.is_file():
        raise FileNotFoundError(f"manifest missing: {MANIFEST}")

    m = pd.read_csv(MANIFEST)
    P33 = float(m.lon.quantile(0.33))
    P25 = float(m.lon.quantile(0.25))
    P50 = float(m.lon.quantile(0.50))
    n_src = int((m.lon >= P33).sum())
    n_tgt = int((m.lon < P33).sum())
    assert n_src == 18090 and n_tgt == 8910, (n_src, n_tgt)

    rng = np.random.default_rng(0)
    idx = rng.choice(len(m), size=4000, replace=False)
    sub = m.iloc[idx]
    src = sub[sub.lon >= P33]
    tgt = sub[sub.lon < P33]

    # Class subsample for panel (c): denser but still light
    idx_c = rng.choice(len(m), size=6000, replace=False)
    sub_c = m.iloc[idx_c]

    fig, axes = plt.subplots(2, 2, figsize=(COL_W, 5.6))
    ax_a, ax_b = axes[0]
    ax_c, ax_d = axes[1]

    # --- (a) full Europe ---
    _draw_land(ax_a, -12, 35, 34, 66)
    ax_a.scatter(
        tgt.lon,
        tgt.lat,
        s=1.0,
        color=C_TGT,
        alpha=0.45,
        lw=0,
        zorder=2,
        label=rf"target (lon $<$ P33), $n$={n_tgt}",
    )
    ax_a.scatter(
        src.lon,
        src.lat,
        s=1.0,
        color=C_SRC,
        alpha=0.45,
        lw=0,
        zorder=3,
        label=rf"source (lon $\geq$ P33), $n$={n_src}",
    )
    _cut_lines(ax_a, P25, P33, P50, y_annot=64.0)
    ax_a.text(P25 - 0.35, 35.2, "P25", fontsize=6, ha="right", color=C_MUTED)
    ax_a.text(P50 + 0.35, 35.2, "P50", fontsize=6, ha="left", color=C_MUTED)
    ax_a.set_xlim(-12, 35)
    ax_a.set_ylim(34, 66)
    ax_a.set_xlabel(r"longitude ($^\circ$E)")
    ax_a.set_ylabel(r"latitude ($^\circ$N)")
    ax_a.spines[["top", "right"]].set_visible(False)
    ax_a.legend(
        frameon=False,
        loc="lower right",
        markerscale=5,
        handletextpad=0.1,
        borderaxespad=0.15,
    )
    ax_a.set_title("Full Europe, $P_{33}$ cut", loc="left", fontsize=8.5)
    _tag(ax_a, "a")

    # --- (b) Iberia / Atlantic target vs Central Europe source zoom ---
    # Two linked zooms drawn on one axes with shared cut line.
    _draw_land(ax_b, -10, 20, 36, 56)
    # Full subsample but emphasize the two regions with larger markers
    iber = sub[(sub.lon > -10) & (sub.lon < P33) & (sub.lat > 36) & (sub.lat < 44)]
    cent = sub[(sub.lon >= P33) & (sub.lon < 20) & (sub.lat > 45) & (sub.lat < 55)]
    ax_b.scatter(sub.lon, sub.lat, s=0.4, color="#CCCCCC", alpha=0.25, lw=0, zorder=2)
    ax_b.scatter(
        iber.lon,
        iber.lat,
        s=2.2,
        color=C_TGT,
        alpha=0.55,
        lw=0,
        zorder=3,
        label="Iberia/Atlantic target",
    )
    ax_b.scatter(
        cent.lon,
        cent.lat,
        s=2.2,
        color=C_SRC,
        alpha=0.55,
        lw=0,
        zorder=4,
        label="Central Europe source",
    )
    _cut_lines(ax_b, P25, P33, P50)
    ax_b.set_xlim(-10, 20)
    ax_b.set_ylim(36, 56)
    ax_b.set_xlabel(r"longitude ($^\circ$E)")
    ax_b.set_ylabel(r"latitude ($^\circ$N)")
    ax_b.spines[["top", "right"]].set_visible(False)
    ax_b.legend(frameon=False, loc="upper right", markerscale=3.5, handletextpad=0.1)
    ax_b.set_title("Zoom: Iberia/Atlantic vs Central Europe", loc="left", fontsize=8.5)
    _tag(ax_b, "b")

    # --- (c) class-colored geographic mix ---
    _draw_land(ax_c, -12, 35, 34, 66)
    # plot rarer classes on top for visibility
    order = sorted(CLASS_COLORS.keys(), key=lambda k: (sub_c.label == k).sum())
    for cls in order:
        g = sub_c[sub_c.label == cls]
        ax_c.scatter(
            g.lon,
            g.lat,
            s=1.4,
            color=CLASS_COLORS[cls],
            alpha=0.55,
            lw=0,
            zorder=2,
            label=cls,
        )
    ax_c.axvline(P33, color=C_INK, lw=1.0, ls="--", zorder=4)
    ax_c.set_xlim(-12, 35)
    ax_c.set_ylim(34, 66)
    ax_c.set_xlabel(r"longitude ($^\circ$E)")
    ax_c.set_ylabel(r"latitude ($^\circ$N)")
    ax_c.spines[["top", "right"]].set_visible(False)
    ax_c.legend(
        frameon=False,
        loc="lower right",
        ncol=2,
        markerscale=4,
        handletextpad=0.05,
        columnspacing=0.6,
        borderaxespad=0.15,
        fontsize=5.5,
    )
    ax_c.set_title("Class mix across the cut (subsample)", loc="left", fontsize=8.5)
    _tag(ax_c, "c")

    # --- (d) lon histograms + count bars ---
    # Split panel: left = lon density with cut lines; right = source/target n bars
    ax_d.set_axis_off()
    gs = ax_d.get_subplotspec().subgridspec(1, 2, wspace=0.35, width_ratios=[1.55, 1.0])
    ax_h = fig.add_subplot(gs[0, 0])
    ax_bar = fig.add_subplot(gs[0, 1])

    bins = np.linspace(-12, 35, 48)
    ax_h.hist(
        m.loc[m.lon < P33, "lon"],
        bins=bins,
        color=C_TGT,
        alpha=0.65,
        label="target",
        edgecolor="none",
    )
    ax_h.hist(
        m.loc[m.lon >= P33, "lon"],
        bins=bins,
        color=C_SRC,
        alpha=0.55,
        label="source",
        edgecolor="none",
    )
    for cut, ls in ((P25, ":"), (P33, "--"), (P50, ":")):
        ax_h.axvline(cut, color=C_INK, lw=1.0 if ls == "--" else 0.75, ls=ls)
    ymax = ax_h.get_ylim()[1]
    for cut, lab, dy in ((P25, "P25", 0.88), (P33, "P33", 0.98), (P50, "P50", 0.88)):
        ax_h.text(cut, ymax * dy, lab, fontsize=6, ha="center", va="top", color=C_MUTED)
    ax_h.set_xlim(-12, 35)
    ax_h.set_xlabel(r"longitude ($^\circ$E)")
    ax_h.set_ylabel("tile count")
    ax_h.spines[["top", "right"]].set_visible(False)
    ax_h.legend(frameon=False, loc="upper right")
    ax_h.set_title("Lon density + cut sweep", loc="left", fontsize=8)
    _tag(ax_h, "d")

    ax_bar.bar(
        [0, 1],
        [n_src, n_tgt],
        color=[C_SRC, C_TGT],
        width=0.65,
        edgecolor="none",
    )
    ax_bar.set_xticks([0, 1], [r"source" + "\n" + r"$\geq$P33", r"target" + "\n" + r"$<$P33"])
    ax_bar.set_ylabel("tiles")
    for i, n in enumerate((n_src, n_tgt)):
        ax_bar.text(i, n + 200, f"{n:,}", ha="center", va="bottom", fontsize=7)
    ax_bar.set_ylim(0, max(n_src, n_tgt) * 1.18)
    ax_bar.spines[["top", "right"]].set_visible(False)
    ax_bar.set_title("Split sizes", loc="left", fontsize=8)

    fig.suptitle(
        "Geographic shift construction (EuroSAT-MS, frozen $P_{33}$ cut)",
        fontsize=10,
        y=0.995,
    )
    fig.tight_layout(rect=[0, 0, 1, 0.98])

    pdf = OUT / "F8_geomap.pdf"
    png = ART / "F8_geomap.png"
    fig.savefig(pdf, bbox_inches="tight")
    fig.savefig(png, dpi=200, bbox_inches="tight")
    plt.close(fig)
    print(
        f"wrote {pdf}; P33={P33:.3f}; source={n_src} target={n_tgt}; "
        f"P25={P25:.3f} P50={P50:.3f}"
    )


if __name__ == "__main__":
    main()
