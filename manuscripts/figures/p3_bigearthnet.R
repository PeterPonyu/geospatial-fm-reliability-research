# P3 BigEarthNet dominant-label-proxy replication figure from the REAL result JSON (no hardcoded numbers).
# Kit pattern (reliability-commons/paper-template): run from manuscripts/ via `make figures`.
# Run: cd manuscripts && Rscript figures/p3_bigearthnet.R
# Output renamed 2026-07-02: F5_bigearthnet_domlabel (this is the DOMINANT-LABEL proxy figure;
# the per-label multi-label conformal figure F6 is produced by p3_bigearthnet_perlabel.R).
source("figures/ggtheme.R")  # vendored copy (formerly sourced from the manuscript-template repo)
RES <- "../experiments/results/bigearthnet_coverage_debt.json"
d <- read_result(RES)
fms <- names(d$fm_results)
fm_lab <- c(prithvi="Prithvi-EO-2.0", clay="Clay v1.5", ssl4eo="SSL4EO-S12")
getm  <- function(x) if (is.null(x)) NA_real_ else as.numeric(x$mean)
# n=5 seed-level CI accessors — the frozen JSON carries {ci_low, ci_high} on every
# coverage block; surface them as error bars (2026-07-16 fig-content pass).
getlo <- function(x) if (is.null(x)) NA_real_ else as.numeric(x$ci_low)
gethi <- function(x) if (is.null(x)) NA_real_ else as.numeric(x$ci_high)
rows <- list()
for (fm in fms) {
  alphas <- names(d$fm_results[[fm]]$per_alpha)
  for (a in alphas) {
    c0 <- d$fm_results[[fm]]$per_alpha[[a]]$cell; rs <- c0$real_shift
    rows[[length(rows)+1]] <- data.frame(
      fm = fm_lab[[fm]], alpha = as.numeric(a), nominal = 1 - as.numeric(a),
      split_cov = getm(rs$conformal_split$coverage),
      split_cov_lo = getlo(rs$conformal_split$coverage),
      split_cov_hi = gethi(rs$conformal_split$coverage),
      mond_cov  = getm(rs$conformal_spatial_mondrian$coverage),
      mond_cov_lo = getlo(rs$conformal_spatial_mondrian$coverage),
      mond_cov_hi = gethi(rs$conformal_spatial_mondrian$coverage),
      mond_size = getm(rs$conformal_spatial_mondrian$set_size),
      stringsAsFactors = FALSE)
  }
}
df <- do.call(rbind, rows)
df$fm <- factor(df$fm, levels = fm_lab[fms])
write.csv(df, "figures/p3_bigearthnet_table.csv", row.names = FALSE)

m <- rbind(
  data.frame(fm=df$fm, alpha=df$alpha, nominal=df$nominal, arm="split-conformal (source)",
             coverage=df$split_cov, ci_low=df$split_cov_lo, ci_high=df$split_cov_hi),
  data.frame(fm=df$fm, alpha=df$alpha, nominal=df$nominal, arm="spatial-Mondrian",
             coverage=df$mond_cov,  ci_low=df$mond_cov_lo,  ci_high=df$mond_cov_hi))
m$arm <- factor(m$arm, levels=c("split-conformal (source)","spatial-Mondrian"))

# Per-α dashed black segments = nominal coverage 1−α (legend-named).
# Vertical whiskers on bars = seed-level t-CIs (n=5) — a different mark.
nom <- unique(df[, c("fm", "alpha", "nominal")])
nom$x_num <- as.numeric(factor(nom$alpha))

f <- ggplot(m, aes(factor(alpha), coverage, fill = arm)) +
  geom_col(position = position_dodge(0.82), width = 0.74) +
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high),
                position = position_dodge(0.82), width = 0.20,
                linewidth = 0.35, colour = "grey25") +
  geom_segment(
    data = nom,
    aes(x = x_num - 0.38, xend = x_num + 0.38,
        y = nominal, yend = nominal,
        linetype = "nominal 1−α"),
    inherit.aes = FALSE,
    colour = "grey20", linewidth = 0.55
  ) +
  facet_wrap(~fm, nrow = 1) +
  scale_fill_paper(name = NULL) +
  scale_linetype_manual(name = NULL, values = c("nominal 1−α" = "dashed")) +
  coord_cartesian(ylim = c(0.45, 1.0)) +
  labs(x = "α", y = "target coverage under real geographic shift") +
  guides(
    fill = guide_legend(order = 1, nrow = 1, title = NULL),
    linetype = guide_legend(
      order = 2, nrow = 1, title = NULL,
      override.aes = list(colour = "grey20", linewidth = 0.55,
                          fill = NA, shape = NA))
  ) +
  theme_paper() +
  theme(
    panel.grid.major.x = element_blank(),
    panel.spacing.x = unit(4, "pt"),
    legend.position = "bottom",
    legend.box = "horizontal",
    legend.direction = "horizontal",
    legend.margin = margin(t = 0, r = 2, b = 0, l = 2),
    legend.box.margin = margin(t = 0, r = 0, b = 0, l = 0),
    legend.box.spacing = unit(1, "pt"),
    legend.spacing.x = unit(8, "pt"),
    axis.title.x = element_text(margin = margin(t = 1)),
    axis.title.y = element_text(margin = margin(r = 1)),
    plot.margin = margin(t = 2, r = 2, b = 0, l = 2)
  )
# Previous 4.75×2.28 read as a thin ribbon with excess side margin once scaled
# to \linewidth; nudge width and raise height so three encoder panels fill the column.
save_fig(f, "figures/F5_bigearthnet_domlabel", w = 5.05, h = 3.15)
cat("BigEarthNet dominant-label figure written. Table:\n"); print(df)
