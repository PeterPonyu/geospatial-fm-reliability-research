# P3 geospatial — all statistical figures from the REAL 5-FM result JSON (no hardcoded numbers).
# Kit pattern (reliability-commons/paper-template): run from manuscripts/ via `make figures`.
# Run: cd manuscripts && Rscript figures/p3_figs.R
# Optional: Rscript figures/p3_figs.R F2   # regenerate one figure only (F1/F2/F3)
#
# Figure input (2026-07-13): the five-encoder merged file. It is a deep-merged copy of the
# four battery encoders from the PROTECTED canonical results.json (Prithvi/Clay/SSL4EO-DINO/
# SSL4EO-MAE, byte-equivalent) PLUS the corrected DOFA fifth-encoder block (forward_features
# 768-d fix, re-run 2026-07-13). The canonical results.json is never modified; the merged file
# is a separate on-disk figure input under experiments/results/. Override with FIVEFM_RESULTS.
source("figures/ggtheme.R")  # vendored copy (formerly sourced from the manuscript-template repo)
args <- commandArgs(trailingOnly = TRUE)
ONLY <- if (length(args) >= 1L) toupper(sub("^F?", "F", args[[1]])) else ""
do_fig <- function(stem) ONLY == "" || identical(ONLY, stem)

# Compact 2×2 typography (matches expand F11–F14): tags largest; axes/legends 7–8 pt.
theme_p3_panel <- function() {
  theme_paper(base_size = 9) +
    theme(
      axis.title = element_text(size = 8),
      axis.text  = element_text(size = 7),
      legend.text = element_text(size = 7),
      legend.title = element_blank(),
      strip.text = element_text(size = 8),
      axis.title.x = element_text(margin = margin(t = 2)),
      axis.title.y = element_text(margin = margin(r = 2))
    )
}
tag_p3 <- function() paper_tag_theme(base_size = 13)
RES <- Sys.getenv("FIVEFM_RESULTS",
  "../experiments/results/eurosat_stage2_multifm_multialpha/results_fivefm_figures_2026-07-13.json")
d <- read_result(RES)
fms <- names(d$fm_results)
alphas <- names(d$fm_results[[fms[[1]]]])   # use the JSON's actual alpha keys
# 5-FM label map (ssl4eo_mae = same data as ssl4eo, MAE objective vs DINO, ViT-B vs ViT-S;
# dofa = corrected 5th EuroSAT-grid encoder, forward_features 768-d embedding, re-run 2026-07-13)
fm_lab <- c(prithvi    = "Prithvi-EO-2.0",
            ssl4eo     = "SSL4EO-S12 (DINO)",
            ssl4eo_mae = "SSL4EO-S12 (MAE)",
            clay       = "Clay v1.5",
            dofa       = "DOFA")

getm <- function(x) if (is.null(x)) NA_real_ else as.numeric(x$mean)
# CI accessors: every real_shift coverage/set-size block in the frozen JSON carries
# an n=5 seed-level {ci_low, ci_high}; the figures previously discarded these and
# plotted bare point estimates. Surface them as error bars so the figures carry the
# same uncertainty richness the expanded tables report (2026-07-16 fig-content pass).
getlo <- function(x) if (is.null(x)) NA_real_ else as.numeric(x$ci_low)
gethi <- function(x) if (is.null(x)) NA_real_ else as.numeric(x$ci_high)
rows <- list()
for (fm in fms) for (a in alphas) {
  c0 <- d$fm_results[[fm]][[a]]$cell
  rs <- c0$real_shift
  rest <- c0$restoration
  ci_low <- tryCatch(as.numeric(rest$paired_gap_diff_split_minus_mondrian$ci_low), error=function(e) NA)
  lab <- if (!is.null(fm_lab[[fm]])) fm_lab[[fm]] else fm   # fallback to raw key
  rows[[length(rows)+1]] <- data.frame(
    fm = lab,
    alpha = as.numeric(a),
    nominal = 1 - as.numeric(a),
    ece_in = getm(c0$ece$in_dist),
    ece_shift = getm(c0$ece$real_shift),
    acc_shift = getm(c0$accuracy$real_shift),
    split_cov = getm(rs$conformal_split$coverage),
    split_cov_lo = getlo(rs$conformal_split$coverage),
    split_cov_hi = gethi(rs$conformal_split$coverage),
    mond_cov = getm(rs$conformal_spatial_mondrian$coverage),
    mond_cov_lo = getlo(rs$conformal_spatial_mondrian$coverage),
    mond_cov_hi = gethi(rs$conformal_spatial_mondrian$coverage),
    mond_size = getm(rs$conformal_spatial_mondrian$set_size),
    mond_size_lo = getlo(rs$conformal_spatial_mondrian$set_size),
    mond_size_hi = gethi(rs$conformal_spatial_mondrian$set_size),
    # split set size + CI: needed by F3-B, which draws the split series
    # explicitly instead of asserting it via the dotted singleton line.
    split_size = getm(rs$conformal_split$set_size),
    split_size_lo = getlo(rs$conformal_split$set_size),
    split_size_hi = gethi(rs$conformal_split$set_size),
    restored = isTRUE(!is.na(ci_low) && ci_low > 0),
    stringsAsFactors = FALSE)
}
df <- do.call(rbind, rows)

