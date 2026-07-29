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
  scale_color_paper() +
  scale_y_continuous(breaks = 0:3, limits = c(0, 3.3)) +
  labs(x = "In-shift coverage debt (mean shift ECE across α)",
       y = "# α values where spatial-Mondrian restores coverage") +
  theme_paper() + theme(legend.position = "none")
# Physical render size set so the effective on-page text size (after LaTeX
# scales to \includegraphics[width=0.62\linewidth]) lands at ~8.5pt, matching
# the other figures in this paper (typography re-audit, 2026-07-16).
save_fig(f1, "figures/F1_debt_vs_robustness", w = 5.22, h = 3.35)

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
# Render size set so effective text at \includegraphics[width=0.95\linewidth]
# lands at ~8.5pt, matching the other figures (typography re-audit, 2026-07-16).
# Height raised (3.03 -> 4.05) now that the legend no longer needs its own
# row: the panels get the freed budget as taller axes.
save_fig(f2, "figures/F2_coverage_restoration", w = 7.99, h = 4.05)

# F3: Mondrian set size vs alpha (restoration costs set size > 1). Dotted line at 1 =
# the split-conformal singleton baseline (split set size is uniformly ~1.0 across all
# cells, so a separate series would be redundant with this reference). Error bars =
# n=5 seed-level CI on the Mondrian set size (previously discarded).
f3 <- ggplot(df, aes(factor(alpha), mond_size, colour = fm, group = fm)) +
  geom_hline(yintercept = 1, linetype = 3) +
  geom_errorbar(aes(ymin = mond_size_lo, ymax = mond_size_hi),
                width = 0.15, linewidth = 0.4, show.legend = FALSE) +
  geom_point(size = 3) + geom_line() +
  scale_color_paper() +
  labs(x = "α", y = "spatial-Mondrian mean set size") +
  # 5-entry single-row legend truncated at this render width (cut off after
  # "DOFA", printing a bare "Pt" for Prithvi-EO-2.0). Wrapped to 2 rows so
  # every encoder name prints in full; title blanked (redundant with the
  # directly-labelled series) so it doesn't float awkwardly beside the
  # wrapped rows -- 2026-07-16 visual-fix pass.
  guides(colour = guide_legend(nrow = 2, byrow = TRUE, title = NULL)) +
  theme_paper() + theme(panel.grid.major.x = element_blank())
# Render size set so effective text at \includegraphics[width=0.62\linewidth]
# lands at ~8.5pt, matching the other figures (typography re-audit, 2026-07-16).
save_fig(f3, "figures/F3_setsize_vs_alpha", w = 5.22, h = 3.68)

cat("P3 figures written. Table:\n"); print(df)
