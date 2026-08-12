# Expand GEO ISPRS figures F11--F14 from frozen table-backed JSON only.
# Run: cd manuscripts && Rscript figures/make_expand_figures_2026_08_12.R
# Optional: Rscript figures/make_expand_figures_2026_08_12.R F12   # only one stem
#
# Sources (never modified here):
#   F11: exp0_2026-07-13/results.json (test_B) +
#        so2sat_roster_stage_2026-07-13/perclass_conditional_summary.json
#   F12: exp0_2026-07-13/lowshot_results.json
#   F13: experiments/results/bigearthnet_crc_arm-exec-2026-06-29.json
#   F14: experiments/results/eurosat_stage2_multifm_multialpha/
#        recompute_class_prior_balanced_control_2026-07-01.json

source("figures/ggtheme.R")
args <- commandArgs(trailingOnly = TRUE)
ONLY <- if (length(args) >= 1L) toupper(sub("^F?", "F", args[[1]])) else ""
do_fig <- function(stem) ONLY == "" || identical(ONLY, stem)

ROOT <- ".."
EXP0 <- file.path(ROOT, "exp0_2026-07-13")
SO2  <- file.path(ROOT, "so2sat_roster_stage_2026-07-13",
                  "perclass_conditional_summary.json")
CRC  <- file.path(ROOT, "experiments/results",
                  "bigearthnet_crc_arm-exec-2026-06-29.json")
PRIOR <- file.path(ROOT, "experiments/results/eurosat_stage2_multifm_multialpha",
                   "recompute_class_prior_balanced_control_2026-07-01.json")

fm_lab <- c(prithvi = "Prithvi", clay = "Clay", ssl4eo = "SSL4EO-DINO",
            ssl4eo_dino = "SSL4EO-DINO", ssl4eo_mae = "SSL4EO-MAE", dofa = "DOFA")
lab_of <- function(k) if (!is.null(fm_lab[[k]])) fm_lab[[k]] else k

getm <- function(x) {
  if (is.null(x)) return(NA_real_)
  if (is.list(x) && !is.null(x$mean)) return(as.numeric(x$mean))
  as.numeric(x)
}
getlo <- function(x) {
  if (is.null(x) || !is.list(x) || is.null(x$ci_low)) return(NA_real_)
  as.numeric(x$ci_low)
}
gethi <- function(x) {
  if (is.null(x) || !is.list(x) || is.null(x$ci_high)) return(NA_real_)
  as.numeric(x$ci_high)
}
src_id <- function(path) {
  p <- normalizePath(path, mustWork = FALSE)
  file.path(basename(dirname(p)), basename(p))
}
prov <- function(tag, path, dfx, series_col) {
  cat(sprintf("[%s] source=%s rows=%d series=%d\n", tag, src_id(path),
              nrow(dfx), length(unique(dfx[[series_col]]))))
}

# Compact typography for the 4.75×3.69 expand 2×2 panels: panel tags are the
# largest text; axis titles / ticks / legends stay in a narrow 7–8 pt band.
# (theme_paper(base_size=11) made rotated y-titles visually dominate the tags.)
theme_expand <- function() {
  theme_paper(base_size = 8) +
    theme(
      axis.title = element_text(size = 6.5),
      axis.text  = element_text(size = 6.5),
      legend.text = element_text(size = 6.5),
      legend.title = element_text(size = 6.5),
      strip.text = element_text(size = 6.5),
      axis.title.x = element_text(margin = margin(t = 0)),
      axis.title.y = element_text(margin = margin(r = 1))
    )
}
# Tags inside the panel corner (not margin) so they read as the largest type.
tag_expand <- function() {
  theme(text = element_text(family = PAPER_FONT),
        plot.tag = element_text(family = PAPER_FONT, face = "bold",
                                size = 14, hjust = 0, vjust = 1),
        plot.tag.position = c(0.02, 0.98),
        plot.tag.location = "panel",
        plot.margin = margin(t = 2, r = 3, b = 1, l = 1))
}