# F1: debt-vs-robustness — per-FM shift ECE vs number of alphas restored.
# Compute debt summary BEFORE setting factor levels so we can order by ECE.
deb <- do.call(rbind, lapply(
  split(df, df$fm),
  function(g) data.frame(fm = g$fm[1], debt = mean(g$ece_shift, na.rm=TRUE),
                         n_restored = sum(g$restored, na.rm=TRUE))))
deb <- deb[order(deb$debt), ]   # ascending debt: Clay < ssl4eo_mae < ssl4eo < Prithvi

# Set fm factor levels ordered by debt (low→high) so F1 line is monotone left→right
df$fm  <- factor(df$fm,  levels = deb$fm)
deb$fm <- factor(deb$fm, levels = deb$fm)
write.csv(df, "figures/p3_table.csv", row.names = FALSE)

# Long descriptive title moved to the LaTeX \caption; plot carries a short bold corner tag only.
# ggrepel resolves the low-debt left-cluster label overlap (Clay / SSL4EO-MAE / SSL4EO-DINO).
# ---------------------------------------------------------------------------
# Additional frozen sources for the 4-panel expansion (2026-08-01).
# Each is a separate on-disk frozen record; none is modified here.
# NOTE the three restoration schemas are NOT interchangeable:
#   5FM merged    : restoration$paired_gap_diff_split_minus_mondrian$ci_low
#   boundary sweep: restoration$split_minus_mondrian$ci_excludes_0_positive
#   so2sat        : restoration$target_global_restores_CI_excludes_0
# Reading one with another's key yields a silent NA, so each has its own accessor.
# ---------------------------------------------------------------------------
BSWEEP <- Sys.getenv("BSWEEP_RESULTS", "../experiments/results/eurosat_boundary_sweep/results.json")
SO2SAT <- Sys.getenv("SO2SAT_RESULTS", "../experiments/results/so2sat_coverage_debt/results.json")
BASE5  <- Sys.getenv("BASELINES_RESULTS", "../experiments/results/eurosat_conformal_baselines/results.json")
LSHIFT <- Sys.getenv("LABELSHIFT_RESULTS", "../experiments/results/labelshift_adjusted_baseline/results.json")

# Several frozen records are named plain "results.json" and differ only by
# directory, so the provenance line carries <parent>/<file>, not basename().
src_id <- function(path) {
  p <- normalizePath(path, mustWork = FALSE)
  file.path(basename(dirname(p)), basename(p))
}
prov <- function(tag, path, dfx, series_col) {
  cat(sprintf("[%s] source=%s rows=%d series=%d\n", tag, src_id(path),
              nrow(dfx), length(unique(dfx[[series_col]]))))
}
lab_of <- function(fm) if (!is.null(fm_lab[[fm]])) fm_lab[[fm]] else fm

# Dense panels (5 facets in a row, or a legend beside a narrow half-width panel)
# cannot fit the full encoder names -- at this render width they truncate
# mid-word ("SSL4EO-S12 (DIN", "SL4EO-S12 (MA"). Those panels use these short
# forms; panel A keeps the full names, which it has room for because it labels
# points directly. Order matches fm_lab.
fm_short <- c("Prithvi-EO-2.0" = "Prithvi",
              "SSL4EO-S12 (DINO)" = "SSL4EO-DINO",
              "SSL4EO-S12 (MAE)"  = "SSL4EO-MAE",
              "Clay v1.5" = "Clay",
              "DOFA" = "DOFA")
