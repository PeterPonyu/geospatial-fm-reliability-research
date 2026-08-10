# P3 BigEarthNet PER-LABEL multi-label conformal figure (F6) from the REAL result JSON
# (no hardcoded numbers). Replaces the matplotlib PNG-only panel in
# experiments/results/bigearthnet_perlabel_figs/ with a kit-pattern R figure (PDF+PNG).
# Kit pattern (reliability-commons/paper-template): run from manuscripts/ via `make figures`.
# Run: cd manuscripts && Rscript figures/p3_bigearthnet_perlabel.R
source("figures/ggtheme.R")  # vendored copy (formerly sourced from the manuscript-template repo)
RES <- "../experiments/results/bigearthnet_perlabel_conformal.json"
d <- read_result(RES)
fms <- names(d$fm_results)
fm_lab <- c(prithvi="Prithvi-EO-2.0", ssl4eo="SSL4EO-S12", clay="Clay v1.5")

num <- function(x) if (is.null(x)) NA_real_ else as.numeric(x)
rows <- list()
for (fm in fms) {
  alphas <- names(d$fm_results[[fm]]$per_alpha)
  for (a in alphas) {
    s <- d$fm_results[[fm]]$per_alpha[[a]]$summary
    r <- s$restoration
    add <- function(metric, arm, blk) {
      rows[[length(rows)+1]] <<- data.frame(
        fm = fm_lab[[fm]], alpha = as.numeric(a), nominal = 1 - as.numeric(a),
        metric = metric, arm = arm,
        mean = num(blk$mean), ci_low = num(blk$ci_low), ci_high = num(blk$ci_high),
        stringsAsFactors = FALSE)
    }
    add("Recall-coverage", "split-conformal (source)", s$mean_per_label_coverage_sh_split)
    add("Recall-coverage", "spatial-Mondrian",         s$mean_per_label_coverage_sh_mond)
    add("Label-set size (shift)",  "split-conformal (source)", r$set_size_sh_split)
    add("Label-set size (shift)",  "spatial-Mondrian",         r$set_size_sh_mond)
  }
}
df <- do.call(rbind, rows)
df$fm <- factor(df$fm, levels = fm_lab[fms])
df$metric <- factor(df$metric,
                    levels = c("Recall-coverage", "Label-set size (shift)"))
df$arm <- factor(df$arm, levels = c("split-conformal (source)", "spatial-Mondrian"))
write.csv(df, "figures/p3_bigearthnet_perlabel_table.csv", row.names = FALSE)

nom <- unique(df[df$metric == "Recall-coverage",
                 c("fm", "alpha", "nominal", "metric")])

# Nominal (1-alpha) reference marker. Typesetter note (2026-07-16 reader
# pass): the previous grey20 shape-95 dash read as a squint-test item at
# normal print size. Replaced with an explicit short dashed segment spanning
# each facet's x-tick width, in solid black with a heavier linewidth, so it
# reads unambiguously as "the nominal reference line" rather than a stray
# mark -- still black-only (no colour channel spent on it).
nom$x_num <- as.numeric(factor(nom$alpha))
f6 <- ggplot(df, aes(factor(alpha), mean, colour = arm, group = arm)) +
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high), width = 0.15, linewidth = 0.5) +
  geom_line(linewidth = 0.6) + geom_point(size = 2.2) +
  geom_segment(data = nom, aes(x = x_num - 0.32, xend = x_num + 0.32,
                               y = nominal, yend = nominal), inherit.aes = FALSE,
               colour = "black", linewidth = 1.0, linetype = "dashed") +
  facet_grid(metric ~ fm, scales = "free_y", switch = "y") +
  scale_color_paper() +
  labs(x = "α", y = NULL, colour = "arm") +
  theme_paper() + theme(strip.placement = "outside")
# Render size set so effective text at \includegraphics[width=0.95\linewidth]
# lands at ~8.5pt, matching the other figures (typography re-audit, 2026-07-16).
save_fig(f6, "figures/F6_bigearthnet_perlabel", w = 4.75, h = 2.64)
cat("BigEarthNet per-label figure written. Table:\n"); print(df)