# ---------------------------------------------------------------------------
# F11 — conditional coverage (mirrors tab:condcov / tab:so2satcond)
# ---------------------------------------------------------------------------
if (do_fig("F11")) {
exp0 <- read_result(file.path(EXP0, "results.json"))
tb <- exp0$test_B_eurosat_conditional_coverage$per_alpha[["0.05"]]
stopifnot(!is.null(tb$per_encoder))

gap_rows <- lapply(names(tb$per_encoder), function(fm) {
  e <- tb$per_encoder[[fm]]
  data.frame(fm = lab_of(fm), worst_gap = as.numeric(e$worst_class_gap),
             worst_cov = as.numeric(e$worst_class_cov),
             marg_cov = as.numeric(e$marg_cov),
             acc = as.numeric(e$acc_sh), ece = as.numeric(e$ece_sh),
             stringsAsFactors = FALSE)
})
gapdf <- do.call(rbind, gap_rows)
gapdf <- gapdf[order(gapdf$worst_gap), ]
gapdf$fm <- factor(gapdf$fm, levels = gapdf$fm)

# Panel A: EuroSAT worst-class gaps (table numbers); α detail in LaTeX caption
f11a <- ggplot(gapdf, aes(fm, worst_gap, fill = fm)) +
  geom_col(width = 0.72, colour = "grey30", linewidth = 0.2) +
  geom_hline(yintercept = 0, colour = "grey40") +
  scale_fill_model() +
  labs(x = NULL, y = "worst-class gap") +
  theme_expand() +
  theme(legend.position = "none",
        axis.text.x = element_text(angle = 25, hjust = 1, size = 7))
prov("F11-A", file.path(EXP0, "results.json"), gapdf, "fm")

# Panel B: per-class bars for SSL4EO-DINO (smoking-gun encoder in tab:condcov)
ssl <- tb$per_encoder$ssl4eo
pc <- ssl$per_class_cov
pcdf <- data.frame(
  class = factor(names(pc), levels = names(pc)),
  cov = as.numeric(unlist(pc)),
  stringsAsFactors = FALSE)
f11b <- ggplot(pcdf, aes(class, cov)) +
  geom_col(width = 0.72, fill = MODEL_COLOURS[["SSL4EO-DINO"]],
           colour = "grey30", linewidth = 0.2) +
  geom_hline(yintercept = as.numeric(ssl$marg_cov), linetype = 2, colour = "grey30") +
  geom_hline(yintercept = 0.95, linetype = 3, colour = "grey50") +
  coord_cartesian(ylim = c(0.80, 1.0)) +
  labs(x = "EuroSAT class id", y = "per-class cov") +
  theme_expand() +
  theme(panel.grid.major.x = element_blank())
prov("F11-B", file.path(EXP0, "results.json"), pcdf, "class")

# Panel C: So2Sat dissociation (worst-class vs marginal)
s2 <- read_result(SO2)
s2_rows <- lapply(names(s2$per_encoder), function(fm) {
  e <- s2$per_encoder[[fm]]
  data.frame(fm = lab_of(fm),
             marg = as.numeric(e$marginal_cov),
             worst = as.numeric(e$worst_class_cov),
             spread = as.numeric(e$class_spread),
             stringsAsFactors = FALSE)
})
s2df <- do.call(rbind, s2_rows)
s2m <- rbind(
  data.frame(fm = s2df$fm, arm = "marginal", cov = s2df$marg),
  data.frame(fm = s2df$fm, arm = "worst class", cov = s2df$worst))
s2m$arm <- factor(s2m$arm, levels = c("marginal", "worst class"))
s2m$fm <- factor(s2m$fm, levels = c("Prithvi", "Clay", "SSL4EO-DINO",
                                    "SSL4EO-MAE", "DOFA"))
f11c <- ggplot(s2m, aes(fm, cov, fill = arm)) +
  geom_col(position = position_dodge(0.78), width = 0.7,
           colour = "grey30", linewidth = 0.15) +
  geom_hline(yintercept = 0.95, linetype = 3, colour = "grey50") +
  scale_fill_paper() +
  coord_cartesian(ylim = c(0.65, 1.0)) +
  labs(x = NULL, y = "So2Sat coverage") +
  guides(fill = guide_legend(ncol = 1, title = NULL)) +
  theme_expand() +
  theme(axis.text.x = element_text(angle = 25, hjust = 1, size = 7),
        panel.grid.major.x = element_blank(),
        legend.position = "bottom",
        legend.direction = "vertical",
        legend.justification = "left",
        legend.box.spacing = unit(1, "pt"),
        legend.margin = margin(t = 0, r = 0, b = 0, l = 0),
        legend.key.spacing.y = unit(0, "pt"))
prov("F11-C", SO2, s2m, "fm")

# Panel D: encoder comparison — EuroSAT worst gap vs So2Sat class spread
cmp <- merge(
  data.frame(fm = gapdf$fm, eurosat_gap = gapdf$worst_gap),
  data.frame(fm = s2df$fm, so2sat_spread = s2df$spread),
  by = "fm")
# Fixed label anchors (F7-style) for the left cluster + DINO outlier.
lab_pos <- data.frame(
  fm = c("DOFA", "SSL4EO-MAE", "Prithvi", "Clay", "SSL4EO-DINO"),
  lx = c(0.032, 0.028, 0.058, 0.072, 0.086),
  ly = c(0.246, 0.286, 0.278, 0.252, 0.290),
  stringsAsFactors = FALSE)
cmp_lab <- merge(cmp, lab_pos, by = "fm")
f11d <- ggplot(cmp, aes(eurosat_gap, so2sat_spread, colour = fm)) +
  geom_segment(data = cmp_lab,
               aes(x = eurosat_gap, y = so2sat_spread, xend = lx, yend = ly),
               colour = "grey50", linewidth = 0.22, lineend = "round",
               show.legend = FALSE) +
  geom_point(size = 2.3) +
  geom_text(data = cmp_lab,
            aes(x = lx, y = ly, label = fm),
            size = 1.7, colour = "black", family = PAPER_FONT,
            show.legend = FALSE) +
  scale_color_model() +
  coord_cartesian(xlim = c(0.018, 0.112), ylim = c(0.240, 0.314),
                  expand = FALSE) +
  labs(x = "EuroSAT worst-class gap", y = "So2Sat class spread") +
  theme_expand() +
  theme(legend.position = "none",
        axis.title.x = element_text(margin = margin(t = 0, b = 0)),
        plot.margin = margin(t = 3, r = 4, b = 0, l = 2))
prov("F11-D", file.path(EXP0, "results.json"), cmp, "fm")

# Legend cell under C only (design E#). Keep D out of the legend row so its
# x-title is not padded by C's legend height; leave # empty under D.
f11c_noleg <- f11c + theme(legend.position = "none")
leg_plot <- f11c +
  guides(fill = guide_legend(ncol = 1, title = NULL,
                             override.aes = list(colour = NA))) +
  theme(legend.position = "right",
        legend.direction = "vertical",
        legend.justification = "left",
        legend.key.spacing.y = unit(1, "pt"),
        legend.margin = margin(0, 0, 0, 0),
        legend.background = element_blank())
f11_leg <- wrap_elements(full = cowplot::get_legend(leg_plot))
f11_all <- f11a + f11b + f11c_noleg + f11d + f11_leg +
  plot_layout(design = "AB\nCD\nE#", heights = c(1, 1, 0.18)) +
  plot_annotation(tag_levels = list(c("A", "B", "C", "D", ""))) &
  tag_expand()
save_fig(f11_all, "figures/F11_conditional_coverage", w = 4.75, h = 3.55)
}  # end F11