shorten_fm <- function(x) {
  out <- unname(fm_short[as.character(x)])
  ifelse(is.na(out), as.character(x), out)   # unmapped names pass through
}

# --- boundary sweep: coverage/set-size/restored across P25..P50 ---
bs <- read_result(BSWEEP)
bs_rows <- list()
for (fm in names(bs$fm_results)) {
  bnames <- names(bs$fm_results[[fm]]$boundaries)
  for (b in bnames) {
    cells <- bs$fm_results[[fm]]$boundaries[[b]]$cells
    for (a in names(cells)) {
      c0 <- cells[[a]]; rs <- c0$real_shift
      rest <- c0$restoration$split_minus_mondrian   # schema 2
      bs_rows[[length(bs_rows)+1]] <- data.frame(
        fm = lab_of(fm), boundary = b, alpha = as.numeric(a), nominal = 1-as.numeric(a),
        split_cov = getm(rs$conformal_split$coverage),
        split_cov_lo = getlo(rs$conformal_split$coverage),
        split_cov_hi = gethi(rs$conformal_split$coverage),
        mond_cov = getm(rs$conformal_spatial_mondrian$coverage),
        mond_cov_lo = getlo(rs$conformal_spatial_mondrian$coverage),
        mond_cov_hi = gethi(rs$conformal_spatial_mondrian$coverage),
        split_size = getm(rs$conformal_split$set_size),
        mond_size = getm(rs$conformal_spatial_mondrian$set_size),
        mond_size_lo = getlo(rs$conformal_spatial_mondrian$set_size),
        mond_size_hi = gethi(rs$conformal_spatial_mondrian$set_size),
        restored = isTRUE(rest$ci_excludes_0_positive),
        stringsAsFactors = FALSE)
    }
  }
}
bsdf <- do.call(rbind, bs_rows)

# --- so2sat: cross-continent LCZ replication (split vs target_global only) ---
s2 <- read_result(SO2SAT)
s2_rows <- list()
for (fm in names(s2$fm_results)) {
  cells <- s2$fm_results[[fm]]$cells
  for (a in names(cells)) {
    c0 <- cells[[a]]
    s2_rows[[length(s2_rows)+1]] <- data.frame(
      fm = lab_of(fm), alpha = as.numeric(a), nominal = 1-as.numeric(a),
      split_cov = getm(c0$conformal_split$coverage),
      split_cov_lo = getlo(c0$conformal_split$coverage),
      split_cov_hi = gethi(c0$conformal_split$coverage),
      tg_cov = getm(c0$conformal_target_global$coverage),
      tg_cov_lo = getlo(c0$conformal_target_global$coverage),
      tg_cov_hi = gethi(c0$conformal_target_global$coverage),
      split_size = getm(c0$conformal_split$set_size),
      split_size_lo = getlo(c0$conformal_split$set_size),
      split_size_hi = gethi(c0$conformal_split$set_size),
      tg_size = getm(c0$conformal_target_global$set_size),
      tg_size_lo = getlo(c0$conformal_target_global$set_size),
      tg_size_hi = gethi(c0$conformal_target_global$set_size),
      restored = isTRUE(c0$restoration$target_global_restores_CI_excludes_0),  # schema 3
      stringsAsFactors = FALSE)
  }
}
s2df <- do.call(rbind, s2_rows)

# --- multi-arm coverage: shared reader for the 5-arm and label-shift records ---
read_arms <- function(path, arms, arm_labels) {
  dd <- read_result(path); out <- list()
  for (fm in names(dd$fm_results)) {
    cells <- dd$fm_results[[fm]]$cells
    for (a in names(cells)) {
      rs <- cells[[a]]$real_shift
      for (i in seq_along(arms)) {
        blk <- rs[[arms[[i]]]]
        if (is.null(blk)) { cat(sprintf("[WARN] %s: %s/%s missing arm %s, dropped\n",
                                        basename(path), fm, a, arms[[i]])); next }
        out[[length(out)+1]] <- data.frame(
          fm = lab_of(fm), alpha = as.numeric(a), nominal = 1-as.numeric(a),
          arm = arm_labels[[i]], coverage = getm(blk$coverage),
          ci_low = getlo(blk$coverage), ci_high = gethi(blk$coverage),
          stringsAsFactors = FALSE)
      }
    }
  }
  d2 <- do.call(rbind, out)
  d2$arm <- factor(d2$arm, levels = arm_labels)
  d2
}
arms5 <- read_arms(BASE5,
  c("conformal_split","conformal_target_global","conformal_spatial_mondrian",
    "conformal_weighted","conformal_class_mondrian"),
  c("split (source)","target-global","spatial-Mondrian","weighted","class-Mondrian"))
