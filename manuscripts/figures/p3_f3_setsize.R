# F3 set-size cost of restoration — standalone rebuild (human-readable 2×2).
# Does not touch F1/F2 assets. Run from manuscripts/:
#   Rscript figures/p3_f3_setsize.R
#
# Frozen inputs (never modified here):
#   FIVEFM_RESULTS  — five-encoder EuroSAT merged JSON
#   BSWEEP_RESULTS  — boundary-sweep set sizes
#   SO2SAT_RESULTS  — So2Sat LCZ split vs target-global set sizes
suppressMessages({
  source("figures/ggtheme.R")
})

RES <- Sys.getenv(
  "FIVEFM_RESULTS",
  "../experiments/results/eurosat_stage2_multifm_multialpha/results_fivefm_figures_2026-07-13.json"
)
BSWEEP <- Sys.getenv("BSWEEP_RESULTS", "../experiments/results/eurosat_boundary_sweep/results.json")
SO2SAT <- Sys.getenv("SO2SAT_RESULTS", "../experiments/results/so2sat_coverage_debt/results.json")

fm_lab <- c(
  prithvi    = "Prithvi-EO-2.0",
  ssl4eo     = "SSL4EO-S12 (DINO)",
  ssl4eo_mae = "SSL4EO-S12 (MAE)",
  clay       = "Clay v1.5",
  dofa       = "DOFA"
)
fm_short <- c(
  "Prithvi-EO-2.0"     = "Prithvi",
  "SSL4EO-S12 (DINO)"  = "SSL4EO-DINO",
  "SSL4EO-S12 (MAE)"   = "SSL4EO-MAE",
  "Clay v1.5"          = "Clay",
  "DOFA"               = "DOFA"
)
shorten_fm <- function(x) {
  out <- unname(fm_short[as.character(x)])
  ifelse(is.na(out), as.character(x), out)
}
lab_of <- function(fm) if (!is.null(fm_lab[[fm]])) fm_lab[[fm]] else fm

getm  <- function(x) if (is.null(x)) NA_real_ else as.numeric(x$mean)
getlo <- function(x) if (is.null(x)) NA_real_ else as.numeric(x$ci_low)
gethi <- function(x) if (is.null(x)) NA_real_ else as.numeric(x$ci_high)

src_id <- function(path) {
  p <- normalizePath(path, mustWork = FALSE)
  file.path(basename(dirname(p)), basename(p))
}
prov <- function(tag, path, dfx, series_col) {
  cat(sprintf("[%s] source=%s rows=%d series=%d\n", tag, src_id(path),
              nrow(dfx), length(unique(dfx[[series_col]]))))
}

# Debt-ordered encoder factor (matches F1 left→right: low debt first).
d <- read_result(RES)
fms <- names(d$fm_results)
alphas <- names(d$fm_results[[fms[[1]]]])
rows <- list()
for (fm in fms) for (a in alphas) {
  c0 <- d$fm_results[[fm]][[a]]$cell
  rs <- c0$real_shift
  rest <- c0$restoration
  ci_low <- tryCatch(
    as.numeric(rest$paired_gap_diff_split_minus_mondrian$ci_low),
    error = function(e) NA
  )
  lab <- lab_of(fm)
  rows[[length(rows) + 1]] <- data.frame(
    fm = lab,
    alpha = as.numeric(a),
    ece_shift = getm(c0$ece$real_shift),
    mond_size = getm(rs$conformal_spatial_mondrian$set_size),
    mond_size_lo = getlo(rs$conformal_spatial_mondrian$set_size),
    mond_size_hi = gethi(rs$conformal_spatial_mondrian$set_size),
    split_size = getm(rs$conformal_split$set_size),
    split_size_lo = getlo(rs$conformal_split$set_size),
    split_size_hi = gethi(rs$conformal_split$set_size),
    restored = isTRUE(!is.na(ci_low) && ci_low > 0),
    stringsAsFactors = FALSE
  )
}
df <- do.call(rbind, rows)
deb <- do.call(rbind, lapply(split(df, df$fm), function(g) {
  data.frame(fm = g$fm[1], debt = mean(g$ece_shift, na.rm = TRUE))
}))
deb <- deb[order(deb$debt), ]
df$fm <- factor(df$fm, levels = deb$fm)