# ---------------------------------------------------------------------------
# F12 — singleton / low-shot boundary (mirrors tab:singleton)
# ---------------------------------------------------------------------------
if (do_fig("F12")) {
ls <- read_result(file.path(EXP0, "lowshot_results.json"))
ls_rows <- list()
for (fm in names(ls$encoders)) {
  for (a in names(ls$encoders[[fm]])) {
    for (row in ls$encoders[[fm]][[a]]) {
      ls_rows[[length(ls_rows) + 1]] <- data.frame(
        fm = lab_of(fm), alpha = as.numeric(a),
        frac = as.numeric(row$frac),
        train_n = as.numeric(row$train_n),
        acc = as.numeric(row$acc_sh),
        ss = as.numeric(row$ss_sh),
        cov_minus_acc = as.numeric(row$cov_minus_acc),
        worst_gap = as.numeric(row$worst_gap),
        stringsAsFactors = FALSE)
    }
  }
}
lsdf <- do.call(rbind, ls_rows)
# Table uses Prithvi α=0.05; keep that series primary in A–C.
p05 <- lsdf[lsdf$fm == "Prithvi" & abs(lsdf$alpha - 0.05) < 1e-9, ]
p05 <- p05[order(p05$frac), ]

# Log-x: keep fraction honesty; label only sparse majors (match panel D).
# Minor ticks at the omitted fracs stay unmarked so A–C are readable.
f12_x <- function() {
  scale_x_continuous(
    trans = "log10",
    breaks = c(0.01, 0.05, 0.25, 1),
    minor_breaks = c(0.02, 0.1, 0.5),
    labels = c("0.01", "0.05", "0.25", "1")
  )
}

f12a <- ggplot(p05, aes(frac, cov_minus_acc)) +
  geom_hline(yintercept = 0, colour = "grey50") +
  geom_line(linewidth = 0.45, colour = MODEL_COLOURS[["Prithvi"]]) +
  geom_point(size = 2.0, colour = MODEL_COLOURS[["Prithvi"]]) +
  f12_x() +
  labs(x = "probe-train fraction", y = "coverage − accuracy") +
  theme_expand()
prov("F12-A", file.path(EXP0, "lowshot_results.json"), p05, "frac")

f12b <- ggplot(p05, aes(frac, ss)) +
  geom_hline(yintercept = 1, linetype = 3, colour = "grey40") +
  geom_line(linewidth = 0.45, colour = MODEL_COLOURS[["Prithvi"]]) +
  geom_point(size = 2.0, colour = MODEL_COLOURS[["Prithvi"]]) +
  f12_x() +
  labs(x = "probe-train fraction", y = "split set size") +
  theme_expand()
prov("F12-B", file.path(EXP0, "lowshot_results.json"), p05, "frac")

f12c <- ggplot(p05, aes(frac, worst_gap)) +
  geom_line(linewidth = 0.45, colour = MODEL_COLOURS[["Prithvi"]]) +
  geom_point(size = 2.0, colour = MODEL_COLOURS[["Prithvi"]]) +
  f12_x() +
  labs(x = "probe-train fraction", y = "worst-class gap") +
  theme_expand()
prov("F12-C", file.path(EXP0, "lowshot_results.json"), p05, "frac")

# Panel D: α comparison (0.05 vs 0.10) for all three encoders — cov−acc
lsdf$alpha_lab <- sprintf("α = %.2f", lsdf$alpha)
f12d <- ggplot(lsdf, aes(frac, cov_minus_acc, colour = fm, linetype = alpha_lab,
                         group = interaction(fm, alpha))) +
  geom_hline(yintercept = 0, colour = "grey50") +
  geom_line(linewidth = 0.4) +
  geom_point(size = 1.5) +
  scale_color_model() +
  f12_x() +
  labs(x = "probe-train fraction", y = "coverage − accuracy") +
  guides(colour = guide_legend(nrow = 1, title = NULL, order = 1),
         linetype = guide_legend(nrow = 1, title = NULL, order = 2)) +
  theme_expand() +
  theme(legend.box = "vertical",
        legend.spacing.y = unit(1, "pt"))
prov("F12-D", file.path(EXP0, "lowshot_results.json"), lsdf, "fm")

f12_all <- (f12a | f12b) / (f12c | f12d) +
  plot_annotation(tag_levels = "A") & tag_expand()
save_fig(f12_all, "figures/F12_singleton_lowshot", w = 4.75, h = 3.85)
}  # end F12

