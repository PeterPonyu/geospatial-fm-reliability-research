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

# Nominal 1−α guides only on the recall-coverage row (coverage has a nominal;
# set-size does not). Short black dashed segments — named in the legend so they
# cannot be mistaken for horizontal error bars / CI whiskers on the points.
nom <- unique(df[df$metric == "Recall-coverage",
                 c("fm", "alpha", "nominal", "metric")])
nom$x_num <- as.numeric(factor(nom$alpha))

f6 <- ggplot(df, aes(factor(alpha), mean, colour = arm, group = arm)) +
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high), width = 0.14, linewidth = 0.4) +
  geom_line(linewidth = 0.7) +
  geom_point(size = 2.4) +
  geom_segment(
    data = nom,
    aes(x = x_num - 0.34, xend = x_num + 0.34,
        y = nominal, yend = nominal,
        linetype = "nominal 1−α"),
    inherit.aes = FALSE,
    colour = "black", linewidth = 0.7
  ) +
  facet_grid(metric ~ fm, scales = "free_y", switch = "y") +
  scale_color_paper(name = NULL) +
  scale_linetype_manual(name = NULL, values = c("nominal 1−α" = "dashed")) +
  labs(x = "α", y = NULL, colour = NULL) +
  guides(
    colour = guide_legend(order = 1, nrow = 1, title = NULL),
    linetype = guide_legend(
      order = 2, nrow = 1, title = NULL,
      override.aes = list(
        colour = "black", linewidth = 0.7,
        shape = NA, fill = NA
      ))
  ) +
  theme_paper() +
  theme(
    strip.placement = "outside",
    panel.spacing.x = unit(4, "pt"),
    panel.spacing.y = unit(4, "pt"),
    legend.position = "bottom",
    legend.box = "horizontal",
    legend.direction = "horizontal",
    legend.margin = margin(t = 0, r = 2, b = 0, l = 2),
    legend.box.margin = margin(t = 0, r = 0, b = 0, l = 0),
    legend.box.spacing = unit(1, "pt"),
    legend.spacing.x = unit(8, "pt"),
    axis.title.x = element_text(margin = margin(t = 1)),
    # Extra left margin so outside y-strips ("Recall-coverage", …) are not clipped.
    plot.margin = margin(t = 2, r = 2, b = 0, l = 5)
  )
# Previous 4.75×2.64 left a thin 2×3 grid with clipped y-strips and a legend
# floating in whitespace; raise height and nudge width so panels fill the column.
save_fig(f6, "figures/F6_bigearthnet_perlabel", w = 5.05, h = 3.70)
cat("BigEarthNet per-label figure written. Table:\n"); print(df)