# Boundary sweep set sizes at α = 0.10.
bs <- read_result(BSWEEP)
bs_rows <- list()
for (fm in names(bs$fm_results)) {
  for (b in names(bs$fm_results[[fm]]$boundaries)) {
    cells <- bs$fm_results[[fm]]$boundaries[[b]]$cells
    for (a in names(cells)) {
      rs <- cells[[a]]$real_shift
      bs_rows[[length(bs_rows) + 1]] <- data.frame(
        fm = lab_of(fm), boundary = b, alpha = as.numeric(a),
        split_size = getm(rs$conformal_split$set_size),
        mond_size = getm(rs$conformal_spatial_mondrian$set_size),
        stringsAsFactors = FALSE
      )
    }
  }
}
bsdf <- do.call(rbind, bs_rows)
bsdf$fm <- factor(bsdf$fm, levels = levels(df$fm))

# So2Sat set sizes (own y-scale; 17 LCZ).
s2 <- read_result(SO2SAT)
s2_rows <- list()
for (fm in names(s2$fm_results)) {
  cells <- s2$fm_results[[fm]]$cells
  for (a in names(cells)) {
    c0 <- cells[[a]]
    s2_rows[[length(s2_rows) + 1]] <- data.frame(
      fm = lab_of(fm), alpha = as.numeric(a),
      split_size = getm(c0$conformal_split$set_size),
      split_size_lo = getlo(c0$conformal_split$set_size),
      split_size_hi = gethi(c0$conformal_split$set_size),
      tg_size = getm(c0$conformal_target_global$set_size),
      tg_size_lo = getlo(c0$conformal_target_global$set_size),
      tg_size_hi = gethi(c0$conformal_target_global$set_size),
      stringsAsFactors = FALSE
    )
  }
}
s2df <- do.call(rbind, s2_rows)
s2df$fm <- factor(s2df$fm, levels = levels(df$fm))

# --- verify frozen DOFA Mondrian sizes (caption / body claim) ---
dofa <- df[as.character(df$fm) == "DOFA", ]
dofa <- dofa[order(dofa$alpha), ]
dofa_str <- paste(sprintf("%.2f", dofa$mond_size), collapse = "/")
cat(sprintf("[F3 verify] DOFA Mondrian set sizes @ α=%s → %s (expect 1.58/1.29/1.08)\n",
            paste(sprintf("%.2f", dofa$alpha), collapse = "/"), dofa_str))
stopifnot(all(abs(dofa$mond_size - c(1.5839, 1.2875, 1.0807)) < 5e-4))

arm_levels_c <- c("split (source)", "spatial-Mondrian")
arm_linetypes <- c(
  "split (source)" = "solid",
  "spatial-Mondrian" = "longdash"
)
arm_shapes <- c(
  "split (source)" = 16,
  "spatial-Mondrian" = 17
)

# Shared 2×2 theme: keep effective print size in the 7–9 pt band under
# figure* @ 0.95\textwidth of a ~4.75 in render.
th_f3 <- theme_paper(base_size = 9) +
  theme(
    axis.title = element_text(size = 8),
    axis.text = element_text(size = 7.5),
    legend.text = element_text(size = 7.5),
    legend.title = element_blank(),
    legend.key.width = unit(10, "pt"),
    legend.key.height = unit(8, "pt"),
    panel.grid.major.x = element_blank()
  )

# Shared y-limits for A/B so B is not a microscopic auto-scale.
ylim_ab <- c(0.95, 1.85)

dfs <- df
dfs$fm <- factor(shorten_fm(dfs$fm), levels = shorten_fm(levels(df$fm)))

# A: Mondrian set size vs α (restoration cost above singleton floor).
f3a <- ggplot(dfs, aes(factor(alpha), mond_size, colour = fm, group = fm)) +
  geom_hline(yintercept = 1, linetype = 3, linewidth = 0.35, colour = "grey35") +
  geom_errorbar(aes(ymin = mond_size_lo, ymax = mond_size_hi),
                width = 0.12, linewidth = 0.35, show.legend = FALSE) +
  geom_line(linewidth = 0.45) +
  geom_point(size = 2.0) +
  scale_color_model() +
  coord_cartesian(ylim = ylim_ab) +
  labs(x = "α", y = "Mondrian set size") +
  guides(colour = guide_legend(nrow = 1, title = NULL, order = 1)) +
  th_f3
prov("F3-A", RES, dfs, "fm")

# B: split set size on the SAME y-scale — singleton floor, not a zoomed strip.
sp <- data.frame(
  fm = factor(shorten_fm(df$fm), levels = levels(dfs$fm)),
  alpha = df$alpha,
  size = df$split_size,
  lo = df$split_size_lo,
  hi = df$split_size_hi,
  stringsAsFactors = FALSE
)
f3b <- ggplot(sp, aes(factor(alpha), size, colour = fm, group = fm)) +
  geom_hline(yintercept = 1, linetype = 3, linewidth = 0.35, colour = "grey35") +
  geom_errorbar(aes(ymin = lo, ymax = hi),
                width = 0.12, linewidth = 0.35, show.legend = FALSE) +
  geom_line(linewidth = 0.45) +
  geom_point(size = 2.0) +
  annotate(
    "text",
    x = 2, y = 1.22,
    label = "all ≈ 1.000\n(singleton floor)",
    size = 2.6, family = PAPER_FONT, colour = "grey25", lineheight = 0.95
  ) +
  scale_color_model() +
  coord_cartesian(ylim = ylim_ab) +
  labs(x = "α", y = "Split set size") +
  guides(colour = "none") +
  th_f3
