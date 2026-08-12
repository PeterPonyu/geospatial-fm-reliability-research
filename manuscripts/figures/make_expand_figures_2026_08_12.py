#!/usr/bin/env python3
"""Expand GEO ISPRS figures from frozen JSON only (2026-08-12).

Produces:
  F11_conditional_coverage.pdf
  F12_singleton_lowshot.pdf
  F13_crc_fnr.pdf
  F14_classprior.pdf
into manuscripts/figures/. No new experiments.
"""
from __future__ import annotations

import json
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
ART = Path(
    "/home/zeyufu/Desktop/ml-reliability-research/.omc/artifacts/"
    "visual-ralph/geo-rotcert-expand/geo"
)
ART.mkdir(parents=True, exist_ok=True)

BLACK = "#000000"
OI = {
    "prithvi": "#009E73",
    "Prithvi": "#009E73",
    "clay": "#0072B2",
    "Clay": "#0072B2",
    "ssl4eo": "#D55E00",
    "ssl4eo_dino": "#D55E00",
    "SSL4EO-DINO": "#D55E00",
    "ssl4eo_mae": "#CC79A7",
    "SSL4EO-MAE": "#CC79A7",
    "dofa": "#E69F00",
    "DOFA": "#E69F00",
}
LABEL = {
    "prithvi": "Prithvi",
    "clay": "Clay",
    "ssl4eo": "SSL4EO-DINO",
    "ssl4eo_dino": "SSL4EO-DINO",
    "ssl4eo_mae": "SSL4EO-MAE",
    "dofa": "DOFA",
}


def _style():
    plt.rcParams.update(
        {
            "font.size": 8,
            "axes.titlesize": 8,
            "axes.labelsize": 8,
            "xtick.labelsize": 7,
            "ytick.labelsize": 7,
            "legend.fontsize": 7,
            "axes.edgecolor": BLACK,
            "axes.labelcolor": BLACK,
            "xtick.color": BLACK,
            "ytick.color": BLACK,
            "text.color": BLACK,
            "figure.facecolor": "white",
            "axes.facecolor": "white",
            "savefig.facecolor": "white",
        }
    )


def _tag(ax, letter: str):
    """Uppercase panel letter outside the spines (upper-left of axes)."""
    letter = str(letter).upper()
    ax.text(
        -0.14,
        1.06,
        letter,
        transform=ax.transAxes,
        fontweight="bold",
        fontsize=12,
        va="bottom",
        ha="right",
        color=BLACK,
        clip_on=False,
    )


def _save(fig, stem: str):
    pdf = OUT / f"{stem}.pdf"
    png = ART / f"{stem}.png"
    fig.savefig(pdf, bbox_inches="tight")
    fig.savefig(png, dpi=200, bbox_inches="tight")
    plt.close(fig)
    print(f"wrote {pdf} ({pdf.stat().st_size} B)")


def _load(p: Path):
    return json.loads(p.read_text())


def _color(name: str) -> str:
    return OI.get(name, OI.get(name.lower(), "#000000"))