armsls <- read_arms(LSHIFT,
  c("conformal_split","conformal_target_global","conformal_weighted_covariate",
    "conformal_labelshift_oracle","conformal_labelshift_bbse"),
  c("split (source)","target-global","weighted covariate","label-shift oracle","label-shift BBSE"))

# ---------------------------------------------------------------------------
# F1: coverage-debt diagnostic (equal 2×2). Redesign 2026-08-12:
#   A — mean shift ECE vs #α restored; colour+legend only (no on-point names)
#   B — shifted top-1 accuracy vs α
#   C — boundary-sweep #α restored vs cut (battery encoders; DOFA unused)
#   D — So2Sat split vs target-global in ONE panel (colour=encoder, shape=arm)
# One shared encoder colour legend; D adds a small shape/linetype arm legend.
# ---------------------------------------------------------------------------
if (do_fig("F1")) {
# Debt-ordered short labels for A (left→right = low→high ECE)
deb_a <- deb
deb_a$fm <- factor(shorten_fm(deb_a$fm),
                   levels = shorten_fm(as.character(deb$fm)))

f1a <- ggplot(deb_a, aes(debt, n_restored, colour = fm)) +
  geom_line(aes(group = 1), colour = "grey60", linetype = 2, linewidth = 0.35) +
  geom_point(size = 2.8) +
  scale_color_model(name = NULL, drop = FALSE) +
  scale_x_continuous(breaks = scales::pretty_breaks(4)) +
  scale_y_continuous(breaks = 0:3, limits = c(0, 3.05)) +
  labs(x = "mean shift ECE", y = "# α restored") +
  guides(colour = guide_legend(nrow = 1, order = 1, override.aes = list(size = 2.4))) +
  theme_p3_panel() +
  theme(panel.grid.major.x = element_blank())
prov("F1-A", RES, deb_a, "fm")

# F1-B: shifted accuracy vs α (robustness axis paired with A's debt ranking).
# Colour legend suppressed — A's guide is the single shared A–D encoder key.
accdf <- data.frame(fm = shorten_fm(df$fm), alpha = df$alpha, acc = df$acc_shift,
                    stringsAsFactors = FALSE)
accdf$fm <- factor(accdf$fm, levels = levels(deb_a$fm))
f1b <- ggplot(accdf, aes(factor(alpha), acc, colour = fm, group = fm)) +
  geom_line(linewidth = 0.4) +
  geom_point(size = 2.0) +
  scale_color_model(name = NULL, drop = FALSE) +
  labs(x = "α", y = "shifted top-1 acc") +
  theme_p3_panel() +
  theme(panel.grid.major.x = element_blank(), legend.position = "none")
prov("F1-B", RES, accdf, "fm")

# F1-C: boundary sweep (DOFA absent from this frozen record; no series drawn).
nres <- aggregate(restored ~ fm + boundary, data = bsdf, FUN = sum)
names(nres)[3] <- "n_restored"
nres$fm <- factor(shorten_fm(nres$fm), levels = levels(deb_a$fm))
f1c <- ggplot(nres, aes(boundary, n_restored, colour = fm, group = fm)) +
  geom_line(linewidth = 0.4) +
  geom_point(size = 2.0) +
  scale_color_model(name = NULL, drop = FALSE) +
  scale_y_continuous(breaks = 0:3, limits = c(0, 3.05)) +
  labs(x = "boundary cut", y = "# α restored") +
  theme_p3_panel() +
  theme(panel.grid.major.x = element_blank(), legend.position = "none")
prov("F1-C", BSWEEP, nres, "fm")

# F1-D: So2Sat — two arm facets (readable); encoder colour matches A–C.
s2m <- rbind(
  data.frame(fm = s2df$fm, alpha = s2df$alpha, nominal = s2df$nominal,
             arm = "split (source)", coverage = s2df$split_cov,
             ci_low = s2df$split_cov_lo, ci_high = s2df$split_cov_hi),
  data.frame(fm = s2df$fm, alpha = s2df$alpha, nominal = s2df$nominal,
             arm = "target-global", coverage = s2df$tg_cov,
             ci_low = s2df$tg_cov_lo, ci_high = s2df$tg_cov_hi))
s2m$arm <- factor(s2m$arm, levels = c("split (source)", "target-global"))
s2m$fm <- factor(shorten_fm(s2m$fm), levels = levels(deb_a$fm))
s2m$alpha_x <- factor(sprintf("%.2f", s2m$alpha),
                      levels = sprintf("%.2f", sort(unique(s2m$alpha))))
f1d <- ggplot(s2m, aes(alpha_x, coverage, colour = fm, group = fm)) +
  geom_point(aes(y = nominal), shape = 95, size = 3.6, colour = "grey30",
             show.legend = FALSE) +
  geom_line(linewidth = 0.4) +
  geom_point(size = 1.8) +
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high), width = 0.12,
                linewidth = 0.25, show.legend = FALSE) +
  facet_wrap(~arm, nrow = 1) +
  scale_color_model(name = NULL, drop = FALSE) +
  coord_cartesian(ylim = c(0.60, 1.0)) +
  labs(x = "α", y = "So2Sat coverage") +
  theme_p3_panel() +
  theme(panel.grid.major.x = element_blank(),
        strip.text = element_text(size = 7.5),
        legend.position = "none")