prov("F3-B", RES, sp, "fm")

# C: boundary sensitivity at α = 0.10 — colour = encoder, linetype = arm (no facets).
bsz <- bsdf[abs(bsdf$alpha - 0.10) < 1e-9, ]
bszm <- rbind(
  data.frame(fm = shorten_fm(bsz$fm), boundary = bsz$boundary,
             arm = "split (source)", size = bsz$split_size,
             stringsAsFactors = FALSE),
  data.frame(fm = shorten_fm(bsz$fm), boundary = bsz$boundary,
             arm = "spatial-Mondrian", size = bsz$mond_size,
             stringsAsFactors = FALSE)
)
bszm$fm <- factor(bszm$fm, levels = levels(dfs$fm))
bszm$arm <- factor(bszm$arm, levels = arm_levels_c)
bszm$boundary <- factor(bszm$boundary, levels = c("P25", "P33", "P40", "P50"))

f3c <- ggplot(bszm, aes(boundary, size, colour = fm, group = interaction(fm, arm),
                        linetype = arm, shape = arm)) +
  geom_hline(yintercept = 1, linetype = 3, linewidth = 0.35, colour = "grey35") +
  geom_line(linewidth = 0.45) +
  geom_point(size = 1.8) +
  scale_color_model() +
  scale_linetype_manual(values = arm_linetypes) +
  scale_shape_manual(values = arm_shapes) +
  labs(x = "Boundary", y = "Set size (α = 0.10)") +
  guides(
    colour = "none",
    linetype = guide_legend(nrow = 1, title = NULL, order = 2),
    shape = guide_legend(nrow = 1, title = NULL, order = 2)
  ) +
  th_f3
prov("F3-C", BSWEEP, bszm, "fm")

# D: So2Sat — same encoder colours; target-global vs split by linetype (own y-scale).
s2sz <- rbind(
  data.frame(fm = shorten_fm(s2df$fm), alpha = s2df$alpha,
             arm = "split (source)", size = s2df$split_size,
             lo = s2df$split_size_lo, hi = s2df$split_size_hi,
             stringsAsFactors = FALSE),
  data.frame(fm = shorten_fm(s2df$fm), alpha = s2df$alpha,
             arm = "target-global", size = s2df$tg_size,
             lo = s2df$tg_size_lo, hi = s2df$tg_size_hi,
             stringsAsFactors = FALSE)
)
s2sz$fm <- factor(s2sz$fm, levels = levels(dfs$fm))
s2sz$arm <- factor(s2sz$arm, levels = c("split (source)", "target-global"))

f3d <- ggplot(s2sz, aes(factor(alpha), size, colour = fm, group = fm)) +
  geom_hline(yintercept = 1, linetype = 3, linewidth = 0.35, colour = "grey35") +
  geom_errorbar(aes(ymin = lo, ymax = hi), width = 0.12, linewidth = 0.3,
                show.legend = FALSE) +
  geom_line(linewidth = 0.45) +
  geom_point(size = 1.8) +
  # Facet by arm (2 strips) instead of overlaying 10 series; encoder colour is
  # enough once each arm has its own panel. Strip labels are short and fit.
  facet_wrap(~arm, nrow = 1) +
  scale_color_model() +
  labs(x = "α", y = "Set size (So2Sat)") +
  guides(colour = "none") +
  th_f3 +
  theme(strip.text = element_text(size = 7.5))
prov("F3-D", SO2SAT, s2sz, "fm")

# Equal 2×2; one encoder legend (A) + one split/Mondrian arm legend (C).
# D names its arms in facet strips (split vs target-global).
f3_all <- (f3a | f3b) / (f3c | f3d) +
  plot_layout(guides = "collect") +
  plot_annotation(tag_levels = "A") &
  paper_tag_theme(base_size = 9) &
  theme(
    legend.position = "bottom",
    legend.box = "vertical",
    legend.spacing.y = unit(1, "pt"),
    legend.margin = margin(t = 0, r = 2, b = 0, l = 2)
  )

save_fig(f3_all, "figures/F3_setsize_vs_alpha", w = 4.75, h = 3.90)
cat("F3 written: figures/F3_setsize_vs_alpha.{pdf,png}\n")