# ---------------------------------------------------------------------------
# F13 — CRC FNR (mirrors tab:crc)
# Equal 2×2 outer panels: A = in vs shift at α=0.05 (no α-facet);
# B/C = Mondrian restore + set-size at α=0.10; D = α sweep of shift FNR.
# One shared fill legend for B+C; A and D keep their own (collected once).
# ---------------------------------------------------------------------------
if (do_fig("F13")) {
crc <- read_result(CRC)
crc_rows <- list()
for (fm in names(crc$fm_results)) {
  for (a in names(crc$fm_results[[fm]]$per_alpha)) {
    cell <- crc$fm_results[[fm]]$per_alpha[[a]]
    boot <- cell$bootstrap
    stopifnot(!is.null(boot$fnr_in_crc), !is.null(boot$fnr_sh_crc),
              !is.null(boot$fnr_sh_mond), !is.null(boot$ss_sh_crc),
              !is.null(boot$ss_sh_mond))
    crc_rows[[length(crc_rows) + 1]] <- data.frame(
      fm = lab_of(fm), alpha = as.numeric(a),
      fnr_in = getm(boot$fnr_in_crc), fnr_in_lo = getlo(boot$fnr_in_crc),
      fnr_in_hi = gethi(boot$fnr_in_crc),
      fnr_sh = getm(boot$fnr_sh_crc), fnr_sh_lo = getlo(boot$fnr_sh_crc),
      fnr_sh_hi = gethi(boot$fnr_sh_crc),
      fnr_mond = getm(boot$fnr_sh_mond), fnr_mond_lo = getlo(boot$fnr_sh_mond),
      fnr_mond_hi = gethi(boot$fnr_sh_mond),
      ss_crc = getm(boot$ss_sh_crc), ss_crc_lo = getlo(boot$ss_sh_crc),
      ss_crc_hi = gethi(boot$ss_sh_crc),
      ss_mond = getm(boot$ss_sh_mond), ss_mond_lo = getlo(boot$ss_sh_mond),
      ss_mond_hi = gethi(boot$ss_sh_mond),
      lambda = getm(cell$lambda_crc_src_CI),
      lambda_lo = getlo(cell$lambda_crc_src_CI),
      lambda_hi = gethi(cell$lambda_crc_src_CI),
      stringsAsFactors = FALSE)
  }
}
crcdf <- do.call(rbind, crc_rows)
fm_lvls <- c("Prithvi", "Clay", "SSL4EO-DINO", "SSL4EO-MAE", "DOFA")
fm_tick <- c(Prithvi = "Prithvi", Clay = "Clay",
             `SSL4EO-DINO` = "DINO", `SSL4EO-MAE` = "MAE", DOFA = "DOFA")
crcdf$fm <- factor(crcdf$fm, levels = fm_lvls)
# Shared Okabe–Ito fills for A (regime) vs B/C (method); named so collect merges.
# Keep bar fills distinct from Panel-D model colours (Clay=blue, Prithvi=teal).
fill_regime <- c("in-dist" = "#56B4E9", "shift" = okabe_ito[4])
fill_method <- c("CRC" = "#E69F00", "Mondrian-CRC" = "#009E73")

# Panel A: CRC in-dist vs shift at α=0.05 only (α sweep lives in D)
a05 <- crcdf[abs(crcdf$alpha - 0.05) < 1e-9, ]
a_long <- rbind(
  data.frame(fm = a05$fm, arm = "in-dist",
             fnr = a05$fnr_in, lo = a05$fnr_in_lo, hi = a05$fnr_in_hi),
  data.frame(fm = a05$fm, arm = "shift",
             fnr = a05$fnr_sh, lo = a05$fnr_sh_lo, hi = a05$fnr_sh_hi))
a_long$arm <- factor(a_long$arm, levels = c("in-dist", "shift"))
f13a <- ggplot(a_long, aes(fm, fnr, fill = arm)) +
  geom_col(position = position_dodge(0.72), width = 0.64,
           colour = "grey30", linewidth = 0.15) +
  geom_errorbar(aes(ymin = lo, ymax = hi),
                position = position_dodge(0.72), width = 0.18, linewidth = 0.28) +
  geom_hline(yintercept = 0.05, linetype = 2, colour = "grey35", linewidth = 0.4) +
  scale_x_discrete(labels = fm_tick) +
  scale_fill_manual(values = fill_regime, name = NULL) +
  labs(x = NULL, y = "FNR") +
  guides(fill = guide_legend(nrow = 1, title = NULL, order = 1)) +
  theme_expand() +
  theme(axis.text.x = element_text(angle = 30, hjust = 1, size = 7),
        panel.grid.major.x = element_blank())
prov("F13-A", CRC, a_long, "fm")

# Panel B: CRC vs Mondrian-CRC shift FNR at α=0.10
b10 <- crcdf[abs(crcdf$alpha - 0.10) < 1e-9, ]
b_long <- rbind(
  data.frame(fm = b10$fm, arm = "CRC", fnr = b10$fnr_sh,
             lo = b10$fnr_sh_lo, hi = b10$fnr_sh_hi),
  data.frame(fm = b10$fm, arm = "Mondrian-CRC", fnr = b10$fnr_mond,
             lo = b10$fnr_mond_lo, hi = b10$fnr_mond_hi))
b_long$arm <- factor(b_long$arm, levels = c("CRC", "Mondrian-CRC"))
f13b <- ggplot(b_long, aes(fm, fnr, fill = arm)) +
  geom_col(position = position_dodge(0.72), width = 0.64,
           colour = "grey30", linewidth = 0.15) +
  geom_errorbar(aes(ymin = lo, ymax = hi),
                position = position_dodge(0.72), width = 0.18, linewidth = 0.28) +
  geom_hline(yintercept = 0.10, linetype = 2, colour = "grey35", linewidth = 0.4) +
  scale_x_discrete(labels = fm_tick) +
  scale_fill_manual(values = fill_method, name = NULL) +
  labs(x = NULL, y = "FNR") +
  guides(fill = guide_legend(nrow = 1, title = NULL, order = 2)) +
  theme_expand() +
  theme(axis.text.x = element_text(angle = 30, hjust = 1, size = 7),
        panel.grid.major.x = element_blank())
prov("F13-B", CRC, b_long, "fm")

# Panel C: set size CRC vs Mondrian under shift, α=0.10 (same fill legend as B)
c_long <- rbind(
  data.frame(fm = b10$fm, arm = "CRC", size = b10$ss_crc,
             lo = b10$ss_crc_lo, hi = b10$ss_crc_hi),
  data.frame(fm = b10$fm, arm = "Mondrian-CRC", size = b10$ss_mond,
             lo = b10$ss_mond_lo, hi = b10$ss_mond_hi))
c_long$arm <- factor(c_long$arm, levels = c("CRC", "Mondrian-CRC"))
f13c <- ggplot(c_long, aes(fm, size, fill = arm)) +
  geom_col(position = position_dodge(0.72), width = 0.64,
           colour = "grey30", linewidth = 0.15) +
  geom_errorbar(aes(ymin = lo, ymax = hi),
                position = position_dodge(0.72), width = 0.18, linewidth = 0.28) +
  scale_x_discrete(labels = fm_tick) +
  scale_fill_manual(values = fill_method, name = NULL) +
  labs(x = NULL, y = "Set size") +
  guides(fill = "none") +
  theme_expand() +
  theme(axis.text.x = element_text(angle = 30, hjust = 1, size = 7),
        panel.grid.major.x = element_blank())
prov("F13-C", CRC, c_long, "fm")

# Panel D: CRC shift FNR across α by encoder (short labels match A–C ticks)
hline_d <- data.frame(alpha = sort(unique(crcdf$alpha)))
enc_cols <- setNames(unname(MODEL_COLOURS[fm_lvls]), fm_lvls)
f13d <- ggplot(crcdf, aes(factor(alpha), fnr_sh, colour = fm, group = fm)) +
  geom_hline(data = hline_d, aes(yintercept = alpha),
             linetype = 3, colour = "grey50", linewidth = 0.35) +
  geom_line(linewidth = 0.45) +
  geom_errorbar(aes(ymin = fnr_sh_lo, ymax = fnr_sh_hi), width = 0.10,
                linewidth = 0.3, show.legend = FALSE) +
  geom_point(size = 1.6) +
  scale_colour_manual(values = enc_cols, breaks = fm_lvls,
                      labels = unname(fm_tick[fm_lvls]), name = NULL) +
  scale_x_discrete(labels = function(x) sprintf("%.2f", as.numeric(x))) +
  labs(x = "α", y = "FNR") +
  guides(colour = guide_legend(nrow = 1, byrow = TRUE, title = NULL, order = 3)) +
  theme_expand() +
  theme(panel.grid.major.x = element_blank(),
        axis.title.x = element_text(margin = margin(t = 1)))
prov("F13-D", CRC, crcdf, "fm")

f13_all <- (f13a | f13b) / (f13c | f13d) +
  plot_layout(guides = "collect") +
  plot_annotation(tag_levels = "A") &
  tag_expand() &
  theme(legend.position = "bottom",
        legend.box = "vertical",
        legend.box.just = "left",
        legend.spacing.y = unit(4, "pt"),
        legend.margin = margin(t = 0, r = 2, b = 0, l = 2))
save_fig(f13_all, "figures/F13_crc_fnr", w = 5.8, h = 4.35)
}  # end F13

