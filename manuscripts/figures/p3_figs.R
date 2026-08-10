# P3 geospatial — all statistical figures from the REAL 5-FM result JSON (no hardcoded numbers).
# Kit pattern (reliability-commons/paper-template): run from manuscripts/ via `make figures`.
# Run: cd manuscripts && Rscript figures/p3_figs.R
#
# Figure input (2026-07-13): the five-encoder merged file. It is a deep-merged copy of the
# four battery encoders from the PROTECTED canonical results.json (Prithvi/Clay/SSL4EO-DINO/
# SSL4EO-MAE, byte-equivalent) PLUS the corrected DOFA fifth-encoder block (forward_features
# 768-d fix, re-run 2026-07-13). The canonical results.json is never modified; the merged file
# is a separate on-disk figure input under experiments/results/. Override with FIVEFM_RESULTS.
source("figures/ggtheme.R")  # vendored copy (formerly sourced from the manuscript-template repo)
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

f1 <- ggplot(deb, aes(debt, n_restored, colour = fm)) +
  geom_line(aes(group = 1), colour = "grey60", linetype = 2) +
  geom_point(size = 4) +
  # Label text fixed to black: colour is reserved for the point marks
  # themselves (house style: colored in-figure TEXT is not fine, colored
  # marks are) -- 2026-07-16 visual-fix pass.
  ggrepel::geom_text_repel(aes(label = fm), size = 3.3, colour = "black",
                           show.legend = FALSE,
                           family = PAPER_FONT,
                           box.padding = 0.5, point.padding = 0.3,
                           min.segment.length = 0, seed = 1) +
  scale_color_model() +
  scale_y_continuous(breaks = 0:3, limits = c(0, 3.3)) +
  # Title shortened: the full sentence spanned the entire axis height and
  # overprinted the panel tag once this became a 4-panel composite.
  labs(x = "In-shift coverage debt (mean shift ECE across α)",
       y = "# α where spatial-Mondrian restores") +
  theme_paper() + theme(legend.position = "none")
prov("F1-A", RES, deb, "fm")

# F1-B: accuracy under real shift, per FM x alpha (the robustness axis the
# debt is being compared against in panel A, shown directly).
accdf <- data.frame(fm = df$fm, alpha = df$alpha, acc = df$acc_shift,
                    stringsAsFactors = FALSE)
accdf$fm <- shorten_fm(accdf$fm)
f1b <- ggplot(accdf, aes(factor(alpha), acc, colour = fm, group = fm)) +
  geom_point(size = 2.4) + geom_line(linewidth = 0.4) +
  scale_color_model() +
  labs(x = "α", y = "top-1 accuracy under real shift") +
  guides(colour = guide_legend(nrow = 2, byrow = TRUE, title = NULL)) +
  theme_paper() + theme(panel.grid.major.x = element_blank())
prov("F1-B", RES, accdf, "fm")

# F1-C: boundary sweep -- how many alphas the spatial-Mondrian arm restores at
# each spatial boundary percentile. Tests whether panel A's ordering is an
# artifact of the single P33 cut.
nres <- aggregate(restored ~ fm + boundary, data = bsdf, FUN = sum)
names(nres)[3] <- "n_restored"
nres$fm <- shorten_fm(nres$fm)
f1c <- ggplot(nres, aes(boundary, n_restored, colour = fm, group = fm)) +
  geom_point(size = 2.4) + geom_line(linewidth = 0.4) +
  scale_color_model() + scale_y_continuous(breaks = 0:3, limits = c(0, 3.3)) +
  labs(x = "spatial boundary percentile", y = "# α restored") +
  guides(colour = guide_legend(nrow = 2, byrow = TRUE, title = NULL)) +
  theme_paper() + theme(panel.grid.major.x = element_blank())
prov("F1-C", BSWEEP, nres, "fm")

