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

# Shared legend strip as a manual grid grob (not ggplot guides).
# ggplot2 4 colour/shape/linetype guides leave a labeled row plus a ghost
# unlabeled handle; a dummy geom_line in the strip also drew a stray dashed
# tick above Prithvi. Two labeled rows: encoders, then source-only.
SRC_LAB <- "source-only (no target)"
col_leg <- c(MODEL_COLOURS[fm_levels], setNames("#555555", SRC_LAB))

# Open a throwaway cairo device so stringWidth uses Nimbus Roman metrics.
grDevices::cairo_pdf(tempfile(fileext = ".pdf"), width = 5, height = 1,
                     family = PAPER_FONT)

encoder_item <- function(lab) {
  col <- unname(col_leg[[lab]])
  shp <- unname(fm_shape[[lab]])
  glyph <- grid::pointsGrob(
    x = grid::unit(1.6, "mm"), y = grid::unit(0.5, "npc"),
    pch = shp, size = grid::unit(1.5, "mm"),
    gp = grid::gpar(col = col, fill = col)
  )
  label <- grid::textGrob(
    lab, x = grid::unit(3.4, "mm"), y = grid::unit(0.5, "npc"), just = "left",
    gp = grid::gpar(fontfamily = PAPER_FONT, fontsize = 7.2, col = "black")
  )
  w <- grid::stringWidth(lab) + grid::unit(4.0, "mm")
  grid::gTree(
    children = grid::gList(glyph, label),
    vp = grid::viewport(width = w, height = grid::unit(3.8, "mm"))
  )
}

src_item <- {
  col <- unname(col_leg[[SRC_LAB]])
  glyph <- grid::linesGrob(
    x = grid::unit(c(0.4, 4.2), "mm"), y = grid::unit(c(0.5, 0.5), "npc"),
    gp = grid::gpar(col = col, lty = 2, lwd = 1.3, lineend = "butt")
  )
  label <- grid::textGrob(
    SRC_LAB, x = grid::unit(5.0, "mm"), y = grid::unit(0.5, "npc"), just = "left",
    gp = grid::gpar(fontfamily = PAPER_FONT, fontsize = 7.2, col = "black")
  )
  w <- grid::stringWidth(SRC_LAB) + grid::unit(5.6, "mm")
  grid::gTree(
    children = grid::gList(glyph, label),
    vp = grid::viewport(width = w, height = grid::unit(3.8, "mm"))
  )
}

enc_grobs <- lapply(fm_levels, encoder_item)
enc_widths <- lapply(fm_levels, function(lab) {
  grid::stringWidth(lab) + grid::unit(4.0, "mm")
})
src_width <- grid::stringWidth(SRC_LAB) + grid::unit(5.6, "mm")
grDevices::dev.off()

pack_row <- function(grobs, widths, gap_mm = 2.0) {
  gap <- grid::unit(gap_mm, "mm")
  children <- lapply(seq_along(grobs), function(i) {
    xoff <- if (i == 1L) {
      grid::unit(0, "mm")
    } else {
      Reduce(`+`, widths[seq_len(i - 1L)]) + gap * (i - 1L)
    }
    grid::gTree(
      children = grobs[[i]]$children,
      vp = grid::viewport(
        x = xoff, y = grid::unit(0.5, "npc"), just = "left",
        width = widths[[i]], height = grid::unit(3.8, "mm")
      )
    )
  })
  total <- Reduce(`+`, widths) + gap * (length(widths) - 1L)
  grid::gTree(
    children = do.call(grid::gList, children),
    vp = grid::viewport(width = total, height = grid::unit(4.0, "mm"),
                        just = "centre")
  )
}

# Row 1: four encoders. Row 2: one labeled source-only key (no ggplot ghost).
row1 <- pack_row(enc_grobs, enc_widths, gap_mm = 2.4)
row2 <- pack_row(list(src_item), list(src_width), gap_mm = 0)
leg_stack <- grid::gTree(children = grid::gList(
  grid::gTree(children = grid::gList(row1),
              vp = grid::viewport(y = grid::unit(0.72, "npc"),
                                  height = grid::unit(4.2, "mm"))),
  grid::gTree(children = grid::gList(row2),
              vp = grid::viewport(y = grid::unit(0.28, "npc"),
                                  height = grid::unit(4.2, "mm")))
))
p_leg <- wrap_elements(full = cowplot::ggdraw() +
  cowplot::draw_grob(leg_stack, x = 0.5, y = 0.50,
                     hjust = 0.5, vjust = 0.5, width = 0.96, height = 0.9))

pA <- draw_eurosat(0.10, expression(EuroSAT ~ (P[33] * "," ~ alpha == 0.10)))
pB <- draw_ben(0.10)
pC <- draw_eurosat(0.05, expression(EuroSAT ~ (P[33] * "," ~ alpha == 0.05)))
pD <- draw_debt(0.05)

f10_all <- ((pA | pB) / (pC | pD) / p_leg) +
  plot_layout(heights = c(1, 1, 0.14), guides = "keep") +
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
