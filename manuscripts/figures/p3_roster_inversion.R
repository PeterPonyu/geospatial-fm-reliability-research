# n=13 BEN cross-encoder inversion scatter (FNR shift vs in-distribution mAP).
# Reads the frozen roster analysis CSV emitted by roster_analysis_2026-07-16
# (traced to bigearthnet_crc_arm_roster + ben_map_roster). House style: black
# text labels, colored marks reserved for architecture family; ~8.5pt effective
# at \includegraphics[width=0.62\linewidth].
# Run: cd manuscripts && Rscript figures/p3_roster_inversion.R
source("figures/ggtheme.R")
suppressPackageStartupMessages(library(ggplot2))
CSV <- Sys.getenv("ROSTER_CSV", "figures/roster_inversion_n13.csv")
d <- read.csv(CSV, stringsAsFactors = FALSE)

# Spearman over the full n=13 (matches roster_analysis results.json: rho=+0.32).
rho <- cor(d$mAP_in, d$fnr_sh, method = "spearman")
lab_stat <- sprintf("Spearman rho = %+.2f  (p = 0.28, n = 13)", rho)

d$roster <- ifelse(d$in_n5 == "yes", "original 5", "added (roster)")
d$roster <- factor(d$roster, levels = c("original 5", "added (roster)"))
d$arch   <- factor(d$arch, levels = c("ViT", "CNN"))

# SSL4EO-DINO sits within 0.0015 fnr of the OLS line (of a ~0.10 y-range), so
# auto-repel places its label directly across the dashed line regardless of
# seed. Route it through a separate repel layer nudged straight up, clear of
# the line and of the SoftCon-ViT-S label above it (2026-07-16 visual-fix pass).
#
# Typesetter note (2026-07-16 reader pass): the mid-mAP cluster around
# SoftCon-ViT-B / CROMA-L / SSL4EO-MAE (mAP ~0.52-0.55, fnr_sh ~0.17-0.19) is
# the densest group of points in the plot. Each gets its own single-point
# repel layer with a distinct fixed nudge (a different clock position) so
# their leader lines fan out instead of stacking on top of each other.
manual_nudges <- list(
  "SSL4EO-DINO"   = list(nudge_x =  0.004, nudge_y =  0.017, direction = "y"),
  "SoftCon-ViT-B" = list(nudge_x = -0.016, nudge_y = -0.022, direction = "both"),
  "CROMA-L"       = list(nudge_x =  0.016, nudge_y =  0.020, direction = "both"),
  # SSL4EO-MAE and SSL4EO-MAE-L (vit_large_mae) share almost the identical
  # in-distribution mAP (0.5496 vs 0.5496), so they are pushed to opposite
  # corners -- MAE down-left, MAE-L up-right -- rather than left to collide.
  "SSL4EO-MAE"    = list(nudge_x = -0.024, nudge_y = -0.040, direction = "both"),
  "SSL4EO-MAE-L"  = list(nudge_x =  0.020, nudge_y =  0.018, direction = "both")
)
crowded <- names(manual_nudges)
d_auto  <- d[!(d$label %in% crowded), ]
manual_layers <- lapply(crowded, function(lbl) {
  cfg <- manual_nudges[[lbl]]
  ggrepel::geom_text_repel(data = d[d$label == lbl, ], aes(label = label), size = 3.5,
                           colour = "black", family = PAPER_FONT,
                           nudge_x = cfg$nudge_x, nudge_y = cfg$nudge_y,
                           direction = cfg$direction, box.padding = 0.3,
                           point.padding = 0.25, min.segment.length = 0,
                           segment.size = 0.3, seed = 7)
})

f <- ggplot(d, aes(mAP_in, fnr_sh)) +
  # No OLS/trend line: the correlation is non-significant (p=0.28, n=13) and a fitted
  # line was judged to visually imply a trend the statistics do not support
  # (fixwave 2026-07-16, tutor review note 2). Points and the reported Spearman rho
  # are the only load-bearing content of this panel.
  geom_point(aes(colour = arch, shape = roster), size = 3.1) +
  ggrepel::geom_text_repel(data = d_auto, aes(label = label), size = 3.5,
                           colour = "black",
                           family = PAPER_FONT, box.padding = 0.5,
                           point.padding = 0.3, min.segment.length = 0,
                           max.overlaps = 20, seed = 7) +
  manual_layers +
  scale_color_paper() +
  scale_shape_manual(values = c("original 5" = 16, "added (roster)" = 17)) +
  annotate("text", x = min(d$mAP_in), y = max(d$fnr_sh),
           label = lab_stat, hjust = 0, vjust = 1, size = 3.5,
           colour = "black", family = PAPER_FONT) +
  labs(x = "In-distribution mAP",
       y = expression(paste("FNR under shift (CRC, ", alpha, " = 0.05)")),
       colour = "backbone", shape = "roster") +
  theme_paper() +
  theme(legend.position = "bottom", legend.box = "horizontal",
        legend.margin = margin(0, 0, 0, 0))

save_fig(f, "figures/F7_ben_inversion_n13", w = 5.22, h = 3.55)
cat(sprintf("F7 written. n=%d, Spearman(FNR_sh, mAP) = %+.4f\n", nrow(d), rho))