# F1-D: so2sat cross-continent replication. so2sat carries no spatial-Mondrian
# arm -- it is a target-global label-access ablation -- so the comparison is
# split vs target_global against nominal.
s2m <- rbind(
  data.frame(fm = s2df$fm, alpha = s2df$alpha, nominal = s2df$nominal,
             arm = "split (source)", coverage = s2df$split_cov,
             ci_low = s2df$split_cov_lo, ci_high = s2df$split_cov_hi),
  data.frame(fm = s2df$fm, alpha = s2df$alpha, nominal = s2df$nominal,
             arm = "target-global", coverage = s2df$tg_cov,
             ci_low = s2df$tg_cov_lo, ci_high = s2df$tg_cov_hi))
s2m$arm <- factor(s2m$arm, levels = c("split (source)","target-global"))
s2m$fm <- shorten_fm(s2m$fm)
f1d <- ggplot(s2m, aes(factor(alpha), coverage, colour = arm, group = arm)) +
  geom_point(size = 1.9, position = position_dodge(0.35)) +
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high), width = 0.2,
                linewidth = 0.35, position = position_dodge(0.35)) +
  geom_point(aes(y = nominal), shape = 95, size = 4, colour = "grey30",
             show.legend = FALSE) +
  facet_wrap(~fm, nrow = 1) + scale_color_paper() +
  labs(x = "α", y = "coverage (So2Sat LCZ)") +
  # 2 arm labels on one row measure ~204pt under a 171pt half-width panel and
  # overhang the device edge; stacking them keeps the legend inside the canvas.
  guides(colour = guide_legend(nrow = 2, byrow = TRUE, title = NULL)) +
  theme_paper() +
  theme(panel.grid.major.x = element_blank(),
        axis.text.x = element_text(size = 9.5),
        strip.text = element_text(size = 9.5))
prov("F1-D", SO2SAT, s2m, "fm")

f1_all <- (f1 | f1b) / (f1c | f1d) +
  plot_annotation(tag_levels = "A") & paper_tag_theme()
save_fig(f1_all, "figures/F1_debt_vs_robustness", w = 4.75, h = 3.69)

# F2: per-FM per-alpha split vs Mondrian coverage (with nominal) -- base-R reshape, no reshape2
m <- rbind(
  data.frame(fm = df$fm, alpha = df$alpha, nominal = df$nominal,
             arm = "split-conformal (source)", coverage = df$split_cov,
             ci_low = df$split_cov_lo, ci_high = df$split_cov_hi),
  data.frame(fm = df$fm, alpha = df$alpha, nominal = df$nominal,
             arm = "spatial-Mondrian", coverage = df$mond_cov,
             ci_low = df$mond_cov_lo, ci_high = df$mond_cov_hi))
m$arm <- factor(m$arm, levels = c("split-conformal (source)","spatial-Mondrian"))
# Error bars = n=5 seed-level CI carried in the frozen JSON (previously discarded).
# panel.grid.major.x blanked: x is the categorical α factor, so vertical gridlines
# carry no reading value (coverage is read against the horizontal grid only).
# 5 fm levels in a facet_wrap default 3x2 grid leave one empty cell
# (bottom-right, under Prithvi-EO-2.0). Previously this cell sat blank while
# a separate full-width legend strip ran below the whole grid, wasting
# height on redundant white space and squeezing the panels' plotted (data)
# area short. Fixed by parking the legend inside that empty cell instead of
# a dedicated legend row, and giving the freed vertical budget to the panels
# (taller axes) -- 2026-07-16 visual-fix pass.
f2 <- ggplot(m, aes(factor(alpha), coverage, fill = arm)) +
  geom_col(position = position_dodge(0.8), width = 0.7) +
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high),
                position = position_dodge(0.8), width = 0.25,
                linewidth = 0.35, colour = "grey25") +
  geom_hline(aes(yintercept = nominal), linetype = 2, colour = "grey30") +
  facet_wrap(~fm) + scale_fill_paper() + coord_cartesian(ylim = c(0.78, 1.0)) +
  labs(x = "α", y = "target coverage under real shift", fill = "arm") +
  theme_paper() +
  theme(panel.grid.major.x = element_blank(),
        legend.position = "inside", legend.position.inside = c(0.84, 0.24),
        legend.background = element_rect(fill = "white", colour = "grey70", linewidth = 0.3))
