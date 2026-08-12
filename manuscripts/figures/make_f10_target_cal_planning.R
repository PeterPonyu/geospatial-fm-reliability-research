# F10_target_cal_planning — target-recalibration planning curves (frozen JSON).
# Run from manuscripts/: Rscript figures/make_f10_target_cal_planning.R
#
# Science identical to experiments/target_calplanning_2026-08-01/make_planning_figure.py:
#   A EuroSAT P33 α=0.10 coverage vs target-calibration fraction
#   B BigEarthNet CRC FNR vs fraction (vacuous CRC budgets omitted)
#   C EuroSAT P33 α=0.05 coverage
#   D fraction of coverage debt repaired (α=0.05; material debt ≥1pp; shaded seed CI)
# House style: bold A–D tags, Nimbus Roman, Okabe–Ito MODEL_COLOURS, shared legend.

source("figures/ggtheme.R")

ROOT <- ".."
RES <- file.path(ROOT, "experiments/target_calplanning_2026-08-01/results.json")
OUT <- "figures/F10_target_cal_planning"
BOUNDARY <- "P33"
MATERIAL_DEBT <- 0.01

fkey <- function(frac) sprintf("%.3f", frac)

fm_map <- c(
  prithvi = "Prithvi",
  ssl4eo = "SSL4EO-DINO",
  clay = "Clay",
  ssl4eo_mae = "SSL4EO-MAE"
)
fm_levels <- c("Prithvi", "SSL4EO-DINO", "Clay", "SSL4EO-MAE")
# Marker identity matches the frozen Python figure (shape only; colour from MODEL_COLOURS).
fm_shape <- c(Prithvi = 16, `SSL4EO-DINO` = 15, Clay = 17, `SSL4EO-MAE` = 18)

theme_f10 <- function() {
  theme_paper(base_size = 10) +
    theme(
      axis.title = element_text(size = 9),
      axis.text  = element_text(size = 8),
      legend.text = element_text(size = 8),
      legend.title = element_text(size = 8),
      plot.title = element_text(size = 9, hjust = 0.5),
      legend.position = "none",
      legend.box.spacing = unit(1, "pt"),
      legend.margin = margin(t = 0, r = 0, b = 0, l = 0),
      plot.margin = margin(t = 2, r = 4, b = 2, l = 2)
    )
}
tag_f10 <- function() paper_tag_theme(base_size = 13)

res <- read_result(RES)
stopifnot(!is.null(res$eurosat), !is.null(res$bigearthnet))

eurosat_cov_df <- function(alpha) {
  akey <- sprintf("%.2f", alpha)
  rows <- list()
  base_rows <- list()
  for (fm in names(fm_map)) {
    blk <- res$eurosat[[fm]]
    if (is.null(blk) || is.null(blk$boundaries[[BOUNDARY]])) next
    cell <- blk$boundaries[[BOUNDARY]]$cells[[akey]]
    if (is.null(cell)) next
    lab <- fm_map[[fm]]
    fracs <- sort(as.numeric(names(cell$curve)))
    for (f in fracs) {
      pt <- cell$curve[[fkey(f)]]
      rows[[length(rows) + 1L]] <- data.frame(
        fm = lab, frac_pct = f * 100,
        coverage = as.numeric(pt$coverage$mean),
        stringsAsFactors = FALSE
      )
    }
    base_rows[[length(base_rows) + 1L]] <- data.frame(
      fm = lab,
      split_cov = as.numeric(cell$conformal_split$coverage$mean),
      stringsAsFactors = FALSE
    )
  }
  list(
    curve = do.call(rbind, rows),
    baseline = do.call(rbind, base_rows),
    nominal = 1 - alpha
  )
}

draw_eurosat <- function(alpha, title) {
  d <- eurosat_cov_df(alpha)
  d$curve$fm <- factor(d$curve$fm, levels = fm_levels)
  d$baseline$fm <- factor(d$baseline$fm, levels = fm_levels)
  nom_lab <- sprintf("nominal 1 − α = %.2f", d$nominal)
  ggplot(d$curve, aes(frac_pct, coverage, colour = fm, shape = fm, group = fm)) +
    geom_hline(data = d$baseline, aes(yintercept = split_cov, colour = fm),
               linetype = "22", linewidth = 0.45, alpha = 0.8, show.legend = FALSE) +
    geom_hline(yintercept = d$nominal, colour = "black", linewidth = 0.55) +
    geom_line(linewidth = 0.55) +
    geom_point(size = 1.7) +
    annotate("text", x = 31.5, y = d$nominal, label = nom_lab,
             hjust = 1, vjust = 1.4, size = 2.9, family = PAPER_FONT) +
    scale_colour_model(drop = FALSE) +
    scale_shape_manual(values = fm_shape, drop = FALSE) +
    scale_x_continuous(breaks = seq(0, 30, 5), limits = c(0, 32),
                       expand = expansion(mult = c(0.01, 0.02))) +
    labs(x = "target-calibration fraction (%)", y = "marginal coverage",
         title = title) +
    theme_f10()
}

