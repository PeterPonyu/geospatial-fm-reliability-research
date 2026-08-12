# n=13 BEN cross-encoder inversion scatter (FNR shift vs in-distribution mAP).
# Reads the frozen roster analysis CSV emitted by roster_analysis_2026-07-16
# (traced to bigearthnet_crc_arm_roster + ben_map_roster). House style: black
# text labels, colored marks reserved for architecture family.
# Run: cd manuscripts && Rscript figures/p3_roster_inversion.R
#
# Visual polish (2026-08-12, pass 2): prior 7.0x5.0 / lbl=2.5 layout printed too
# small at 0.82\\linewidth and pushed ResNet50-MoCo / SSL4EO-MAE-L into long
# callouts. Match polished single-panel GEO figures (theme_paper ~12,
# device nearer print width) with short manual leaders (no distant ggrepel).
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

# ggplot geom_text size (mm): 3.6 ≈ 10.2 pt — readable after 0.82\\linewidth scale.
lbl_size <- 3.6
pt_size  <- 3.15

# Short absolute anchors: each label sits in a local sector around its mark
# (clock slots in the mid/right cloud) so leaders stay short and do not cross.
# ResNets use lateral slots (not far N) so callouts stay flush with the marks.
#   Prithvi S | DOFA W | Clay NW | SoftCon-B W | SoftCon-S N
#   CROMA-B NW | CROMA-L SW | MAE SE | MAE-L S | DINO NE
#   MoCo E | ResNet-MoCo W | ResNet-DINO E
lab_pos <- data.frame(
  label = c(
    "Prithvi", "DOFA", "Clay", "SoftCon-ViT-B", "SoftCon-ViT-S",
    "CROMA-B", "CROMA-L", "SSL4EO-MAE", "SSL4EO-MAE-L", "SSL4EO-DINO",
    "SSL4EO-MoCo", "ResNet50-MoCo", "ResNet50-DINO"
  ),
  lx = c(
    0.432, 0.448, 0.492, 0.514, 0.514,
    0.535, 0.530, 0.560, 0.558, 0.570,
    0.592, 0.528, 0.568
  ),
  ly = c(
    0.120, 0.172, 0.184, 0.168, 0.224,
    0.190, 0.158, 0.162, 0.148, 0.200,
    0.174, 0.238, 0.236
  ),
  hjust = c(
    0.5, 1, 1, 1, 1,
    1, 1, 0, 0, 0,
    0, 1, 0
  ),
  vjust = c(
    1, 0.5, 0, 1, 0,
    0, 1, 1, 1, 0,
    0.5, 0.5, 0.5
  ),
  stringsAsFactors = FALSE
)
d_lab <- merge(d, lab_pos, by = "label")
# Stop the leader short of the glyph; keep most of the path (labels already near).
shrink <- 0.55
d_lab$xend <- d_lab$mAP_in + shrink * (d_lab$lx - d_lab$mAP_in)
d_lab$yend <- d_lab$fnr_sh + shrink * (d_lab$ly - d_lab$fnr_sh)

f <- ggplot(d, aes(mAP_in, fnr_sh)) +
  # No OLS/trend line: the correlation is non-significant (p=0.28, n=13) and a fitted
  # line was judged to visually imply a trend the statistics do not support
  # (fixwave 2026-07-16, tutor review note 2). Points and the reported Spearman rho
  # are the only load-bearing content of this panel.
  geom_segment(data = d_lab,
               aes(x = mAP_in, y = fnr_sh, xend = xend, yend = yend),
               colour = "grey50", linewidth = 0.30, lineend = "round") +
  geom_point(aes(colour = arch, shape = roster), size = pt_size) +
  geom_text(data = d_lab,
            aes(x = lx, y = ly, label = label, hjust = hjust, vjust = vjust),
            size = lbl_size, colour = "black", family = PAPER_FONT) +
  scale_color_paper() +
  scale_shape_manual(values = c("original 5" = 16, "added (roster)" = 17)) +
  scale_x_continuous(limits = c(0.405, 0.630), expand = expansion(mult = 0.01)) +
  scale_y_continuous(limits = c(0.100, 0.265), expand = expansion(mult = 0.01)) +
  labs(x = "In-distribution mAP",
       y = expression(paste("FNR under shift (CRC, ", alpha, " = 0.05)")),
       colour = "backbone", shape = "roster",
       caption = lab_stat) +
  theme_paper(base_size = 13) +
  theme(
    legend.position = "bottom",
    legend.box = "horizontal",
    legend.justification = "center",
    legend.box.just = "center",
    legend.margin = margin(t = 2, r = 0, b = 0, l = 0),
    legend.box.spacing = unit(5, "pt"),
    legend.key.width  = unit(12, "pt"),
    legend.key.height = unit(12, "pt"),
    legend.key.spacing.x = unit(6, "pt"),
    legend.text  = element_text(size = 11),
    legend.title = element_text(size = 11),
    axis.title   = element_text(size = 12),
    axis.text    = element_text(size = 11),
    # Center Spearman on the panel/legend column (not page-center, which
    # sits left of the scatter because of the y-axis title; not hjust=0,
    # which sat flush under the roster key).
    plot.caption.position = "panel",
    plot.caption = element_text(size = 9.5, colour = "grey30", hjust = 0.5,
                                family = PAPER_FONT, margin = margin(t = 6)),
    plot.margin  = margin(t = 6, r = 8, b = 4, l = 4)
  )

# Device nearer print width than the prior 7.0x5.0in so base_size=12 survives
# 0.82\\linewidth inclusion without looking undersized.
save_fig(f, "figures/F7_ben_inversion_n13", w = 5.85, h = 4.40)
cat(sprintf("F7 written. n=%d, Spearman(FNR_sh, mAP) = %+.4f\n", nrow(d), rho))
