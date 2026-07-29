# Cover letter — IEEE Transactions on Geoscience and Remote Sensing (TGRS)

Dear Prof. Jia, Editor-in-Chief, and Associate Editors,

We submit our manuscript, "Geographic coverage debt of frozen Earth-observation foundation
models: an encoder-robustness reliability diagnostic and a conditional target-recalibration
remedy," for consideration in IEEE Transactions on Geoscience and Remote Sensing.

Across thirteen frozen geospatial foundation-model encoders evaluated on GEO-Bench
BigEarthNet-S2 under real cross-region shift, every encoder meets its in-distribution
false-negative-rate risk-control guarantee, yet all thirteen incur a real reliability debt once
deployed off-region, with false-negative rates running 2.6-4.7 times the nominal target. A
deterministic accuracy boundary (about 0.80) marks where this audit stops mattering, since prediction
sets collapse to singletons above it. An unlabeled covariate-shift correction recovers only part
of the debt, but a labeled target-region slice (about 30% of target data) reliably restores the
guarantee, at the cost of larger yet still informative prediction sets (22-24 of about 27 active
labels).

This work gives practitioners finite-sample statistical guarantees on when a frozen
Earth-observation foundation model can be trusted after a regional move, and a concrete
labeled-data prescription for restoring that guarantee once shift breaks it — a distribution-free
reliability audit, built on split-conformal risk control, that speaks directly to TGRS's
readership deploying these encoders operationally. The manuscript also reports its negative and
conditional findings as plainly as its positive ones, which we regard as a strength for a
reliability-focused audit.

We confirm that this is original work, that it is not under consideration elsewhere, and that the
single author has approved the submission.

Thank you for your consideration.

Sincerely,

Zeyu Fu  
ORCID: 0009-0001-8329-0108  
e-mail: fuzeyu09@gmail.com  
State Key Laboratory of Trauma and Chemical Poisoning, Institute of Combined Injury,  
Army Medical University, Chongqing, China

Date: [at submission]

---
**Suggested reviewers** (TODO-USER: supply three; leave blank if you prefer the editors choose):
1. TODO-USER — expertise: geospatial / Earth-observation foundation models (Prithvi, Clay, SSL4EO).
2. TODO-USER — expertise: conformal prediction / calibration under distribution shift.
3. TODO-USER — expertise: remote-sensing scene classification and cross-region generalization (Sentinel-2).
Pick reviewers without a recent co-authorship or shared-institution conflict with the author.

**Funding statement:** TODO-USER (state grant/support, or "The author received no specific funding
for this work.").
