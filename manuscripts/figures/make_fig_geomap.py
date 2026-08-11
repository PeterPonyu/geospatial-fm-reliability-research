#!/usr/bin/env python3
"""F8_geomap.pdf — the geographic-shift construction, shown as a map
(geo ISPRS kit; answers R2.2 "realism of the geographic-shift scenario" —
the single highest-value figure addition for the application bar).

EuroSAT-MS patch centroids (manifest lat/lon) over a Natural Earth land
outline, colored by split side at the paper's P33 longitude cut
(source = lon >= P33, E/Central Europe; target = lon < P33,
W/Iberian-Atlantic Europe). The P25/P50 sweep boundaries are drawn faintly
(boundary-sensitivity ablation lives in the paper's Table VI).

Data: results_expansion_2026-07-09/eurosat_spatial/manifest.csv (27,000
patches, subsampled to 4,000 seeded); coastline from the local pyogrio
naturalearth_lowres fixture (no network dependency).
"""
import sys
from pathlib import Path


def _portal_commons_root():
    import os
    from pathlib import Path
    for key in ("COMMONS_ROOT", "RELIABILITY_COMMONS"):
        v = os.environ.get(key)
        if v:
            p = Path(v).expanduser().resolve()
            if p.is_dir():
                return p
    here = Path(__file__).resolve()
    for parent in [here.parent, *here.parents]:
        for cand in (parent / "reliability-commons", parent.parent / "reliability-commons"):
            if cand.is_dir():
                return cand
    raise RuntimeError(
        "Set COMMONS_ROOT to the reliability-commons checkout (or place it as a sibling of this repo)."
    )

def _portal_repo_root():
    from pathlib import Path
    here = Path(__file__).resolve().parent
    for p in [here, *here.parents]:
        if (p / ".git").exists() or (p / "pyproject.toml").exists() or (p / "README.md").exists():
            return p
    return here

def _data_root():
    import os
    from pathlib import Path
    return Path(os.environ.get("DATA_ROOT", Path.home() / "data")).expanduser()

def _portfolio_root():
    """Parent of theme repos when laid out as a portfolio sibling tree."""
    from pathlib import Path
    r = _portal_repo_root()
    parent = r.parent
    markers = ("reliability-commons", "inspect-gate", "materials-mlip-research", "asr-gate")
    if any((parent / m).exists() for m in markers):
        return parent
    return parent

def _autodl_tmp():
    import os
    from pathlib import Path
    return Path(os.environ.get("AUTODL_TMP", "/tmp/autodl-tmp"))

def _conda_root():
    import os
    from pathlib import Path
    return Path(os.environ.get("CONDA_ROOT", Path.home() / "miniconda3")).expanduser()

GEO = _portal_repo_root()
IG_STYLE = _portal_commons_root() / "tools" / "inspect-gate" / "figures_2026-07-19"
sys.path.insert(0, str(IG_STYLE))
import figstyle

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import shapefile  # pyshp

figstyle.apply()

SHP = str(_conda_root() / "envs" / "dl" / "lib" / "python3.13" / "site-packages" / "pyogrio" / "tests" / "fixtures" / "naturalearth_lowres" / "naturalearth_lowres.shp")
MANIFEST = GEO / "results_expansion_2026-07-09" / "eurosat_spatial" / "manifest.csv"

m = pd.read_csv(MANIFEST)
P33 = float(m.lon.quantile(0.33))
P25, P50 = float(m.lon.quantile(0.25)), float(m.lon.quantile(0.50))
sub = m.sample(4000, random_state=0)
src = sub[sub.lon >= P33]
tgt = sub[sub.lon < P33]

fig, ax = plt.subplots(figsize=(figstyle.COL_WIDTH_IN, 3.6))

reader = shapefile.Reader(SHP)
for shape in reader.shapes():
    pts = np.array(shape.points)
    if len(pts) == 0:
        continue
    parts = list(shape.parts) + [len(pts)]
    for i in range(len(parts) - 1):
        seg = pts[parts[i]:parts[i + 1]]
        if len(seg) < 3:
            continue
        lon_min, lon_max = seg[:, 0].min(), seg[:, 0].max()
        lat_min, lat_max = seg[:, 1].min(), seg[:, 1].max()
        if lon_max < -25 or lon_min > 45 or lat_max < 30 or lat_min > 72:
            continue
        ax.fill(seg[:, 0], seg[:, 1], facecolor="#F2F2F2", edgecolor="#BBBBBB",
                lw=0.4, zorder=1)

ax.scatter(tgt.lon, tgt.lat, s=1.2, color=figstyle.C_BASE, alpha=0.45, lw=0,
           zorder=2, label=f"target (lon $<$ P33), n={len(m[m.lon < P33])}")
ax.scatter(src.lon, src.lat, s=1.2, color=figstyle.C_GATE, alpha=0.45, lw=0,
           zorder=3, label=f"source (lon $\\geq$ P33), n={len(m[m.lon >= P33])}")

for cut, ls, lab in ((P33, "--", "P33 (headline)"), (P25, ":", "P25"), (P50, ":", "P50")):
    ax.axvline(cut, color=figstyle.OI["black"], lw=1.0 if ls == "--" else 0.7,
               ls=ls, zorder=4)
ax.text(P33, 64.0, f"P33 = {P33:.1f}$^\\circ$E", fontsize=figstyle.FONT_ANNOT,
        ha="center", va="top")
ax.text(P25 - 0.4, 35.0, "P25", fontsize=figstyle.FONT_ANNOT - 0.5, ha="right", va="bottom", color="#555555")
ax.text(P50 + 0.4, 35.0, "P50", fontsize=figstyle.FONT_ANNOT - 0.5, ha="left", va="bottom", color="#555555")

ax.set_xlim(-12, 35)
ax.set_ylim(34, 66)
ax.set_xlabel("longitude ($^\\circ$E)")
ax.set_ylabel("latitude ($^\\circ$N)")
ax.spines[["top", "right"]].set_visible(False)
ax.legend(frameon=False, loc="lower right", markerscale=6, handletextpad=0.1,
          borderaxespad=0.2, fontsize=figstyle.FONT_TICK)

out = GEO / "manuscripts" / "figures" / "F8_geomap.pdf"
fig.savefig(out)
print(f"wrote {out}; P33={P33:.3f}; source={len(m[m.lon >= P33])} target={len(m[m.lon < P33])}")