def fig_condcov():
    """Match R expand F11: EuroSAT gaps / SSL4EO-DINO per-class /
    So2Sat marginal-vs-worst / gap-vs-spread scatter."""
    exp0 = _load(ROOT / "exp0_2026-07-13/results.json")
    tb = exp0["test_B_eurosat_conditional_coverage"]["per_alpha"]["0.05"]
    so2 = _load(ROOT / "so2sat_roster_stage_2026-07-13/perclass_conditional_summary.json")

    fig, axes = plt.subplots(2, 2, figsize=(4.75, 3.85), constrained_layout=True)

    # A: worst-class gap by encoder (sorted ascending)
    ax = axes[0, 0]
    encs = sorted(
        tb["per_encoder"].keys(),
        key=lambda e: tb["per_encoder"][e]["worst_class_gap"],
    )
    gaps = [tb["per_encoder"][e]["worst_class_gap"] for e in encs]
    cols = [_color(e) for e in encs]
    ax.bar(range(len(encs)), gaps, color=cols, edgecolor="0.3", linewidth=0.4)
    ax.axhline(0, color="0.4", lw=0.6)
    ax.set_xticks(range(len(encs)))
    ax.set_xticklabels([LABEL.get(e, e) for e in encs], rotation=25, ha="right")
    ax.set_ylabel("worst-class gap")
    _tag(ax, "A")

    # B: per-class coverage for SSL4EO-DINO (smoking-gun in tab:condcov)
    ax = axes[0, 1]
    ssl = tb["per_encoder"]["ssl4eo"]
    pc = ssl["per_class_cov"]
    xs = sorted(pc.keys(), key=lambda k: int(k))
    vals = [pc[k] for k in xs]
    ax.bar(range(len(xs)), vals, color=_color("ssl4eo"), edgecolor="0.3", linewidth=0.4)
    ax.axhline(ssl["marg_cov"], color=BLACK, ls="--", lw=0.8)
    ax.axhline(0.95, color="#666666", ls=":", lw=0.8)
    ax.set_xticks(range(len(xs)))
    ax.set_xticklabels(xs)
    ax.set_xlabel("EuroSAT class id")
    ax.set_ylabel("per-class cov")
    ax.set_ylim(0.80, 1.0)
    _tag(ax, "B")

    # C: So2Sat marginal vs worst-class coverage (dodged bars)
    ax = axes[1, 0]
    pe = so2["per_encoder"]
    order = ["prithvi", "clay", "ssl4eo_dino", "ssl4eo_mae", "dofa"]
    # tolerate key variants in frozen JSON
    key_map = {}
    for k in pe:
        lab = LABEL.get(k, k)
        key_map[lab] = k
    labs_c = ["Prithvi", "Clay", "SSL4EO-DINO", "SSL4EO-MAE", "DOFA"]
    keys_c = []
    for lab in labs_c:
        if lab in key_map:
            keys_c.append(key_map[lab])
        else:
            # fallback short keys
            for cand in order:
                if LABEL.get(cand) == lab and cand in pe:
                    keys_c.append(cand)
                    break
    xs = np.arange(len(keys_c))
    w = 0.35
    marg = [pe[k]["marginal_cov"] for k in keys_c]
    worst = [pe[k]["worst_class_cov"] for k in keys_c]
    ax.bar(xs - w / 2, marg, w, color="#0072B2", edgecolor="0.3", linewidth=0.3, label="marginal")
    ax.bar(xs + w / 2, worst, w, color="#E69F00", edgecolor="0.3", linewidth=0.3, label="worst class")
    ax.axhline(0.95, color="#666666", ls=":", lw=0.8)
    ax.set_xticks(xs)
    ax.set_xticklabels([LABEL.get(k, k) for k in keys_c], rotation=25, ha="right")
    ax.set_ylabel("So2Sat coverage")
    ax.set_ylim(0.65, 1.0)
    ax.legend(frameon=False, loc="lower center", ncol=1, fontsize=7, bbox_to_anchor=(0.5, -0.02))
    _tag(ax, "C")

    # D: EuroSAT worst-class gap vs So2Sat class spread
    ax = axes[1, 1]
    for e in encs:
        # map eurosat encoder key to so2 key
        so2_key = e
        if e not in pe:
            for k, lab in ((k, LABEL.get(k, k)) for k in pe):
                if lab == LABEL.get(e, e):
                    so2_key = k
                    break
        if so2_key not in pe:
            continue
        x = tb["per_encoder"][e]["worst_class_gap"]
        y = pe[so2_key]["class_spread"]
        ax.scatter(x, y, s=36, color=_color(e), zorder=3)
        ax.annotate(
            LABEL.get(e, e),
            (x, y),
            fontsize=7,
            textcoords="offset points",
            xytext=(4, 4),
            color=BLACK,
        )
    ax.set_xlabel("EuroSAT worst-class gap")
    ax.set_ylabel("So2Sat class spread")
    _tag(ax, "D")

    _save(fig, "F11_conditional_coverage")


