# n=13 BEN cross-encoder inversion scatter (FNR shift vs in-distribution mAP).
# Reads the frozen roster analysis CSV emitted by roster_analysis_2026-07-16
# (traced to bigearthnet_crc_arm_roster + ben_map_roster). House style: black
# text labels, colored marks reserved for architecture family.
# Run: cd manuscripts && Rscript figures/p3_roster_inversion.R
#
# Visual-fix pass (2026-08-12): denser mid/right cluster was overlapping at
# the prior 5.22x3.55in / size=3.5 layout. Larger device, smaller labels,
# Spearman as caption (no banner collision), and fixed geom_text + geom_segment
# anchors so leaders do not cross in the mid/right pack.
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

lbl_size <- 2.5

# Absolute label anchors chosen so each leader stays in its own sector of a
# clock around the mid/right cloud (no X-crossings):
#   W SoftCon-B | SW SoftCon left-down reserved | S CROMA-L / MAE / MAE-L
#   SE MAE-L | E MoCo | NE DINO | N CNN pair | NW SoftCon-S | WNW Clay/DOFA
lab_pos <- data.frame(
  label = c(
    "Prithvi", "DOFA", "Clay", "SoftCon-ViT-B", "SoftCon-ViT-S",
    "CROMA-B", "CROMA-L", "SSL4EO-MAE", "SSL4EO-MAE-L", "SSL4EO-DINO",
    "SSL4EO-MoCo", "ResNet50-MoCo", "ResNet50-DINO"
  ),
  # MAE sits directly above MAE-L, so its leader must go sideways (right),
  # never straight down through the MAE-L mark. CROMA-L takes the SW sector;
  # MAE-L takes SE; SoftCon-B takes W/SW.
  lx = c(
    0.432, 0.445, 0.488, 0.485, 0.505,
    0.528, 0.522, 0.575, 0.598, 0.598,
    0.625, 0.518, 0.588
  ),
  ly = c(
    0.114, 0.188, 0.195, 0.155, 0.238,
    0.205, 0.122, 0.135, 0.105, 0.218,
    0.190, 0.258, 0.258
  ),
  hjust = c(
    0.5, 1, 1, 1, 1,
    1, 1, 0, 0, 0,
    0, 1, 0
  ),
  vjust = c(
    1, 0, 0, 1, 0,
    0, 1, 1, 1, 0,
    0, 0, 0
  ),
  stringsAsFactors = FALSE
)
d_lab <- merge(d, lab_pos, by = "label")
# Stop the leader short of the glyph so ink does not run under the letters.
shrink <- 0.78
d_lab$xend <- d_lab$mAP_in + shrink * (d_lab$lx - d_lab$mAP_in)
d_lab$yend <- d_lab$fnr_sh + shrink * (d_lab$ly - d_lab$fnr_sh)

f <- ggplot(d, aes(mAP_in, fnr_sh)) +
  # No OLS/trend line: the correlation is non-significant (p=0.28, n=13) and a fitted
  # line was judged to visually imply a trend the statistics do not support
  # (fixwave 2026-07-16, tutor review note 2). Points and the reported Spearman rho
  # are the only load-bearing content of this panel.
  geom_segment(data = d_lab,
               aes(x = mAP_in, y = fnr_sh, xend = xend, yend = yend),
               colour = "grey50", linewidth = 0.22, lineend = "round") +
  geom_point(aes(colour = arch, shape = roster), size = 2.6) +
  geom_text(data = d_lab,
            aes(x = lx, y = ly, label = label, hjust = hjust, vjust = vjust),
            size = lbl_size, colour = "black", family = PAPER_FONT) +
  scale_color_paper() +
  scale_shape_manual(values = c("original 5" = 16, "added (roster)" = 17)) +
  scale_x_continuous(limits = c(0.400, 0.650), expand = expansion(mult = 0)) +
  scale_y_continuous(limits = c(0.090, 0.275), expand = expansion(mult = 0)) +
  labs(x = "In-distribution mAP",
       y = expression(paste("FNR under shift (CRC, ", alpha, " = 0.05)")),
       colour = "backbone", shape = "roster",
       caption = lab_stat) +
  theme_paper() +
  theme(legend.position = "bottom", legend.box = "horizontal",
        legend.margin = margin(0, 0, 0, 0),
        plot.caption = element_text(size = 9, colour = "black", hjust = 0,
                                    family = PAPER_FONT, margin = margin(t = 4)))

# Larger device than the prior 5.22x3.55in so 13 labels have room at print width
# 0.82\\linewidth; smaller lbl_size keeps type readable after downscale.
save_fig(f, "figures/F7_ben_inversion_n13", w = 7.0, h = 5.0)
cat(sprintf("F7 written. n=%d, Spearman(FNR_sh, mAP) = %+.4f\n", nrow(d), rho))
