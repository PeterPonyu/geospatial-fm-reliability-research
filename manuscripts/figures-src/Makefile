# Build the Fig. 1 method-overview schematic: standalone TikZ -> PDF.
# Symbolic only (no on-disk result data); does not touch the R figure
# pipeline in ../figures/*.R (see ../Makefile `figures` target).
#
# Usage:
#   make            # compile fig0_overview.pdf
#   make clean      # remove LaTeX build byproducts (keeps the PDF)
#   make distclean  # also remove the compiled PDF

LATEXMK = latexmk -pdf -interaction=nonstopmode -halt-on-error

.PHONY: all clean distclean

all: fig0_overview.pdf

fig0_overview.pdf: fig0_overview.tex
	$(LATEXMK) fig0_overview.tex

clean:
	latexmk -c fig0_overview.tex

distclean: clean
	rm -f fig0_overview.pdf