prov("F1-D", SO2SAT, s2m, "fm")

# Equal 2×2. Only A exposes the encoder legend; guide_area holds it under the
# grid. Do NOT `& theme(legend.position="bottom")` — that re-enables B/C/D
# legends and duplicates the encoder key.
f1_all <- ((f1a | f1b) / (f1c | f1d) / guide_area()) +
  plot_layout(heights = c(1, 1, 0.14), guides = "collect") +
  plot_annotation(tag_levels = "A") &
  paper_tag_theme(base_size = 13)
save_fig(f1_all, "figures/F1_debt_vs_robustness", w = 5.6, h = 4.35)

cat("[F1 verify] debt / restore counts:\n")
print(deb_a[, c("fm", "debt", "n_restored")])
}

# ---------------------------------------------------------------------------
# F2: coverage restoration (equal 2×2). Redesign 2026-08-12:
#   A — P33 split vs spatial-Mondrian bars; facet by α (not by encoder)
#   B — non-P33 boundaries as arm × boundary grid; colour = encoder
#   C/D — multi-arm contrasts at α=0.10; shared encoder colour legend
# One fig-level encoder legend; one arm fill legend; no in-panel legend boxes.
# ---------------------------------------------------------------------------
if (do_fig("F2")) {
arm_lv <- c("split (source)", "spatial-Mondrian")
# Full short names on the shared y-axis (facet_grid, not per-facet wrap).
fm_tick <- c("Prithvi" = "Prithvi",
             "SSL4EO-DINO" = "SSL4EO-DINO",
             "SSL4EO-MAE" = "SSL4EO-MAE",
             "Clay" = "Clay",
             "DOFA" = "DOFA")
m <- rbind(
  data.frame(fm = df$fm, alpha = df$alpha, nominal = df$nominal,
             arm = "split (source)", coverage = df$split_cov,
             ci_low = df$split_cov_lo, ci_high = df$split_cov_hi),
  data.frame(fm = df$fm, alpha = df$alpha, nominal = df$nominal,
             arm = "spatial-Mondrian", coverage = df$mond_cov,
             ci_low = df$mond_cov_lo, ci_high = df$mond_cov_hi))
m$arm <- factor(m$arm, levels = arm_lv)
m$fm  <- factor(shorten_fm(m$fm), levels = unname(fm_short))
m$alpha_lab <- factor(sprintf("α = %s", format(m$alpha, nsmall = 2)),
                      levels = sprintf("α = %s", format(sort(unique(m$alpha)), nsmall = 2)))

f2a <- ggplot(m, aes(coverage, fm, fill = arm)) +
  geom_col(position = position_dodge(0.72), width = 0.62, colour = NA) +
  geom_errorbar(aes(xmin = ci_low, xmax = ci_high),
                position = position_dodge(0.72), width = 0.18,
                linewidth = 0.3, colour = "grey25") +
  geom_vline(aes(xintercept = nominal), linetype = 2, colour = "grey35",
             linewidth = 0.35) +
  # Shared y-axis (one encoder column) — avoids truncated per-facet tick clones.
  facet_grid(. ~ alpha_lab) +
  scale_y_discrete(labels = fm_tick, limits = rev) +
  scale_fill_paper(name = NULL) +
  scale_x_continuous(breaks = c(0.80, 0.90, 1.00),
                     labels = c(".80", ".90", "1")) +
  coord_cartesian(xlim = c(0.78, 1.0)) +
  labs(x = "coverage", y = NULL) +
  guides(fill = guide_legend(nrow = 1, order = 1)) +
  theme_p3_panel() +
  theme(panel.grid.major.y = element_blank(),
        axis.text.y = element_text(size = 7),
        axis.text.x = element_text(size = 6.5),
        strip.text = element_text(size = 8))
prov("F2-A", RES, m, "fm")

# F2-B: same split-vs-Mondrian contrast at non-P33 cuts. Row facet = arm so the
# strip carries the arm name (no second arm colour legend); colour = encoder.
bm <- rbind(
  data.frame(fm = bsdf$fm, boundary = bsdf$boundary, alpha = bsdf$alpha,
             nominal = bsdf$nominal, arm = "split (source)",
             coverage = bsdf$split_cov, ci_low = bsdf$split_cov_lo,
             ci_high = bsdf$split_cov_hi),
  data.frame(fm = bsdf$fm, boundary = bsdf$boundary, alpha = bsdf$alpha,
             nominal = bsdf$nominal, arm = "spatial-Mondrian",
             coverage = bsdf$mond_cov, ci_low = bsdf$mond_cov_lo,
             ci_high = bsdf$mond_cov_hi))
bm$arm <- factor(bm$arm, levels = arm_lv)
bm_off <- bm[bm$boundary != "P33", ]
bm_off$fm <- factor(shorten_fm(bm_off$fm),
                    levels = intersect(unname(fm_short), unique(shorten_fm(bm_off$fm))))
bm_off$arm_lab <- factor(ifelse(bm_off$arm == "split (source)", "split", "Mondrian"),
                         levels = c("split", "Mondrian"))
# One nominal tick per α (not three full-width hlines from the long form).
nom_b <- unique(bm_off[, c("alpha", "nominal", "arm_lab", "boundary")])

f2b <- ggplot(bm_off, aes(factor(alpha), coverage, colour = fm, group = fm)) +
  geom_point(data = nom_b, aes(factor(alpha), nominal),
             shape = 95, size = 3.8, colour = "grey30",
             inherit.aes = FALSE, show.legend = FALSE) +
  geom_line(linewidth = 0.35) +
  geom_point(size = 1.55) +
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high), width = 0.12,
                linewidth = 0.28, show.legend = FALSE) +
  facet_grid(arm_lab ~ boundary, switch = "y") +
  scale_x_discrete(labels = c("0.05" = ".05", "0.1" = ".10", "0.2" = ".20")) +
  scale_color_model(name = NULL) +
  coord_cartesian(ylim = c(0.78, 1.0)) +
  labs(x = "α", y = "coverage") +
  guides(colour = guide_legend(nrow = 1, order = 2,
                               override.aes = list(linewidth = 0.6))) +
  theme_p3_panel() +
  theme(panel.grid.major.x = element_blank(),
        axis.text.x = element_text(size = 6.5),
        strip.text.x = element_text(size = 8),
        strip.text.y.left = element_text(size = 7.5, angle = 0),
        strip.placement = "outside")