prov("F2-A", RES, m, "fm")

# F2-B: boundary sensitivity. Panel A is the P33 cut; this shows the same
# split-vs-Mondrian comparison at the other three percentiles, so a reader can
# see the restoration is not specific to where the spatial line was drawn.
bm <- rbind(
  data.frame(fm = bsdf$fm, boundary = bsdf$boundary, alpha = bsdf$alpha,
             nominal = bsdf$nominal, arm = "split (source)",
             coverage = bsdf$split_cov, ci_low = bsdf$split_cov_lo,
             ci_high = bsdf$split_cov_hi),
  data.frame(fm = bsdf$fm, boundary = bsdf$boundary, alpha = bsdf$alpha,
             nominal = bsdf$nominal, arm = "spatial-Mondrian",
             coverage = bsdf$mond_cov, ci_low = bsdf$mond_cov_lo,
             ci_high = bsdf$mond_cov_hi))
bm$arm <- factor(bm$arm, levels = c("split (source)","spatial-Mondrian"))
bm_off <- bm[bm$boundary != "P33", ]   # P33 is panel A
bm_off$fm <- shorten_fm(bm_off$fm)
f2b <- ggplot(bm_off, aes(factor(alpha), coverage, colour = arm, group = arm)) +
  geom_point(size = 1.5, position = position_dodge(0.4)) +
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high), width = 0.18,
                linewidth = 0.3, position = position_dodge(0.4)) +
  geom_point(aes(y = nominal), shape = 95, size = 3, colour = "grey30",
             show.legend = FALSE) +
  facet_grid(boundary ~ fm) + scale_color_paper() +
  labs(x = "α", y = "coverage") +
  guides(colour = guide_legend(nrow = 1, title = NULL)) +
  theme_paper() +
  theme(panel.grid.major.x = element_blank(),
        axis.text = element_text(size = 9.5),
        strip.text = element_text(size = 9.5))
prov("F2-B", BSWEEP, bm_off, "fm")

# F2-C: five conformal arms side by side at a single risk level. alpha is fixed
# at 0.10 so the arm contrast is not confounded with the risk level.
a5 <- arms5[abs(arms5$alpha - 0.10) < 1e-9, ]
a5$fm <- shorten_fm(a5$fm)
f2c <- ggplot(a5, aes(arm, coverage, colour = fm, group = fm)) +
  geom_hline(aes(yintercept = nominal), linetype = 2, colour = "grey30") +
  geom_point(size = 1.9, position = position_dodge(0.4)) +
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high), width = 0.2,
                linewidth = 0.35, position = position_dodge(0.4)) +
  scale_color_model() +
  labs(x = NULL, y = "coverage (α = 0.10)") +
  guides(colour = guide_legend(nrow = 2, byrow = TRUE, title = NULL)) +
  theme_paper() +
  theme(panel.grid.major.x = element_blank(),
        axis.text.x = element_text(angle = 30, hjust = 1, size = 9.5))
prov("F2-C", BASE5, a5, "fm")

# F2-D: label-shift adjusted baselines at the same alpha. The oracle is the
# ceiling an estimated label-shift correction is trying to reach; BBSE is the
# estimable version.
als <- armsls[abs(armsls$alpha - 0.10) < 1e-9, ]
als$fm <- shorten_fm(als$fm)
f2d <- ggplot(als, aes(arm, coverage, colour = fm, group = fm)) +
  geom_hline(aes(yintercept = nominal), linetype = 2, colour = "grey30") +
  geom_point(size = 1.9, position = position_dodge(0.4)) +
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high), width = 0.2,
                linewidth = 0.35, position = position_dodge(0.4)) +
  scale_color_model() +
  labs(x = NULL, y = "coverage (α = 0.10)") +
  guides(colour = guide_legend(nrow = 2, byrow = TRUE, title = NULL)) +
  theme_paper() +
  theme(panel.grid.major.x = element_blank(),
        axis.text.x = element_text(angle = 30, hjust = 1, size = 9.5))
