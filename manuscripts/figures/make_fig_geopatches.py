#!/usr/bin/env python3
"""F9_geopatches.pdf — what the geographic shift looks like at patch level
(geo ISPRS kit; class-1 direct-imagery figure the paper currently lacks).

2 x 4 panel: the same four land-cover classes (AnnualCrop, Forest,
Residential, SeaLake) drawn from the source (lon >= P33, top row) and
target (lon < P33, bottom row) sides of the paper's P33 cut. True-color
composite (B04/B03/B02, per-panel 2-98% stretch). Message: the shift is
real but subtle at single-patch level -- region-specific crop structure,
settlement texture, and water color differ systematically across the cut.

Data: data/eurosat_ms/extracted/EuroSAT_MS (local), patch coords from
results_expansion_2026-07-09/eurosat_spatial/manifest.csv.
"""
import sys
from pathlib import Path

GEO = Path("/home/zeyufu/Desktop/ml-reliability-research/geospatial-fm-reliability-research")
IG_STYLE = Path("/home/zeyufu/Desktop/ml-reliability-research/reliability-commons/tools/inspect-gate/figures_2026-07-19")
sys.path.insert(0, str(IG_STYLE))
import figstyle

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import rasterio

figstyle.apply()

m = pd.read_csv(GEO / "results_expansion_2026-07-09" / "eurosat_spatial" / "manifest.csv")
P33 = float(m.lon.quantile(0.33))
ROOT = GEO / "data" / "eurosat_ms" / "extracted"

CLASSES = ["AnnualCrop", "Forest", "Residential", "SeaLake"]
rng = np.random.default_rng(7)


def read_rgb(rel):
    with rasterio.open(ROOT / rel) as ds:
        a = ds.read([4, 3, 2]).astype(np.float32)  # B04,B03,B02 -> RGB
    # fixed Sentinel-2 L2A stretch + mild gamma lift (honest channel balance,
    # no per-panel noise amplification)
    return np.clip(a / 3000.0, 0, 1).transpose(1, 2, 0) ** 0.75


fig, axes = plt.subplots(2, 4, figsize=(figstyle.COL_WIDTH_IN, 2.6),
                         gridspec_kw={"hspace": 0.45, "wspace": 0.06})
for col, cls in enumerate(CLASSES):
    pool = m[m.label == cls]
    src = pool[pool.lon >= P33]
    tgt = pool[pool.lon < P33]
    for row, (side, df) in enumerate((("source", src), ("target", tgt))):
        # pick a legible patch: brightness closest to 0.35 (avoid dark water
        # and saturated/noisy candidates), <=20 tries
        rec, best = None, 1e9
        for _ in range(20):
            cand = df.iloc[int(rng.integers(len(df)))]
            img = read_rgb(cand.relpath)
            score = abs(img.mean() - 0.35)
            if score < best:
                rec, best = cand, score
        ax = axes[row, col]
        ax.imshow(read_rgb(rec.relpath), interpolation="nearest")
        ax.set_xticks([]); ax.set_yticks([])
        for sp in ax.spines.values():
            sp.set_visible(False)
        if row == 0:
            ax.set_title(cls, fontsize=figstyle.FONT_TICK)
        if col == 0:
            side_lab = r"lon $\geq$ P33" if side == "source" else r"lon $<$ P33"
            ax.set_ylabel(f"{side}\n{side_lab}", fontsize=figstyle.FONT_TICK)
        ax.text(0.04, 0.94, f"{rec.lon:.1f}E {rec.lat:.1f}N",
                transform=ax.transAxes, fontsize=5.4, color="white",
                va="top", ha="left",
                bbox=dict(facecolor="black", alpha=0.45, pad=0.6, lw=0))

out = GEO / "manuscripts" / "figures" / "F9_geopatches.pdf"
fig.savefig(out)
print(f"wrote {out}")