prov("F2-B", BSWEEP, bm_off, "fm")

# F2-C: five conformal arms at α=0.10 (battery encoders; no DOFA in this record).
a5 <- arms5[abs(arms5$alpha - 0.10) < 1e-9, ]
a5$fm <- factor(shorten_fm(a5$fm),
                levels = intersect(unname(fm_short), unique(shorten_fm(a5$fm))))
a5_arm_short <- c("split (source)" = "split",
                  "target-global" = "tgt-glob",
                  "spatial-Mondrian" = "Mondrian",
                  "weighted" = "weighted",
                  "class-Mondrian" = "class-Mond")
a5$arm_x <- factor(unname(a5_arm_short[as.character(a5$arm)]),
                   levels = unname(a5_arm_short))
f2c <- ggplot(a5, aes(arm_x, coverage, colour = fm, group = fm)) +
  geom_hline(yintercept = 0.90, linetype = 2, colour = "grey35", linewidth = 0.35) +
  geom_point(size = 1.7, position = position_dodge(0.45)) +
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high), width = 0.18,
                linewidth = 0.3, position = position_dodge(0.45),
                show.legend = FALSE) +
  scale_color_model(name = NULL) +
  coord_cartesian(ylim = c(0.80, 0.96)) +
  labs(x = NULL, y = "coverage") +
  # Drop colour guide here so patchwork does not duplicate B's encoder legend.
  guides(colour = "none") +
  theme_p3_panel() +
  theme(panel.grid.major.x = element_blank(),
        axis.text.x = element_text(angle = 28, hjust = 1, size = 6.5))
