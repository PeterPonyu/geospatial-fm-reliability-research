# Reusable professional ggplot2 theme + helpers for the reliability-portfolio manuscripts.
# Usage in a figure script:
#   source("${ORCHESTRATION_FILES}/manuscript-template/ggtheme.R")
#   d <- read_result("/path/to/result.json")          # jsonlite
#   p <- ggplot(...) + theme_paper()
#   save_fig(p, "figures/F1_name", w = 6.5, h = 4)     # writes 300-dpi PNG + PDF
suppressMessages({
  library(ggplot2)
  library(jsonlite)
  library(scales)
  library(patchwork)   # multi-panel composition + plot_annotation(tag_levels=)
})

# Okabe-Ito colorblind-safe palette
okabe_ito <- c("#0072B2", "#E69F00", "#009E73", "#D55E00",
               "#CC79A7", "#56B4E9", "#F0E442", "#000000")

# Fixed model -> colour assignment. This must be keyed by name, not positional:
# scale_*_manual() with an unnamed palette walks the vector against whatever
# factor levels the panel in hand contains, so a model picks up a different
# colour in every panel that omits or reorders its peers (e.g. a panel sorted
# by an x-axis metric rather than alphabetically). Both the short and the
# fully-versioned label for each model map to the same hue so panels that use
# either convention agree.
MODEL_COLOURS <- c(
  "Clay"             = okabe_ito[1],
  "Clay v1.5"        = okabe_ito[1],
  "DOFA"             = okabe_ito[2],
  "Prithvi"          = okabe_ito[3],
  "Prithvi-EO-2.0"   = okabe_ito[3],
  "SSL4EO-DINO"      = okabe_ito[4],
  "SSL4EO-S12 (DINO)" = okabe_ito[4],
  "SSL4EO-MAE"       = okabe_ito[5],
  "SSL4EO-MAE-L"     = okabe_ito[5],
  "SSL4EO-S12 (MAE)" = okabe_ito[5],
  "SSL4EO-S12"       = okabe_ito[5]
)

## Use these for any scale keyed by model (aes(colour = fm)). Passing the named
## vector — rather than relying on level order — is what keeps a model's colour
## identical across panels that contain different model subsets. Unused names
## in the palette are ignored by scale_*_manual(), so a panel may show any
## subset. Note that pinning factor levels is NOT an adequate substitute:
## ggplot2 drops unused levels before assigning an unnamed palette positionally.
scale_colour_model <- function(...) scale_colour_manual(values = MODEL_COLOURS, ...)
scale_color_model  <- scale_colour_model
scale_fill_model   <- function(...) scale_fill_manual(values = MODEL_COLOURS, ...)

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
      # Legend geometry is load-bearing for the 2x2 multi-panel figures. At
      # ggplot2's default key size and spacing, a 5-entry legend measures
      # ~240-300pt; placed under a 171pt half-width panel it is centred and
      # overhangs both edges of the 342pt device, where cairo clips it (labels
      # sheared mid-word: "target-globa", "spatial-Mondrian"). Tightening the
      # keys and inter-key gaps pulls those legends inside the canvas without
      # dropping to a smaller-than-floor font.
      legend.key.width  = unit(9, "pt"),
      legend.key.height = unit(9, "pt"),
      legend.key.spacing.x = unit(3, "pt"),
      legend.key.spacing.y = unit(1, "pt"),
      legend.margin     = margin(t = 1, r = 1, b = 1, l = 1),
      legend.box.spacing = unit(3, "pt"),
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

# Patchwork panel-tag theme for multi-panel figures. Bold is reserved for the
# panel tag alone -- the standing portfolio typography rule is one serif family,
# uniform sizes, and no decorative weight anywhere except the panel label
# (identical rule to figstyle.panel_label() on the Python side). Use as:
#   (pA | pB) / (pC | pD) + plot_annotation(tag_levels = "A") & paper_tag_theme()
paper_tag_theme <- function(base_size = 11) {
  # plot.tag.location = "margin" is load-bearing, not cosmetic. The default
  # ("panel", or an npc position like c(0,1)) anchors the tag in the same
  # region as a rotated y-axis title, so on panels whose y title spans the
  # full axis height the tag and the title overprint each other. "margin"
  # reserves a strip outside the axis titles. Requires patchwork >= 1.2.
  theme(text     = element_text(family = PAPER_FONT),
        plot.tag = element_text(family = PAPER_FONT, face = "bold",
                                size = base_size, hjust = 0, vjust = 1),
        plot.tag.position = "topleft",
        plot.tag.location = "margin",
        plot.margin = margin(t = 4, r = 5, b = 2, l = 2))
}