def fig_singleton():
    """Mirror R shipper: Prithvi A–C @ α=0.05; multi-encoder D with in-panel legend."""
    ls = _load(ROOT / "exp0_2026-07-13/lowshot_results.json")
    fig, axes = plt.subplots(2, 2, figsize=(4.85, 3.15), constrained_layout=True)
    major = [0.01, 0.05, 0.25, 1.0]
    major_lab = ["0.01", "0.05", "0.25", "1"]

    def _logx(ax):
        ax.set_xscale("log")
        ax.set_xticks(major)
        ax.set_xticklabels(major_lab)
        ax.set_xticks([0.02, 0.1, 0.5], minor=True)
        ax.tick_params(axis="x", which="minor", labelbottom=False)

    # A–C: Prithvi @ α=0.05 (matches tab:singleton)
    p05 = sorted(ls["encoders"]["prithvi"]["0.05"], key=lambda r: r["frac"])
    fr = [r["frac"] for r in p05]
    col = _color("prithvi")

    ax = axes[0, 0]
    ax.axhline(0, color="#7f7f7f", lw=0.8)
    ax.plot(fr, [r["cov_minus_acc"] for r in p05], "-o", color=col, ms=4, lw=1.0)
    _logx(ax)
    ax.set_xlabel("probe-train fraction")
    ax.set_ylabel("coverage − accuracy")
    _tag(ax, "A")

    ax = axes[0, 1]
    ax.axhline(1, color="#666666", ls=":", lw=0.9)
    ax.plot(fr, [r["ss_sh"] for r in p05], "-o", color=col, ms=4, lw=1.0)
    _logx(ax)
    ax.set_xlabel("probe-train fraction")
    ax.set_ylabel("split set size")
    _tag(ax, "B")

    ax = axes[1, 0]
    ax.plot(fr, [r["worst_gap"] for r in p05], "-o", color=col, ms=4, lw=1.0)
    _logx(ax)
    ax.set_xlabel("probe-train fraction")
    ax.set_ylabel("worst-class gap")
    _tag(ax, "C")

    # D: all encoders; solid α=0.05, dotted α=0.10; tight in-panel legend
    ax = axes[1, 1]
    ax.axhline(0, color="#7f7f7f", lw=0.8)
    for e, rec in ls["encoders"].items():
        for a, ls_style in (("0.05", "-"), ("0.10", ":")):
            series = sorted(rec[a], key=lambda r: r["frac"])
            ax.plot(
                [r["frac"] for r in series],
                [r["cov_minus_acc"] for r in series],
                ls_style + "o",
                color=_color(e),
                ms=3,
                lw=0.9,
                label=LABEL.get(e, e) if a == "0.05" else None,
            )
    # Synthetic α linestyle handles (match R in-panel key).
    ax.plot([], [], "-", color="black", lw=1.0, label="α=0.05")
    ax.plot([], [], ":", color="black", lw=1.0, label="α=0.1")
    _logx(ax)
    ax.set_xlabel("probe-train fraction")
    ax.set_ylabel("coverage − accuracy")
    ax.legend(frameon=False, loc="upper right", fontsize=6, ncol=1)
    _tag(ax, "D")

    _save(fig, "F12_singleton_lowshot")


