#!/usr/bin/env python3
"""F8_geomap.pdf — geographic-shift construction as a 2x2 multi-panel map
(geo ISPRS kit).

Panels (all from frozen manifest centroids; no new experiments):
  (a) Full Europe scatter at the paper's P33 longitude cut
      (source = lon >= P33, n=18090; target = lon < P33, n=8910).
  (b) Zoom: Iberia/Atlantic target vs Central Europe source.
  (c) Class-colored centroids (seeded subsample) — geographic class mix.
  (d) Longitude histograms + P25/P33/P50 guides and source/target counts.

Typography: Nimbus Roman (same PAPER_FONT as manuscripts/figures/ggtheme.R).
Panel tags sit in the margin above-left of each spine (outside the drawing
area). Split legends sit in a dedicated strip under A/B; an explicit spacer
row separates A/B from C/D; the class legend is a 2×5 strip under C/D.

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
from matplotlib.lines import Line2D

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
    / "miniconda3/envs/dl/lib/python3.13/site-packages/pyogrio/tests/fixtures"
    / "naturalearth_lowres"
    / "naturalearth_lowres.shp"
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
CLASS_SHORT = {
    "AnnualCrop": "AnnualCrop",
    "Forest": "Forest",
    "HerbaceousVegetation": "Herb.Veg.",
    "Highway": "Highway",
    "Industrial": "Industrial",
    "Pasture": "Pasture",
    "PermanentCrop": "Perm.Crop",
    "Residential": "Residential",
    "River": "River",
    "SeaLake": "SeaLake",
}

# Match ISPRS full-width include; Nimbus Roman = ggtheme.R PAPER_FONT.
COL_W = 7.15
PAPER_FONT = "Nimbus Roman"

# Tightened Europe view (covers ≥99% of tiles; rare Atlantic outliers clipped).
LON0, LON1 = -9.0, 34.0
LAT0, LAT1 = 35.0, 61.5
# Zoom panel: Iberia/Atlantic vs Central Europe around the cut.
ZLON0, ZLON1 = -9.5, 18.0
ZLAT0, ZLAT1 = 36.0, 54.0


def _style():
    plt.rcParams.update(
        {
            # Pin to manuscript serif — same face as ggtheme.R PAPER_FONT.
            # No sans fallback list: Nimbus Roman is installed (urw-base35).
            "font.family": PAPER_FONT,
            "font.size": 8,
            "axes.titlesize": 8.5,
            "axes.labelsize": 8,
            "xtick.labelsize": 7,
            "ytick.labelsize": 7,
            "legend.fontsize": 6.5,
            "mathtext.fontset": "stix",
            "axes.edgecolor": C_INK,
            "axes.labelcolor": C_INK,
            "xtick.color": C_INK,
            "ytick.color": C_INK,
            "text.color": C_INK,
            "figure.facecolor": "white",
            "axes.facecolor": "white",
            "savefig.facecolor": "white",
            "pdf.fonttype": 42,
            "ps.fonttype": 42,
        }
    )


def _tag(ax, letter: str, y: float = 1.08):
    """Panel letter outside the drawing area: above-left of top-left spine."""
    # Axes-fraction offsets place the glyph in the reserved figure margin
    # (cf. ggtheme paper_tag_theme plot.tag.location = "margin").
    letter = str(letter).upper()
    ax.text(
        -0.14,
        y,
        letter,
        transform=ax.transAxes,
        fontsize=11,
        fontweight="bold",
        fontfamily=PAPER_FONT,
        va="bottom",
        ha="right",
        color=C_INK,
        clip_on=False,
        zorder=20,
    )


def _tag_fig_row(fig, ax, letter: str, y_fig: float):
    """Place a panel letter at a shared figure-y (row-aligned tags)."""
    bbox = ax.get_position()
    fig.text(
        bbox.x0 - 0.018,
        y_fig,
        str(letter).upper(),
        fontsize=11,
        fontweight="bold",
        fontfamily=PAPER_FONT,
        va="bottom",
        ha="right",
        color=C_INK,
        clip_on=False,
        zorder=20,
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
            fontfamily=PAPER_FONT,
        )


def _handles_scatter(items):
    """items: list of (facecolor, label)."""
    return [
        Line2D(
            [0],
            [0],
            marker="o",
            color="none",
            markerfacecolor=fc,
            markersize=5.5,
            label=lab,
        )
        for fc, lab in items
    ]


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

    idx_c = rng.choice(len(m), size=6000, replace=False)
    sub_c = m.iloc[idx_c]

    # Explicit figure-fraction layout (avoids GridSpec hspace collapse).
    # Landscape canvas fills ISPRS \linewidth; large mid-gap separates A/B from C/D.
    # Bands (bottom→top): class leg | C/D maps | ROW GAP | A/B leg | A/B maps | title.
    fig = plt.figure(figsize=(COL_W, 6.15))

    L = 0.062  # left (room for y-labels)
    R = 0.998  # right edge
    G = 0.028  # column gap
    CW = (R - L - G) / 2.0
    X0, X1 = L, L + CW + G

    # Vertical bands. Mid gap ~0.16 fig-fraction (~1.0 in) between A/B legends and C/D.
    Y_CLASS0, Y_CLASS1 = 0.012, 0.088
    Y_CD0, Y_CD1 = 0.155, 0.405
    Y_ABLEG0, Y_ABLEG1 = 0.565, 0.620
    Y_AB0, Y_AB1 = 0.675, 0.905
    # Implicit row gap: Y_CD1 (0.405) → Y_ABLEG0 (0.565) ≈ 0.16.

    ax_a = fig.add_axes([X0, Y_AB0, CW, Y_AB1 - Y_AB0])
    ax_b = fig.add_axes([X1, Y_AB0, CW, Y_AB1 - Y_AB0])
    ax_a_leg = fig.add_axes([X0, Y_ABLEG0, CW, Y_ABLEG1 - Y_ABLEG0])
    ax_b_leg = fig.add_axes([X1, Y_ABLEG0, CW, Y_ABLEG1 - Y_ABLEG0])
    ax_c = fig.add_axes([X0, Y_CD0, CW, Y_CD1 - Y_CD0])

    # D: histogram + bar share the right column of the C/D band.
    D_GAP = 0.024
    DW = CW - D_GAP
    DW_H = DW * 0.62
    DW_BAR = DW * 0.38
    ax_h = fig.add_axes([X1, Y_CD0, DW_H, Y_CD1 - Y_CD0])
    ax_bar = fig.add_axes([X1 + DW_H + D_GAP, Y_CD0, DW_BAR, Y_CD1 - Y_CD0])

    ax_c_leg = fig.add_axes([L, Y_CLASS0, R - L, Y_CLASS1 - Y_CLASS0])

    for ax_leg in (ax_a_leg, ax_b_leg, ax_c_leg):
        ax_leg.set_axis_off()

    # --- (a) full Europe ---
    _draw_land(ax_a, LON0, LON1, LAT0, LAT1)
    ax_a.scatter(tgt.lon, tgt.lat, s=0.85, color=C_TGT, alpha=0.40, lw=0, zorder=2)
    ax_a.scatter(src.lon, src.lat, s=0.85, color=C_SRC, alpha=0.40, lw=0, zorder=3)
    _cut_lines(ax_a, P25, P33, P50, y_annot=LAT1 - 1.0)
    ax_a.text(P25 - 0.35, LAT0 + 0.5, "P25", fontsize=6, ha="right", color=C_MUTED)
    ax_a.text(P50 + 0.35, LAT0 + 0.5, "P50", fontsize=6, ha="left", color=C_MUTED)
    ax_a.set_xlim(LON0, LON1)
    ax_a.set_ylim(LAT0, LAT1)
    ax_a.set_xlabel(r"longitude ($^\circ$E)", labelpad=2)
    ax_a.set_ylabel(r"latitude ($^\circ$N)", labelpad=2)
    ax_a.spines[["top", "right"]].set_visible(False)
    ax_a.set_title("Full Europe, $P_{33}$ cut", loc="left", pad=3)
    ax_a_leg.legend(
        handles=_handles_scatter(
            [
                (C_TGT, rf"target (lon $<$ P33), $n$={n_tgt}"),
                (C_SRC, rf"source (lon $\geq$ P33), $n$={n_src}"),
            ]
        ),
        frameon=False,
        loc="center",
        ncol=2,
        fontsize=6.8,
        handletextpad=0.35,
        borderaxespad=0.0,
        columnspacing=1.0,
        labelspacing=0.25,
        handlelength=1.0,
    )

    # --- (b) zoom ---
    _draw_land(ax_b, ZLON0, ZLON1, ZLAT0, ZLAT1)
    iber = sub[(sub.lon > ZLON0) & (sub.lon < P33) & (sub.lat > 36) & (sub.lat < 44)]
    cent = sub[(sub.lon >= P33) & (sub.lon < ZLON1) & (sub.lat > 45) & (sub.lat < 54)]
    ax_b.scatter(sub.lon, sub.lat, s=0.30, color="#CCCCCC", alpha=0.20, lw=0, zorder=2)
    ax_b.scatter(iber.lon, iber.lat, s=2.0, color=C_TGT, alpha=0.55, lw=0, zorder=3)
    ax_b.scatter(cent.lon, cent.lat, s=2.0, color=C_SRC, alpha=0.55, lw=0, zorder=4)
    _cut_lines(ax_b, P25, P33, P50)
    ax_b.set_xlim(ZLON0, ZLON1)
    ax_b.set_ylim(ZLAT0, ZLAT1)
    ax_b.set_xlabel(r"longitude ($^\circ$E)", labelpad=2)
    ax_b.set_ylabel(r"latitude ($^\circ$N)", labelpad=2)
    ax_b.spines[["top", "right"]].set_visible(False)
    ax_b.set_title("Zoom: Iberia/Atlantic vs Central Europe", loc="left", pad=3)
    ax_b_leg.legend(
        handles=_handles_scatter(
            [
                (C_TGT, "Iberia/Atlantic target"),
                (C_SRC, "Central Europe source"),
            ]
        ),
        frameon=False,
        loc="center",
        ncol=2,
        fontsize=6.8,
        handletextpad=0.35,
        borderaxespad=0.0,
        columnspacing=1.0,
        labelspacing=0.25,
        handlelength=1.0,
    )

    # --- (c) class mix ---
    _draw_land(ax_c, LON0, LON1, LAT0, LAT1)
    order = sorted(CLASS_COLORS.keys(), key=lambda k: (sub_c.label == k).sum())
    for cls in order:
        g = sub_c[sub_c.label == cls]
        ax_c.scatter(
            g.lon,
            g.lat,
            s=1.15,
            color=CLASS_COLORS[cls],
            alpha=0.50,
            lw=0,
            zorder=2,
        )
    ax_c.axvline(P33, color=C_INK, lw=1.0, ls="--", zorder=4)
    ax_c.set_xlim(LON0, LON1)
    ax_c.set_ylim(LAT0, LAT1)
    ax_c.set_xlabel(r"longitude ($^\circ$E)", labelpad=2)
    ax_c.set_ylabel(r"latitude ($^\circ$N)", labelpad=2)
    ax_c.spines[["top", "right"]].set_visible(False)
    ax_c.set_title("Class mix across the cut (subsample)", loc="left", pad=3)
    # C/D tags placed after layout with a shared figure-y (row-aligned).
    # Two rows × 5 cols so every handle keeps a readable label (no truncation).
    class_order_leg = list(CLASS_COLORS.keys())
    ax_c_leg.legend(
        handles=_handles_scatter(
            [(CLASS_COLORS[cls], CLASS_SHORT[cls]) for cls in class_order_leg]
        ),
        frameon=False,
        loc="center",
        ncol=5,
        fontsize=6.2,
        handletextpad=0.30,
        columnspacing=1.05,
        borderaxespad=0.0,
        labelspacing=0.55,
        markerscale=1.0,
        handlelength=1.0,
    )

    # --- (d) lon density + split sizes ---
    bins = np.linspace(LON0, LON1, 46)
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
        ax_h.text(
            cut,
            ymax * dy,
            lab,
            fontsize=6,
            ha="center",
            va="top",
            color=C_MUTED,
            fontfamily=PAPER_FONT,
        )
    ax_h.set_xlim(LON0, LON1)
    ax_h.set_xlabel(r"longitude ($^\circ$E)", labelpad=2)
    ax_h.set_ylabel("tile count", labelpad=2)
    ax_h.spines[["top", "right"]].set_visible(False)
    ax_h.legend(
        frameon=False,
        loc="upper left",
        borderaxespad=0.15,
        ncol=1,
        fontsize=6.5,
        handletextpad=0.3,
        labelspacing=0.25,
    )
    ax_h.set_title("Lon density + cut sweep", loc="left", pad=3)

    ax_bar.bar(
        [0, 1],
        [n_src, n_tgt],
        color=[C_SRC, C_TGT],
        width=0.65,
        edgecolor="none",
    )
    ax_bar.set_xticks(
        [0, 1], [r"source" + "\n" + r"$\geq$P33", r"target" + "\n" + r"$<$P33"]
    )
    ax_bar.set_ylabel("tiles")
    for i, n in enumerate((n_src, n_tgt)):
        ax_bar.text(i, n + 200, f"{n:,}", ha="center", va="bottom", fontsize=7)
    ax_bar.set_ylim(0, max(n_src, n_tgt) * 1.18)
    ax_bar.spines[["top", "right"]].set_visible(False)
    ax_bar.set_title("Split sizes", loc="left", pad=3)

    # Row-aligned panel tags above titles; clear of legends and the mid-row gap.
    y_ab = Y_AB1 + 0.012
    y_cd = Y_CD1 + 0.012
    _tag_fig_row(fig, ax_a, "A", y_ab)
    _tag_fig_row(fig, ax_b, "B", y_ab)
    _tag_fig_row(fig, ax_c, "C", y_cd)
    _tag_fig_row(fig, ax_h, "D", y_cd)

    fig.suptitle(
        "Geographic shift construction (EuroSAT-MS, frozen $P_{33}$ cut)",
        fontsize=10,
        fontfamily=PAPER_FONT,
        y=0.978,
        x=0.532,
    )

    pdf = OUT / "F8_geomap.pdf"
    png = ART / "F8_geomap.png"
    # Fixed canvas (no tight crop) so left/right fill and row gaps stay as designed.
    fig.savefig(pdf, bbox_inches=None, pad_inches=0.0)
    fig.savefig(png, dpi=200, bbox_inches=None, pad_inches=0.0)
    plt.close(fig)
    print(
        f"wrote {pdf}; P33={P33:.3f}; source={n_src} target={n_tgt}; "
        f"P25={P25:.3f} P50={P50:.3f}; lim=({LON0},{LON1})x({LAT0},{LAT1})"
    )


if __name__ == "__main__":
    main()