prov("F2-D", LSHIFT, als, "fm")

f2_all <- (f2 | f2b) / (f2c | f2d) +
  plot_annotation(tag_levels = "A") & paper_tag_theme()
save_fig(f2_all, "figures/F2_coverage_restoration", w = 4.75, h = 3.69)

# F3: Mondrian set size vs alpha (restoration costs set size > 1). Dotted line at 1 =
# the split-conformal singleton baseline (split set size is uniformly ~1.0 across all
# cells, so a separate series would be redundant with this reference). Error bars =
# n=5 seed-level CI on the Mondrian set size (previously discarded).
# Panel A's legend is the widest object in this figure: the comment below claimed
# A "labels points directly" and so could keep the full encoder names, but it
# draws an ordinary 5-entry legend. At full names that legend is ~300pt wide
# under a 171pt half-width panel, so it hung ~53pt off both edges of the 342pt
# device and cairo clipped it. A now uses the same short forms as B/C/D.
dfs <- df
dfs$fm <- shorten_fm(dfs$fm)
f3 <- ggplot(dfs, aes(factor(alpha), mond_size, colour = fm, group = fm)) +
  geom_hline(yintercept = 1, linetype = 3) +
  geom_errorbar(aes(ymin = mond_size_lo, ymax = mond_size_hi),
                width = 0.15, linewidth = 0.4, show.legend = FALSE) +
  geom_point(size = 3) + geom_line() +
  scale_color_model() +
  labs(x = "α", y = "spatial-Mondrian mean set size") +
  # 5-entry single-row legend truncated at this render width (cut off after
  # "DOFA", printing a bare "Pt" for Prithvi-EO-2.0). Wrapped to 2 rows so
  # every encoder name prints in full; title blanked (redundant with the
  # directly-labelled series) so it doesn't float awkwardly beside the
  # wrapped rows -- 2026-07-16 visual-fix pass.
  guides(colour = guide_legend(nrow = 2, byrow = TRUE, title = NULL)) +
  theme_paper() + theme(panel.grid.major.x = element_blank())
prov("F3-A", RES, df, "fm")

# F3-B: split-conformal set size on the same axes as A. Panel A's dotted line at
# 1 asserts split sits at the singleton floor; drawing the split series directly
# lets a reader verify that rather than take it on trust.
sp <- data.frame(fm = shorten_fm(df$fm), alpha = df$alpha, size = df$split_size,
                 lo = df$split_size_lo, hi = df$split_size_hi,
                 stringsAsFactors = FALSE)
f3b <- ggplot(sp, aes(factor(alpha), size, colour = fm, group = fm)) +
  geom_hline(yintercept = 1, linetype = 3) +
  geom_errorbar(aes(ymin = lo, ymax = hi), width = 0.15, linewidth = 0.4,
                show.legend = FALSE) +
  geom_point(size = 2.4) + geom_line(linewidth = 0.4) +
  scale_color_model() +
  labs(x = "α", y = "split-conformal mean set size") +
  guides(colour = guide_legend(nrow = 2, byrow = TRUE, title = NULL)) +
  theme_paper() + theme(panel.grid.major.x = element_blank())
prov("F3-B", RES, sp, "fm")

# F3-C: set size vs spatial boundary at one risk level -- the cost side of the
# F1-C restoration count.
bsz <- bsdf[abs(bsdf$alpha - 0.10) < 1e-9, ]
bszm <- rbind(
  data.frame(fm = bsz$fm, boundary = bsz$boundary, arm = "split (source)",
             size = bsz$split_size),
  data.frame(fm = bsz$fm, boundary = bsz$boundary, arm = "spatial-Mondrian",
             size = bsz$mond_size))
