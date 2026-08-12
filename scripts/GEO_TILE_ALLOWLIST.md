# GEO physical-depth tile allowlist (2026-08-12)

## Box mapping
- SeetaCloud **46823** = GEO (`GEO_BOX_ALL_DONE`, `geospatial-fm-reliability-research/`)
- SeetaCloud **19514** = RotCert (do not pull GEO dumps from RotCert)

## Designed pull (tight budget ≤200 MiB hard fail)

| Need | Status | Action |
|------|--------|--------|
| F8 geomap | manifest-only (centroids) | **no tile fetch** |
| F9 geopatches (6 classes × 3 sides) | local MS+RGB complete for all 6 figure classes | **no GPU fetch** |
| F15 shift fingerprint (N_PER=80, seed 11) | seeded sample tiles all have local MS for 6 classes | **no GPU fetch** |
| Other EuroSAT classes MS (HerbaceousVegetation, Industrial, Pasture, River) | ~10k TIFs missing locally; not used by F8/F9/F15 | **do not pull** unless a new float freezes IDs |

## Refused (too large / not allowlisted)
- `/root/geospatial-fm-reliability-research/data/eurosat_ms/EuroSAT_MS.zip` (~2.0 GiB)
- `/root/autodl-tmp/dataset` GeoBench tree (~29 GiB)
- `/root/autodl-tmp/geo_session5.tar.gz` (~300 MiB session dump)
- Full EuroSAT zip from RotCert box `/root/autodl-tmp/eurosat_ms/EuroSAT_MS.zip` (~2.0 GiB)

## Zenodo (non-GPU) if full MS archive needed later
Use `geospatial-fm-reliability-research/scripts/restore_eurosat_ms.py` — do not abuse the GPU box for the archive.

## Residual
F15 PDF regenerated locally in MS mode (2026-08-12); ISPRS/TGRS manuscript floats remain deferred pending human re-insert.
F15 float remains deferred from ISPRS/TGRS manuscripts (`F15_DEFERRED.txt`); generator + PDF asset may be regenerated locally now that the 6-class MS tiles exist.