def fig_crc():
    """Match R F13: equal 2×2; A@0.05 in/shift; B/C Mondrian@0.10; D α-sweep.

    Canonical renderer is make_expand_figures_2026_08_12.R; keep this in sync.
    """
    crc = _load(ROOT / "experiments/results/bigearthnet_crc_arm-exec-2026-06-29.json")
    fms = list(crc["fm_results"].keys())
    tick = [LABEL.get(f, f).replace("SSL4EO-", "") for f in fms]
    xs = np.arange(len(fms))
    w = 0.36
    fill_regime = {"in-dist": "#0072B2", "shift": "#D55E00"}
    fill_method = {"CRC": "#0072B2", "Mondrian-CRC": "#009E73"}

    def _boot(fm: str, a: str, key: str):
        b = crc["fm_results"][fm]["per_alpha"][a]["bootstrap"][key]
        return float(b["mean"]), float(b["ci_low"]), float(b["ci_high"])

    fig, axes = plt.subplots(2, 2, figsize=(5.8, 4.35), constrained_layout=True)

    # A: CRC in-dist vs shift @ α=0.05
    ax = axes[0, 0]
    yin, yish, ein_lo, ein_hi, esh_lo, esh_hi = [], [], [], [], [], []
    for fm in fms:
        m, lo, hi = _boot(fm, "0.05", "fnr_in_crc")
        yin.append(m)
        ein_lo.append(m - lo)
        ein_hi.append(hi - m)
        m, lo, hi = _boot(fm, "0.05", "fnr_sh_crc")
        yish.append(m)
        esh_lo.append(m - lo)
        esh_hi.append(hi - m)
    ax.bar(xs - w / 2, yin, w, color=fill_regime["in-dist"], label="in-dist",
           yerr=np.vstack([ein_lo, ein_hi]), capsize=1.5, error_kw={"lw": 0.6})
    ax.bar(xs + w / 2, yish, w, color=fill_regime["shift"], label="shift",
           yerr=np.vstack([esh_lo, esh_hi]), capsize=1.5, error_kw={"lw": 0.6})
    ax.axhline(0.05, color=BLACK, ls="--", lw=0.7)
    ax.set_xticks(xs)
    ax.set_xticklabels(tick, rotation=30, ha="right")
    ax.set_ylabel("FNR")
    _tag(ax, "A")

    # B: CRC vs Mondrian-CRC shift FNR @ α=0.10
    ax = axes[0, 1]
    ycrc, ymond, ecrc_lo, ecrc_hi, em_lo, em_hi = [], [], [], [], [], []
    for fm in fms:
        m, lo, hi = _boot(fm, "0.10", "fnr_sh_crc")
        ycrc.append(m)
        ecrc_lo.append(m - lo)
        ecrc_hi.append(hi - m)
        m, lo, hi = _boot(fm, "0.10", "fnr_sh_mond")
        ymond.append(m)
        em_lo.append(m - lo)
        em_hi.append(hi - m)
    ax.bar(xs - w / 2, ycrc, w, color=fill_method["CRC"], label="CRC",
           yerr=np.vstack([ecrc_lo, ecrc_hi]), capsize=1.5, error_kw={"lw": 0.6})
    ax.bar(xs + w / 2, ymond, w, color=fill_method["Mondrian-CRC"], label="Mondrian-CRC",
           yerr=np.vstack([em_lo, em_hi]), capsize=1.5, error_kw={"lw": 0.6})
    ax.axhline(0.10, color=BLACK, ls="--", lw=0.7)
    ax.set_xticks(xs)
    ax.set_xticklabels(tick, rotation=30, ha="right")
    ax.set_ylabel("FNR")
    _tag(ax, "B")

    # C: set size CRC vs Mondrian @ α=0.10 (no per-panel legend; shared below)
    ax = axes[1, 0]
    ysc, ysm, esc_lo, esc_hi, esm_lo, esm_hi = [], [], [], [], [], []
    for fm in fms:
        m, lo, hi = _boot(fm, "0.10", "ss_sh_crc")
        ysc.append(m)
        esc_lo.append(m - lo)
        esc_hi.append(hi - m)
        m, lo, hi = _boot(fm, "0.10", "ss_sh_mond")
        ysm.append(m)
        esm_lo.append(m - lo)
        esm_hi.append(hi - m)
    ax.bar(xs - w / 2, ysc, w, color=fill_method["CRC"],
           yerr=np.vstack([esc_lo, esc_hi]), capsize=1.5, error_kw={"lw": 0.6})
    ax.bar(xs + w / 2, ysm, w, color=fill_method["Mondrian-CRC"],
           yerr=np.vstack([esm_lo, esm_hi]), capsize=1.5, error_kw={"lw": 0.6})
    ax.set_xticks(xs)
    ax.set_xticklabels(tick, rotation=30, ha="right")
    ax.set_ylabel("Set size")
    _tag(ax, "C")

    # D: CRC shift FNR across α by encoder
    ax = axes[1, 1]
    alphas = sorted(
        {a for fm in fms for a in crc["fm_results"][fm]["per_alpha"]},
        key=float,
    )
    for a in alphas:
        ax.axhline(float(a), color="#888888", ls=":", lw=0.6)
    for fm in fms:
        ys, lo_e, hi_e = [], [], []
        for a in alphas:
            m, lo, hi = _boot(fm, a, "fnr_sh_crc")
            ys.append(m)
            lo_e.append(m - lo)
            hi_e.append(hi - m)
        xa = [float(a) for a in alphas]
        ax.errorbar(
            xa, ys, yerr=np.vstack([lo_e, hi_e]),
            color=_color(fm), label=LABEL.get(fm, fm).replace("SSL4EO-", ""),
            fmt="-o", ms=3.5, lw=0.9, capsize=1.5, elinewidth=0.6,
        )
    ax.set_xlabel(r"$\alpha$", labelpad=1)
    ax.set_ylabel("FNR")
    ax.set_xticks([float(a) for a in alphas])
    _tag(ax, "D")

    # Figure-level legends once: A regime, B/C method, D encoders
    h_a, l_a = axes[0, 0].get_legend_handles_labels()
    h_b, l_b = axes[0, 1].get_legend_handles_labels()
    h_d, l_d = axes[1, 1].get_legend_handles_labels()
    fig.legend(h_a + h_b, l_a + l_b, loc="lower left", bbox_to_anchor=(0.02, -0.08),
               frameon=False, ncol=4, fontsize=7, title=None)
    fig.legend(h_d, l_d, loc="lower right", bbox_to_anchor=(0.98, -0.08),
               frameon=False, ncol=5, fontsize=7, title=None)
    for ax in axes.ravel():
        leg = ax.get_legend()
        if leg is not None:
            leg.remove()

    _save(fig, "F13_crc_fnr")