# ---------------------------------------------------------------------------
# F14 — class-prior enrichment + balanced vs unadjusted
# Panels C/D share one unadjusted/balanced fill legend (table #α repaired).
# Short on-figure y-labels; α / prior-ratio / error-bar detail lives in LaTeX.
# ---------------------------------------------------------------------------
if (do_fig("F14")) {
pr <- read_result(PRIOR)
pc <- pr$class_prior_shift_at_P33$per_class
pr_rows <- lapply(pc, function(r) {
  data.frame(class = as.integer(r$class),
             source_pct = as.numeric(r$source_pct),
             target_pct = as.numeric(r$target_pct),
             ratio = as.numeric(r$target_over_source_ratio),
             stringsAsFactors = FALSE)
})
prdf <- do.call(rbind, pr_rows)
# Highlight the five classes shown in tab:classprior
highlight <- c(5L, 2L, 9L, 8L, 1L)
prdf$flag <- ifelse(prdf$class %in% highlight, "tabled", "other")
prdf$class_f <- factor(prdf$class, levels = prdf$class[order(prdf$ratio)])

f14a <- ggplot(prdf, aes(class_f, ratio, fill = flag)) +
  geom_col(width = 0.72, colour = "grey30", linewidth = 0.15) +
  geom_hline(yintercept = 1, linetype = 2, colour = "grey35", linewidth = 0.4) +
  scale_fill_manual(values = c(tabled = okabe_ito[4], other = "grey75"),
                    guide = "none") +
  labs(x = "class id", y = "prior ratio") +
  theme_expand() + theme(panel.grid.major.x = element_blank())
prov("F14-A", PRIOR, prdf, "class")

# Panel B: source vs target % for tabled classes
fill_freq <- c("source" = okabe_ito[1], "target" = okabe_ito[2])
tabc <- prdf[prdf$class %in% highlight, ]
tab_long <- rbind(
  data.frame(class = tabc$class, arm = "source", pct = tabc$source_pct),
  data.frame(class = tabc$class, arm = "target", pct = tabc$target_pct))
tab_long$class <- factor(tab_long$class, levels = highlight)
tab_long$arm <- factor(tab_long$arm, levels = c("source", "target"))
f14b <- ggplot(tab_long, aes(class, pct, fill = arm)) +
  geom_col(position = position_dodge(0.78), width = 0.7,
           colour = "grey30", linewidth = 0.15) +
  scale_fill_manual(values = fill_freq, name = NULL) +
  labs(x = "class id (tabled)", y = "frequency (%)") +
  guides(fill = guide_legend(nrow = 1, title = NULL, order = 1)) +
  theme_expand() + theme(panel.grid.major.x = element_blank())
prov("F14-B", PRIOR, tab_long, "class")

# Shared fill for C/D (named so patchwork collect merges once)
fill_probe <- c("unadjusted" = okabe_ito[1], "balanced" = okabe_ito[2])
fm_tick14 <- c(Prithvi = "Prithvi", `SSL4EO-DINO` = "DINO",
               `SSL4EO-MAE` = "MAE", Clay = "Clay")

# Panel C: ECE shift unadjusted vs balanced at α=0.05 (matches tab:balanced)
ece_rows <- list()
for (mode in c("unbalanced", "balanced")) {
  for (fm in names(pr$results[[mode]])) {
    blk <- pr$results[[mode]][[fm]]$per_alpha[["0.05"]]$ece_shift
    ece_rows[[length(ece_rows) + 1]] <- data.frame(
      fm = lab_of(fm),
      mode = if (mode == "unbalanced") "unadjusted" else "balanced",
      ece = getm(blk), lo = getlo(blk), hi = gethi(blk),
      stringsAsFactors = FALSE)
  }
}
ecedf <- do.call(rbind, ece_rows)
ecedf$mode <- factor(ecedf$mode, levels = c("unadjusted", "balanced"))
ecedf$fm <- factor(ecedf$fm, levels = c("Prithvi", "SSL4EO-DINO",
                                        "SSL4EO-MAE", "Clay"))
f14c <- ggplot(ecedf, aes(fm, ece, fill = mode)) +
  geom_col(position = position_dodge(0.78), width = 0.7,
           colour = "grey30", linewidth = 0.15) +
  geom_errorbar(aes(ymin = lo, ymax = hi),
                position = position_dodge(0.78), width = 0.22, linewidth = 0.3) +
  scale_x_discrete(labels = fm_tick14) +
  scale_fill_manual(values = fill_probe, name = NULL) +
  labs(x = NULL, y = "shift ECE") +
  guides(fill = guide_legend(nrow = 1, title = NULL, order = 2)) +
  theme_expand() +
  theme(axis.text.x = element_text(angle = 25, hjust = 1, size = 7),
        panel.grid.major.x = element_blank())
prov("F14-C", PRIOR, ecedf, "fm")

# Panel D: #α Mondrian-restored (of 3) — same column as tab:balanced "#α repaired"
rep_rows <- list()
for (mode in c("unbalanced", "balanced")) {
  for (fm in names(pr$results[[mode]])) {
    cells <- pr$results[[mode]][[fm]]$per_alpha
    n_rep <- sum(vapply(cells, function(c0) isTRUE(c0$mondrian_restores_CI_excludes_0),
                        FALSE))
    rep_rows[[length(rep_rows) + 1]] <- data.frame(
      fm = lab_of(fm),
      mode = if (mode == "unbalanced") "unadjusted" else "balanced",
      n_restored = n_rep, stringsAsFactors = FALSE)
  }
}
repdf <- do.call(rbind, rep_rows)
repdf$mode <- factor(repdf$mode, levels = c("unadjusted", "balanced"))
repdf$fm <- factor(repdf$fm, levels = c("Prithvi", "SSL4EO-DINO",
                                        "SSL4EO-MAE", "Clay"))
f14d <- ggplot(repdf, aes(fm, n_restored, fill = mode)) +
  geom_col(position = position_dodge(0.78), width = 0.7,
           colour = "grey30", linewidth = 0.15) +
  scale_x_discrete(labels = fm_tick14) +
  scale_y_continuous(breaks = 0:3, limits = c(0, 3.2)) +
  scale_fill_manual(values = fill_probe, name = NULL) +
  labs(x = NULL, y = "#α restored") +
  guides(fill = "none") +
  theme_expand() +
  theme(axis.text.x = element_text(angle = 25, hjust = 1, size = 7),
        panel.grid.major.x = element_blank())
prov("F14-D", PRIOR, repdf, "fm")

f14_all <- (f14a | f14b) / (f14c | f14d) +
  plot_layout(guides = "collect") +
  plot_annotation(tag_levels = "A") &
  tag_expand() &
  theme(legend.position = "bottom",
        legend.box = "horizontal",
        legend.spacing.x = unit(8, "pt"),
        legend.margin = margin(t = 0, r = 2, b = 0, l = 2))
save_fig(f14_all, "figures/F14_classprior", w = 4.75, h = 3.85)
}  # end F14

cat("Expand figures F11–F14 written from frozen JSON.\n")
