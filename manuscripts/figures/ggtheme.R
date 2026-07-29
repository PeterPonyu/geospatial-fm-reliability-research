# Reusable professional ggplot2 theme + helpers for the reliability-portfolio manuscripts.
# Usage in a figure script:
#   source("/home/zeyufu/Desktop/Orchestration-files/manuscript-template/ggtheme.R")
#   d <- read_result("/path/to/result.json")          # jsonlite
#   p <- ggplot(...) + theme_paper()
#   save_fig(p, "figures/F1_name", w = 6.5, h = 4)     # writes 300-dpi PNG + PDF
suppressMessages({
  library(ggplot2)
  library(jsonlite)
  library(scales)
})

# Okabe-Ito colorblind-safe palette
okabe_ito <- c("#0072B2", "#E69F00", "#009E73", "#D55E00",
               "#CC79A7", "#56B4E9", "#F0E442", "#000000")

# Times-compatible serif matching the manuscript body text. Nimbus Roman (URW
# Times clone) carries full Latin + Greek (alpha, delta) + the Unicode minus, so
# the cairo_pdf device embeds it for every glyph with no sans/Noto fallback.
PAPER_FONT <- "Nimbus Roman"

theme_paper <- function(base_size = 11) {
  # No decorative bold/italic anywhere: strip/axis/legend titles and the plot
  # title carry no face= override (plain weight, matching the caption's own
  # unemphasized "Figure N:" label). Axis/legend/strip text are pinned to
  # base_size - 1 explicitly (rather than left at ggplot2's default rel(0.8)
  # relative sizing) so every text element in the figure lands in the same
  # size family once the figure is scaled to its printed width.
  theme_bw(base_size = base_size) +
    theme(
      text             = element_text(family = PAPER_FONT),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(linewidth = 0.25, colour = "grey88"),
      panel.border     = element_rect(linewidth = 0.4, colour = "grey40"),
      strip.background = element_rect(fill = "grey92", colour = NA),
      strip.text       = element_text(size = base_size - 1),
      axis.title       = element_text(size = base_size - 1),
      axis.text        = element_text(size = base_size - 1),
      legend.position  = "bottom",
      legend.key       = element_blank(),
      legend.text      = element_text(size = base_size - 1),
      legend.title     = element_text(size = base_size - 1),
      plot.title       = element_text(size = base_size),
      plot.caption     = element_text(size = base_size - 2, colour = "grey40")
    )
}

scale_color_paper <- function(...) scale_colour_manual(values = okabe_ito, ...)
scale_fill_paper  <- function(...) scale_fill_manual(values = okabe_ito, ...)

# Read a result JSON; returns a nested list.
read_result <- function(path) jsonlite::fromJSON(path, simplifyVector = FALSE)

# Save a figure at publication size as BOTH 300-dpi PNG and vector PDF.
save_fig <- function(plot, stem, w = 6.5, h = 4) {
  dir.create(dirname(stem), showWarnings = FALSE, recursive = TRUE)
  ggsave(paste0(stem, ".png"), plot, width = w, height = h, dpi = 300, bg = "white")
  # family = PAPER_FONT sets the cairo device default so glyphs drawn outside the
  # theme text elements (e.g. pch/text plotting symbols) also use the serif face.
  ggsave(paste0(stem, ".pdf"), plot, width = w, height = h, device = cairo_pdf,
         family = PAPER_FONT, bg = "white")
  invisible(stem)
}