prov("F2-C", BASE5, a5, "fm")

# F2-D: label-shift arms at α=0.10 (oracle ceiling vs BBSE estimate).
als <- armsls[abs(armsls$alpha - 0.10) < 1e-9, ]
als$fm <- factor(shorten_fm(als$fm),
                 levels = intersect(unname(fm_short), unique(shorten_fm(als$fm))))
als_arm_short <- c("split (source)" = "split",
                   "target-global" = "tgt-glob",
                   "weighted covariate" = "wtd-cov",
                   "label-shift oracle" = "LS-oracle",
                   "label-shift BBSE" = "LS-BBSE")
als$arm_x <- factor(unname(als_arm_short[as.character(als$arm)]),
                    levels = unname(als_arm_short))
f2d <- ggplot(als, aes(arm_x, coverage, colour = fm, group = fm)) +
  geom_hline(yintercept = 0.90, linetype = 2, colour = "grey35", linewidth = 0.35) +
  geom_point(size = 1.7, position = position_dodge(0.45)) +
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high), width = 0.18,
                linewidth = 0.3, position = position_dodge(0.45),
                show.legend = FALSE) +
  scale_color_model(name = NULL) +
  coord_cartesian(ylim = c(0.70, 0.96)) +
  labs(x = NULL, y = "coverage") +
  guides(colour = "none") +
  theme_p3_panel() +
  theme(panel.grid.major.x = element_blank(),
        axis.text.x = element_text(angle = 28, hjust = 1, size = 6.5))
prov("F2-D", LSHIFT, als, "fm")

# Equal 2×2; A supplies the arm legend, B the encoder legend; C/D guides dropped.
# Caption notes DOFA appears in A only (battery records for B–D lack DOFA).
f2_all <- (f2a | f2b) / (f2c | f2d) +
  plot_layout(guides = "collect", heights = c(1, 1), widths = c(1, 1)) +
  plot_annotation(tag_levels = "A") &
  tag_p3() &
  theme(legend.position = "bottom",
        legend.box = "horizontal",
        legend.box.just = "left",
        legend.spacing.x = unit(8, "pt"),
        legend.spacing.y = unit(1, "pt"))
save_fig(f2_all, "figures/F2_coverage_restoration", w = 5.2, h = 4.1)

chk <- function(lab, got, expect, tol = 5e-4) {
  ok <- isTRUE(abs(got - expect) < tol)
  cat(sprintf("  %s: got=%.4f expect=%.4f %s\n", lab, got, expect,
              if (ok) "OK" else "MISMATCH"))
  ok
}
cat("[F2 verify] frozen-JSON spot checks:\n")
dofa_a <- m[m$fm == "DOFA" & abs(m$alpha - 0.05) < 1e-9, ]
chk("DOFA split@0.05", dofa_a$coverage[dofa_a$arm == "split (source)"], 0.8507)
chk("DOFA Mondrian@0.05", dofa_a$coverage[dofa_a$arm == "spatial-Mondrian"], 0.9506)
chk("DOFA Mondrian@0.10",
    m$coverage[m$fm == "DOFA" & abs(m$alpha - 0.10) < 1e-9 &
                 m$arm == "spatial-Mondrian"], 0.9135)
chk("DOFA Mondrian@0.20",
    m$coverage[m$fm == "DOFA" & abs(m$alpha - 0.20) < 1e-9 &
                 m$arm == "spatial-Mondrian"], 0.8730)
chk("Prithvi Mondrian@0.05",
    m$coverage[m$fm == "Prithvi" & abs(m$alpha - 0.05) < 1e-9 &
                 m$arm == "spatial-Mondrian"], 0.9547)
}

if (do_fig("F3")) {
# Human-readable equal 2×2 rebuild (standalone; does not touch F1/F2 assets).
# Self-contained reload of the same frozen JSONs; writes only F3_setsize_vs_alpha.{pdf,png}.
source("figures/p3_f3_setsize.R")

}

cat("P3 figures written. Table:\n"); print(df)