def fig_classprior():
    """Mirror R F14: prior ratio + tabled freqs + ECE/#α restored control.

    Panel D is ``#α restored`` (tab:balanced), not Mondrian coverage.
    Prefer regenerating via make_expand_figures_2026_08_12.R F14.
    """
    cp = _load(
        ROOT
        / "experiments/results/eurosat_stage2_multifm_multialpha/recompute_class_prior_balanced_control_2026-07-01.json"
    )
    prior = cp["class_prior_shift_at_P33"]["per_class"]
    unb = cp["results"]["unbalanced"]
    bal = cp["results"].get("balanced") or cp["results"].get("class_balanced")
    if bal is None:
        for k in cp["results"]:
            if k != "unbalanced":
                bal = cp["results"][k]
                break
    if isinstance(unb, list):
        unb = {k: v for k, v in unb}
    if isinstance(bal, list):
        bal = {k: v for k, v in bal}

    highlight = {5, 2, 9, 8, 1}
    # sort A by ratio ascending (match R)
    prior_sorted = sorted(prior, key=lambda p: p["target_over_source_ratio"])
    fig, axes = plt.subplots(2, 2, figsize=(4.75, 3.85), constrained_layout=True)

    ax = axes[0, 0]
    xs = [str(p["class"]) for p in prior_sorted]
    ratios = [p["target_over_source_ratio"] for p in prior_sorted]
    colors = ["#D55E00" if p["class"] in highlight else "#BFBFBF" for p in prior_sorted]
    ax.bar(xs, ratios, color=colors, edgecolor="grey30", linewidth=0.3)
    ax.axhline(1.0, color="grey35", ls="--", lw=0.8)
    ax.set_xlabel("class id")
    ax.set_ylabel("prior ratio")
    _tag(ax, "A")

    ax = axes[0, 1]
    order = [5, 2, 9, 8, 1]
    by_c = {p["class"]: p for p in prior}
    xpos = np.arange(len(order))
    w = 0.35
    src = [by_c[c]["source_pct"] for c in order]
    tgt = [by_c[c]["target_pct"] for c in order]
    ax.bar(xpos - w / 2, src, w, color="#0072B2", label="source",
           edgecolor="grey30", linewidth=0.3)
    ax.bar(xpos + w / 2, tgt, w, color="#E69F00", label="target",
           edgecolor="grey30", linewidth=0.3)
    ax.set_xticks(xpos)
    ax.set_xticklabels([str(c) for c in order])
    ax.set_xlabel("class id (tabled)")
    ax.set_ylabel("frequency (%)")
    _tag(ax, "B")

    fm_order = ["prithvi", "ssl4eo_dino", "ssl4eo_mae", "clay"]
    fm_tick = {"prithvi": "Prithvi", "ssl4eo_dino": "DINO",
               "ssl4eo_mae": "MAE", "clay": "Clay"}
    fms = [f for f in fm_order if f in unb]

    ax = axes[1, 0]
    xpos = np.arange(len(fms))
    w = 0.35
    u_ece, u_lo, u_hi, b_ece, b_lo, b_hi = [], [], [], [], [], []
    for f in fms:
        u = unb[f]["per_alpha"]["0.05"]["ece_shift"]
        b = bal[f]["per_alpha"]["0.05"]["ece_shift"]
        u_ece.append(u["mean"]); u_lo.append(u["ci_low"]); u_hi.append(u["ci_high"])
        b_ece.append(b["mean"]); b_lo.append(b["ci_low"]); b_hi.append(b["ci_high"])
    ax.bar(xpos - w / 2, u_ece, w, color="#0072B2", label="unadjusted",
           edgecolor="grey30", linewidth=0.3,
           yerr=np.vstack([np.array(u_ece) - np.array(u_lo),
                           np.array(u_hi) - np.array(u_ece)]),
           capsize=1.5, error_kw={"lw": 0.6})
    ax.bar(xpos + w / 2, b_ece, w, color="#E69F00", label="balanced",
           edgecolor="grey30", linewidth=0.3,
           yerr=np.vstack([np.array(b_ece) - np.array(b_lo),
                           np.array(b_hi) - np.array(b_ece)]),
           capsize=1.5, error_kw={"lw": 0.6})
    ax.set_xticks(xpos)
    ax.set_xticklabels([fm_tick[f] for f in fms], rotation=25, ha="right")
    ax.set_ylabel("shift ECE")
    _tag(ax, "C")

    ax = axes[1, 1]
    def n_restored(blk):
        return sum(
            1 for c in blk["per_alpha"].values()
            if c.get("mondrian_restores_CI_excludes_0") is True
        )
    u_n = [n_restored(unb[f]) for f in fms]
    b_n = [n_restored(bal[f]) for f in fms]
    ax.bar(xpos - w / 2, u_n, w, color="#0072B2", edgecolor="grey30", linewidth=0.3)
    ax.bar(xpos + w / 2, b_n, w, color="#E69F00", edgecolor="grey30", linewidth=0.3)
    ax.set_xticks(xpos)
    ax.set_xticklabels([fm_tick[f] for f in fms], rotation=25, ha="right")
    ax.set_ylabel(r"#$\alpha$ restored")
    ax.set_yticks([0, 1, 2, 3])
    ax.set_ylim(0, 3.2)
    _tag(ax, "D")

    h_b, l_b = axes[0, 1].get_legend_handles_labels()
    h_c, l_c = axes[1, 0].get_legend_handles_labels()
    fig.legend(h_b + h_c, l_b + l_c, loc="lower center", bbox_to_anchor=(0.5, -0.02),
               frameon=False, ncol=4, fontsize=7)
    for a in axes.ravel():
        leg = a.get_legend()
        if leg is not None:
            leg.remove()

    _save(fig, "F14_classprior")


def main():
    _style()
    fig_condcov()
    fig_singleton()
    fig_crc()
    fig_classprior()
    print("done")


if __name__ == "__main__":
    main()
