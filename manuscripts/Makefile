# Adopted from reliability-commons/paper-template (v0.1) on 2026-07-02.
#
# Targets:
#   make figures  - run every figures/*.R via Rscript (figures regenerate
#                   ONLY from on-disk result JSONs/CSVs under ../experiments/results/)
#   make bib      - copy the portfolio shared bibliography next to the paper
#   make paper    - figures + bib, then latexmk -pdf
#   make clean    - remove LaTeX aux files and generated figure PDFs/PNGs
#
# Override SHARED_BIB if the kit moves:
#   make paper SHARED_BIB=/path/to/reliability-commons/shared.bib

SHARED_BIB ?= ${COMMONS_ROOT}/shared.bib
# ggtheme.R is a sourced helper (theme + save_fig), not a standalone figure script.
R_SCRIPTS  := $(filter-out figures/ggtheme.R,$(wildcard figures/*.R))

.PHONY: all figures fig1 bib paper clean

all: paper

figures:
	@for s in $(R_SCRIPTS); do \
		echo "Rscript $$s"; \
		Rscript "$$s" || exit 1; \
	done

# Fig. 1 method-overview schematic: standalone TikZ under figures-src/, kept
# separate from the R pipeline above (it plots no on-disk result data).
# Compiles figures-src/fig0_overview.pdf and copies it next to the R-generated
# figures for both the canonical draft and the JSTARS port.
fig1:
	$(MAKE) -C figures-src
	cp figures-src/fig0_overview.pdf figures/fig0_overview.pdf
	cp figures-src/fig0_overview.pdf jstars/figures/fig0_overview.pdf

bib:
	@if [ -f "$(SHARED_BIB)" ]; then \
		cp "$(SHARED_BIB)" shared.bib; \
		echo "Copied $(SHARED_BIB) -> shared.bib"; \
	else \
		echo "WARNING: $(SHARED_BIB) not found; creating empty shared.bib"; \
		touch shared.bib; \
	fi

paper: figures fig1 bib
	latexmk -pdf -interaction=nonstopmode paper.tex

clean:
	latexmk -C paper.tex 2>/dev/null || true
	rm -f paper.bbl paper.run.xml shared.bib
	rm -f figures/*.pdf figures/*.png figures/*.csv