ben_df <- function(alpha = 0.10) {
  akey <- sprintf("%.2f", alpha)
  rows <- list()
  base_rows <- list()
  for (fm in names(fm_map)) {
    blk <- res$bigearthnet[[fm]]
    if (is.null(blk) || is.null(blk$cells[[akey]])) next
    cell <- blk$cells[[akey]]
    lab <- fm_map[[fm]]
    fracs <- sort(as.numeric(names(cell$curve)))
    for (f in fracs) {
      pt <- cell$curve[[fkey(f)]]
      attainable <- pt$all_seeds_crc_attainable
      if (is.null(attainable)) attainable <- TRUE
      if (!isTRUE(attainable)) next
      rows[[length(rows) + 1L]] <- data.frame(
        fm = lab, frac_pct = f * 100,
        fnr = as.numeric(pt$fnr$mean),
        stringsAsFactors = FALSE
      )
    }
    base_rows[[length(base_rows) + 1L]] <- data.frame(
      fm = lab,
      src_fnr = as.numeric(cell$crc_source$fnr$mean),
      stringsAsFactors = FALSE
    )
  }
  list(curve = do.call(rbind, rows), baseline = do.call(rbind, base_rows),
       target = alpha)
}

draw_ben <- function(alpha = 0.10) {
  d <- ben_df(alpha)
  d$curve$fm <- factor(d$curve$fm, levels = fm_levels)
  d$baseline$fm <- factor(d$baseline$fm, levels = fm_levels)
  tgt_lab <- sprintf("target FNR α = %.2f", d$target)
  ggplot(d$curve, aes(frac_pct, fnr, colour = fm, shape = fm, group = fm)) +
    geom_hline(data = d$baseline, aes(yintercept = src_fnr, colour = fm),
               linetype = "22", linewidth = 0.45, alpha = 0.8, show.legend = FALSE) +
    geom_hline(yintercept = d$target, colour = "black", linewidth = 0.55) +
    geom_line(linewidth = 0.55) +
    geom_point(size = 1.7) +
    annotate("text", x = 31.5, y = d$target, label = tgt_lab,
             hjust = 1, vjust = -0.5, size = 2.9, family = PAPER_FONT) +
    scale_colour_model(drop = FALSE) +
    scale_shape_manual(values = fm_shape, drop = FALSE) +
    scale_x_continuous(breaks = seq(0, 30, 5), limits = c(0, 32),
                       expand = expansion(mult = c(0.01, 0.02))) +
    labs(x = "target-calibration fraction (%)",
         y = "CRC example-averaged FNR",
         title = sprintf("BigEarthNet-S2 (α = %.2f)", alpha)) +
    theme_f10()
}

