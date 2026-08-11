# DATA_MANIFEST — gitignored bulk data (provenance record)

Created 2026-07-02 during the provenance sweep. Every data path excluded by `.gitignore`
(files >50 MB or bulk-data directories >200 MB, plus download caches) is documented here
with its exact size and SHA256 as measured on disk on 2026-07-02 (`sha256sum`, this machine).
Nothing listed here was modified — only catalogued.

## Raw dataset archives

| Path | Size (bytes) | SHA256 | Source / re-download |
|---|---|---|---|
| `data/eurosat_ms/EuroSAT_MS.zip` | 2,065,402,329 | `eb0cf47380b0ff0dba68726bcb9184f8b261efcbb818d3d2b00b557ab0835b33` | EuroSAT MS 13-band GeoTIFF, Zenodo record 7711810 (https://zenodo.org/records/7711810), free/no-auth (per `DEEP-REVERIFY-2026-06-21.md` and `experiments/eurosat_spatial/prepare_eurosat.py`) |
| `experiments/bigearthnet_coverage_debt/data/classification_v1.0/m-bigearthnet.zip` | 6,561,072,575 | `7997a68855b473c0c9b92986d1365cddaf9f83d90b7858c81914bd915320bed4` | GEO-Bench, HuggingFace dataset `recursix/geo-bench-1.0`, file `classification_v1.0/m-bigearthnet.zip`, public no-auth (per header of `experiments/bigearthnet_coverage_debt/build_ben_arrays.py`) |

## Extracted / derived directories (gitignored as bulk-data dirs)

### `data/eurosat_ms/extracted/` — 2,895,588,000 bytes, 27,000 files
27,000 EuroSAT_MS GeoTIFF tiles (`EuroSAT_MS/<Class>/<Class>_<n>.tif`, 10 classes).
Derived deterministically by unzipping `data/eurosat_ms/EuroSAT_MS.zip` (SHA256 above);
the zip is the integrity source of truth. Individual per-file hashes are not listed
(27k files); regenerate with `unzip EuroSAT_MS.zip -d extracted/`.

### `experiments/bigearthnet_coverage_debt/data/.cache/` — 24 KB
HuggingFace download cache (`huggingface/download/classification_v1.0/*.metadata|.lock`)
left by the `recursix/geo-bench-1.0` pull. No payload data; safe to delete/regenerate.

## Derived arrays (>50 MB files, gitignored individually)

Built by scripts in this repo from the raw archives above. Small sibling files
(coords, labels, multihot, sample_ids, prep_stats, small feature caches) ARE tracked in git.

| Path | Size (bytes) | SHA256 | Built by |
|---|---|---|---|
| `experiments/bigearthnet_coverage_debt/arrays/images_ms13.npy` | 1,633,435,776 | `04ed8b460806698ee012d36d974da9a1d97fef7e242ae002af2d55bda09b70d0` | `experiments/bigearthnet_coverage_debt/build_ben_arrays.py` from m-bigearthnet.zip |
| `experiments/results/eurosat_spatial/images_ms.npy` | 2,875,392,128 | `d5f6494365d926168c313b5de20a1b6d3de8d40f656f599dbb9eea8bbb39dea9` | `experiments/eurosat_spatial/prepare_eurosat.py` from EuroSAT_MS.zip |
| `experiments/results/eurosat_spatial/images_rgb.npy` | 663,552,128 | `341060c0fb016312331a90d3bf195b031b3a974d5f85f0b5ca5aa2b79a9e5d75` | `experiments/eurosat_spatial/prepare_eurosat.py` from EuroSAT_MS.zip |
| `experiments/results/eurosat_calib/cache/imgs.npy` | 331,776,128 | `a143866d1e6b3e20cf8fa4afa14fdc6067774cb5492c29fa3245fe01cae17027` | `experiments/eurosat_calib/run_eurosat_calib.py` from HF `blanchon/EuroSAT_RGB` |

### `experiments/xsensor_real/arrays/` (bulk-data dir, ~1.6 GB total; `s1_*.npy`/`s2_*.npy` gitignored, labels/sample_ids/prep_stats tracked)

Built by `experiments/xsensor_real/prep_so2sat.py` from GEO-Bench m-so2sat HDF5
(`classification_v0.9.1/m-so2sat`, downloadable via `geobench.geobench_download` — see
the header of `prep_so2sat.py`; source HDF5 dir referenced there:
`${DATA_ROOT}/geobench/classification_v0.9.1/m-so2sat`).

| File | Size (bytes) | SHA256 |
|---|---|---|
| `s1_train.npy` | 655,097,984 | `c6e08b00d23f1981b3f5ebfac6d28415c67b2d962fd866153cb982809554ea8e` |
| `s1_valid.npy` | 32,309,376 | `e0c8d1c5bcbca526457c76d0194670f64b948b8291ff128536e727d51f740743` |
| `s1_test.npy` | 32,309,376 | `d9aa301f5997f024773e3a330442c93348a5237d52b7d399b56c358d4997ce25` |
| `s2_train.npy` | 818,872,448 | `3d9666aa19816a109dc14df989365624d156b29e34b0dbc312b4b9839a490a66` |
| `s2_valid.npy` | 40,386,688 | `386d31dfb1cd0ae6d0fbed5fce8b4a6f3f9f8fe507cdf11cde4af564c31310e0` |
| `s2_test.npy` | 40,386,688 | `aa5ed1def5b210246140b6554af27564da792149a59c65457fa14b3b740e5f56` |

## Cached frozen-FM feature arrays (>50 MB, gitignored individually)

Extracted by the runner scripts from the frozen encoders (HuggingFace checkpoints, not
retained on disk — re-extraction requires re-pulling each model, see FABLE-HANDOFF.md).
Smaller sibling caches (`feats_ssl4eo_n27000.npy` 41 MB, `feats_prithvi_n6000_lim6000.npy`
24 MB, and the three `feats_*_n7669.npy` BigEarthNet caches, ~30 MB each) ARE tracked in git.

| Path | Size (bytes) | SHA256 | Built by |
|---|---|---|---|
| `experiments/results/eurosat_real_geo_shift_calib/cache/feats_prithvi_n27000_lim0.npy` | 110,592,128 | `1660ec06b22ac38ea53c29cd9acf3b8552bdf04262498e769d7619a4b2ea78f5` | `experiments/eurosat_xsensor_calib/` runners (Prithvi-EO-2.0-300M frozen encoder) |
| `experiments/results/eurosat_stage2_multifm_multialpha/cache/feats_clay_n27000.npy` | 110,592,128 | `fd6576317dbf7ae551380d173f9485f607a90db5eec58be56175fd6f43b89e70` | `experiments/eurosat_xsensor_calib/run_stage2_multi_fm_alpha.py` (Clay v1.5 frozen encoder) |
| `experiments/results/eurosat_stage2_multifm_multialpha/cache/feats_ssl4eo_mae_n27000.npy` | 82,944,128 | `cb4b8e92f55e199e0e1199ba5079d6c9aa0ae7de44f2cc6f56ea0c9d8d5c6a74` | `experiments/eurosat_xsensor_calib/run_stage2_multi_fm_alpha.py` (SSL4EO-S12 MAE frozen encoder) |