bszm$arm <- factor(bszm$arm, levels = c("split (source)","spatial-Mondrian"))
bszm$fm <- shorten_fm(bszm$fm)
f3c <- ggplot(bszm, aes(boundary, size, colour = arm, group = arm)) +
  geom_hline(yintercept = 1, linetype = 3) +
  geom_point(size = 1.9) + geom_line(linewidth = 0.4) +
  facet_wrap(~fm, nrow = 1) + scale_color_paper() +
  labs(x = "spatial boundary percentile", y = "mean set size (α = 0.10)") +
  guides(colour = guide_legend(nrow = 1, title = NULL)) +
  theme_paper() +
  theme(panel.grid.major.x = element_blank(),
        axis.text.x = element_text(angle = 45, hjust = 1, size = 9.5),
        strip.text = element_text(size = 9.5))
prov("F3-C", BSWEEP, bszm, "fm")

# F3-D: So2Sat set size. 17 LCZ classes, so the sets are far larger than
# EuroSAT's 10-class sets -- deliberately NOT on a shared y-scale with A/B,
# which would compress both into unreadable strips.
s2sz <- rbind(
  data.frame(fm = s2df$fm, alpha = s2df$alpha, arm = "split (source)",
             size = s2df$split_size, lo = s2df$split_size_lo, hi = s2df$split_size_hi),
  data.frame(fm = s2df$fm, alpha = s2df$alpha, arm = "target-global",
             size = s2df$tg_size, lo = s2df$tg_size_lo, hi = s2df$tg_size_hi))
s2sz$arm <- factor(s2sz$arm, levels = c("split (source)","target-global"))
s2sz$fm <- shorten_fm(s2sz$fm)
f3d <- ggplot(s2sz, aes(factor(alpha), size, colour = arm, group = arm)) +
  geom_hline(yintercept = 1, linetype = 3) +
  geom_point(size = 1.7, position = position_dodge(0.35)) +
  geom_errorbar(aes(ymin = lo, ymax = hi), width = 0.18, linewidth = 0.3,
                position = position_dodge(0.35)) +
  scale_color_paper() +
  labs(x = "α", y = "mean set size (So2Sat, 17 LCZ)") +
  # Same 204pt-under-171pt legend overhang as F1-D; stack the two arm entries.
  guides(colour = guide_legend(nrow = 2, byrow = TRUE, title = NULL)) +
  facet_wrap(~fm, nrow = 1) +
  theme_paper() +
  theme(panel.grid.major.x = element_blank(),
        axis.text.x = element_text(size = 9.5),
        # 5 facets across a full-width row give ~62pt per strip; "SSL4EO-DINO"
        # does not fit that at 9.5pt and shears. label_wrap_gen is no help here
        # -- it only breaks on whitespace and these names have none -- so the
        # strip text drops to 7pt, which does fit. Must stay in this final
        # theme() call: an earlier one is overridden by the later strip.text.
        strip.text = element_text(size = 7))
prov("F3-D", SO2SAT, s2sz, "fm")

# Layout: a 2x2 grid at 342pt gives each panel ~171pt, too narrow for a y-axis
# title + plot + a 5-entry legend (A/B) or a 4-5 facet strip (C/D). ggplot clips
# overflowing text when it draws, so the shortfall shows up as sheared labels in
# the render ("atial-Mondrian mean set", strip "4EO-D"), not as out-of-canvas
# geometry -- it has to be checked on a rasterised page, not measured.
# A and B plot the same 5 encoders on the same colour scale. Side by side they
# each drew their own 5-entry legend; at ~204pt per legend under a 171pt panel
# the two collided mid-row (right legend sheared to a bare "P" + unlabelled
# key). Suppress B's legend and let A's single legend serve the shared row --
# patchwork's guides="collect" was tried first and is not usable here: it pools
# the guides into a tall right-hand block that squeezes A and B into slivers.
f3_row1 <- (f3 | (f3b + theme(legend.position = "none")))
f3_all <- f3_row1 / f3c / f3d +
  plot_layout(heights = c(1, 1, 1)) +
  plot_annotation(tag_levels = "A") & paper_tag_theme()
save_fig(f3_all, "figures/F3_setsize_vs_alpha", w = 4.75, h = 7.20)

cat("P3 figures written. Table:\n"); print(df)
