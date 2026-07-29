# Zenodo deposit instructions

This repository ships a completed `.zenodo.json` metadata file describing the
code + result-JSON snapshot that backs the manuscript
(`manuscripts/paper.tex` / `paper.pdf`). Depositing archives a citable,
DOI-reserved copy of HEAD for the paper's Data & Code Availability statement.

**No deposit has been made yet, and this document performs no network calls.**
It records the exact manual steps. Depositing and, later, publishing are
deliberate human actions.

## Prerequisites

- The working tree is committed and pushed (`git archive` only captures
  tracked files at HEAD; commit first).
- Bulk data under `data/eurosat_ms/` and download caches are gitignored and
  documented in `DATA_MANIFEST.md` (size + SHA256 + source); they are
  intentionally excluded from the archive. Do **not** delete data to shrink it.

## Steps

1. **Get a Zenodo token.** Log in at <https://zenodo.org>, open
   <https://zenodo.org/account/settings/applications>, and create a personal
   access token with scopes `deposit:write` and `deposit:actions`. For a
   rehearsal, make a separate token on <https://sandbox.zenodo.org>.

2. **Export it (never commit it):**

   ```bash
   export ZENODO_TOKEN=<your token>
   ```

3. **Metadata is already in place.** `.zenodo.json` in this repo root is filled
   in (title, description, creators, MIT license, keywords, version 0.1.0,
   `prereserve_doi`). No `REPLACE` placeholders remain.

4. **Dry-run first** (no network; prints the exact API steps the script would
   take):

   ```bash
   python3 ../reliability-commons/zenodo/zenodo_deposit.py \
     --repo . --dry-run
   ```

5. **Create the draft deposition** (optionally rehearse with `--sandbox`
   first). This builds a `git archive` tarball of HEAD, creates a **draft**
   deposition, reserves a DOI, and uploads the tarball. It does **not**
   publish:

   ```bash
   python3 ../reliability-commons/zenodo/zenodo_deposit.py --repo .
   ```

6. **Use the reserved DOI** (`10.5281/zenodo.XXXXXXX`) in the manuscript's
   Data & Code Availability section, replacing the placeholder.

7. **Publish manually** in the Zenodo web UI once the paper is submitted or
   accepted. The script never publishes; that is a deliberate human step.

## Version

`0.1.0` — first archived snapshot. Zenodo concept-DOI versioning can chain
later releases onto the same concept DOI.

## Deposit record

### 2026-07-02 — reserved DOI on draft deposition

- Deposition ID: `21130299`
- Reserved DOI: `10.5281/zenodo.21130299`
- Draft record URL: <https://zenodo.org/deposit/21130299>
- Status: **reserved on a DRAFT deposition** — not yet published/active. The
  DOI resolves only after the record is published in the Zenodo web UI.
- Archived commit: `eced35c` (repo HEAD *before* this DOI-propagation commit).
  The uploaded tarball was built by `git archive` at that HEAD.
- Propagated the DOI into `CITATION.cff`, `README.md`, and
  `manuscripts/paper.tex` (Data & Code Availability), all marked
  reserved/draft pending publication.

Note: the uploaded tarball predates this DOI-propagation commit, so it does not
contain the DOI strings themselves. Before pressing Publish, optionally replace
the file in the draft (via the web UI, or by rerunning `zenodo_deposit.py`
after deleting the old file) so the archive reflects the final repository state.
