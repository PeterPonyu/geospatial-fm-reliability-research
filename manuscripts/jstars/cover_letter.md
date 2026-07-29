# Cover letter — IEEE Journal of Selected Topics in Applied Earth Observations and Remote Sensing (JSTARS)

Date: TODO-USER

Dear Editor-in-Chief and Associate Editors,

We submit our manuscript, **"Geographic coverage debt of frozen Earth-observation foundation
models: an encoder-robustness reliability diagnostic and a conditional target-recalibration
remedy,"** for consideration in the IEEE Journal of Selected Topics in Applied Earth Observations
and Remote Sensing.

Frozen geospatial foundation models (GFMs) are increasingly used as off-the-shelf encoders, yet
their predictive reliability under geographic distribution shift is rarely audited. On a real
East→West Europe cross-region holdout of EuroSAT-MS (Sentinel-2, 27,000 tiles), the paper shows
that linear probes on five frozen GFMs — Prithvi-EO-2.0-300M, Clay v1.5, two SSL4EO-S12
encoders (ViT-S/16 DINO and ViT-B/16 MAE), and DOFA — incur a "geographic coverage debt": source-fit
split-conformal predictors systematically under-cover the shifted target. A target-side conformal correction repays this debt exactly where
it exists, restoring near-nominal coverage at a modest prediction-set-size cost on EuroSAT-MS
(larger on the harder BigEarthNet task). Crucially, the debt is encoder-dependent — it tracks each
model's calibration degradation under shift and yields a reproducible encoder ordering
(Prithvi > DOFA > SSL4EO-DINO > SSL4EO-MAE > Clay). The ordering of the original four encoders survives
a boundary-sensitivity sweep and a class-prior-balanced control; DOFA — a fifth, architecturally
distinct encoder added on the same EuroSAT grid — carries the second-heaviest coverage debt and is
repaired at two of three risk levels at the fixed P33 boundary. The pattern is reproduced on a
non-European GEO-Bench m-so2sat external validation across 42 multi-continent cities. The contribution is therefore a diagnostic and audit: coverage debt as an
encoder-robustness reliability diagnostic that ranks frozen GFMs by the fragility of their
off-distribution conformal guarantees.

The work fits JSTARS's applied Earth-observation scope directly: it audits widely used geospatial
foundation models on standard Sentinel-2 benchmarks under a realistic cross-region shift, and
delivers a practitioner-facing reliability diagnostic and a scoped recalibration recipe for
deploying frozen encoders on new regions — an applied remote-sensing reliability question rather
than a new network architecture.

In line with the paper's reliability emphasis, the abstract discloses its negative and conditional
results directly: the preregistered success criterion (universal restoration for both Prithvi and
Clay) returned KILL, and the conditional, encoder-dependent claim is presented as its honest
exploratory reframe; moreover a label-access ablation shows spatial conditioning is inert — a
non-spatial target-calibrated baseline matches spatial-Mondrian in all cells — so the remedy is
reported as standard split-conformal on a small labeled target slice, not a new method, and spatial
conditioning is reported as an honest negative result. We regard this transparency as central to
the paper's rigor.

We confirm that this manuscript is original work, is not under consideration or review elsewhere,
and has not been submitted in whole or part to any other venue. The single author has approved the
submission. Data and code availability are as stated in the manuscript's availability statement
(results reproducible from the frozen result files and released code; the datasets — EuroSAT,
BigEarthNet, GEO-Bench — are public).

Thank you for your consideration.

Sincerely,

Zeyu Fu
TODO-USER: affiliation line (department, institution, city, country)
e-mail: fuzeyu09@gmail.com

---
**Suggested reviewers** (TODO-USER: supply three; leave blank if you prefer the editors choose):
1. TODO-USER — expertise: geospatial / Earth-observation foundation models (Prithvi, Clay, SSL4EO).
2. TODO-USER — expertise: conformal prediction / calibration under distribution shift.
3. TODO-USER — expertise: remote-sensing scene classification and cross-region generalization (Sentinel-2).
Pick reviewers without a recent co-authorship or shared-institution conflict with the author.

**Funding statement:** TODO-USER (state grant/support, or "The author received no specific funding
for this work.").