debt_df <- function(alpha = 0.05) {
  akey <- sprintf("%.2f", alpha)
  rows <- list()
  for (fm in names(fm_map)) {
    blk <- res$eurosat[[fm]]
    if (is.null(blk) || is.null(blk$boundaries[[BOUNDARY]])) next
    cell <- blk$boundaries[[BOUNDARY]]$cells[[akey]]
    if (is.null(cell)) next
    split <- as.numeric(cell$conformal_split$coverage$mean)
    debt <- (1 - alpha) - split
    lab <- fm_map[[fm]]
    if (debt <= 0) {
      cat(sprintf("[WARN] eurosat/%s a=%s: no debt (split=%.4f), dropped from D\n",
                  fm, akey, split))
      next
    }
    if (debt < MATERIAL_DEBT) {
      cat(sprintf("[WARN] eurosat/%s a=%s: debt %.2fpp below floor, dropped from D\n",
                  fm, akey, debt * 100))
      next
    }
    fracs <- sort(as.numeric(names(cell$curve)))
    for (f in fracs) {
      pt <- cell$curve[[fkey(f)]]$frac_debt_repaired
      if (is.null(pt)) next
      rows[[length(rows) + 1L]] <- data.frame(
        fm = lab, frac_pct = f * 100,
        mean = as.numeric(pt$mean),
        lo = as.numeric(pt$ci_low),
        hi = as.numeric(pt$ci_high),
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

draw_debt <- function(alpha = 0.05) {
  d <- debt_df(alpha)
  d$fm <- factor(d$fm, levels = fm_levels)
  ggplot(d, aes(frac_pct, mean, colour = fm, shape = fm, group = fm, fill = fm)) +
    geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.15, colour = NA,
                show.legend = FALSE) +
    geom_hline(yintercept = 1.0, colour = "black", linewidth = 0.55) +
    geom_line(linewidth = 0.55) +
    geom_point(size = 1.7) +
    # Far-right, under seed-CI floor (min lo≈0.82 at x≥20): left-above y=1
    # overlapped low-x markers/ribbons; sitting just under the rule clips CI.
    annotate("text", x = 31.5, y = 0.65, label = "debt exactly closed",
             hjust = 1, vjust = 0.5, size = 2.9, family = PAPER_FONT) +
    scale_colour_model(drop = FALSE) +
    scale_fill_model(drop = FALSE) +
    scale_shape_manual(values = fm_shape, drop = FALSE) +
    scale_x_continuous(breaks = seq(0, 30, 5), limits = c(0, 32),
                       expand = expansion(mult = c(0.01, 0.02))) +
    labs(x = "target-calibration fraction (%)",
         y = "fraction of debt repaired",
         # Short title: prior "shaded = seed CI" clipped at the panel edge.
         title = sprintf("Debt repaired (α = %.2f)", alpha)) +
    theme_f10()
}

# Shared legend panel. Colour-only aes (shape/linetype via override.aes):
# mapping colour+shape+linetype under ggplot2 4 left a labeled row plus a second
# unlabeled handle row; "source-only (no target labels)" also clipped at the edge.
SRC_LAB <- "source-only (no target)"
leg_levels <- c(fm_levels, SRC_LAB)
col_leg <- c(MODEL_COLOURS[fm_levels], setNames("#555555", SRC_LAB))
shp_override <- c(unname(fm_shape[fm_levels]), NA_real_)
lty_override <- c(rep("solid", length(fm_levels)), "22")

leg_pts <- data.frame(
  kind = factor(fm_levels, levels = leg_levels),
  x = seq_along(fm_levels), y = 1,
  stringsAsFactors = FALSE
)
leg_src <- data.frame(
  kind = factor(SRC_LAB, levels = leg_levels),
  x = c(0.7, 1.3), y = 1,
  stringsAsFactors = FALSE
)
p_leg <- ggplot() +
  geom_line(data = leg_src, aes(x, y, colour = kind, group = kind),
            linewidth = 0.55, linetype = "22") +
  geom_point(data = leg_pts, aes(x, y, colour = kind, shape = kind),
             size = 1.8, alpha = 0) +
  scale_colour_manual(values = col_leg, breaks = leg_levels, name = NULL,
                      drop = FALSE) +
  scale_shape_manual(values = fm_shape, breaks = fm_levels, name = NULL,
                     drop = FALSE) +
  guides(
    colour = guide_legend(
      nrow = 1, title = NULL,
      override.aes = list(
        shape = shp_override,
        linetype = lty_override,
        linewidth = 0.55,
        alpha = 1
      )
    ),
    shape = "none"
  ) +
  theme_void(base_family = PAPER_FONT) +
  theme(
    legend.position = "bottom",
    legend.direction = "horizontal",
    legend.justification = "center",
    legend.text = element_text(size = 7.0, family = PAPER_FONT),
    legend.key.width = unit(10, "pt"),
    legend.key.height = unit(7, "pt"),
    legend.key.spacing.x = unit(2.5, "pt"),
    legend.margin = margin(t = 0, r = 2, b = 0, l = 2),
    legend.box.margin = margin(0, 0, 0, 0),
    legend.box.spacing = unit(0, "pt"),
    legend.background = element_blank(),
    legend.box.background = element_blank(),
    plot.margin = margin(0, 0, 0, 0)
  )

pA <- draw_eurosat(0.10, expression(EuroSAT ~ (P[33] * "," ~ alpha == 0.10)))
pB <- draw_ben(0.10)
pC <- draw_eurosat(0.05, expression(EuroSAT ~ (P[33] * "," ~ alpha == 0.05)))
pD <- draw_debt(0.05)

f10_all <- ((pA | pB) / (pC | pD) / p_leg) +
  plot_layout(heights = c(1, 1, 0.12), guides = "keep") +
  plot_annotation(tag_levels = "A") & tag_f10()
f10_all[[3]] <- f10_all[[3]] + theme(plot.tag = element_blank())

prov_n <- function(tag, dfx) {
  cat(sprintf("[%s] source=target_calplanning_2026-08-01/results.json rows=%d series=%d\n",
              tag, nrow(dfx), length(unique(dfx$fm))))
}
prov_n("F10-A", eurosat_cov_df(0.10)$curve)
prov_n("F10-B", ben_df(0.10)$curve)
prov_n("F10-C", eurosat_cov_df(0.05)$curve)
prov_n("F10-D", debt_df(0.05))

# Slightly wider so the five-entry floor clears the right edge.
save_fig(f10_all, OUT, w = 5.15, h = 4.55)
cat(sprintf("[write] %s.pdf / .png\n", OUT))
