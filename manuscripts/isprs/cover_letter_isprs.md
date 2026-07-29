Dear Prof. Mallet and Prof. Weng,

We submit "Cross-European coverage debt of frozen optical Earth-observation foundation models: a pre-deployment reliability report card and a conditional target-recalibration remedy" for consideration in the ISPRS Journal of Photogrammetry and Remote Sensing.

The manuscript asks whether a frozen optical encoder's reliability survives regional transfer and what evidence is required to repair it. On GEO-Bench BigEarthNet-S2, all thirteen Sentinel-2 encoders satisfy their in-distribution false-negative-rate guarantee, yet all thirteen incur a 2.6-4.7-fold nominal FNR debt under the cross-European shift. The debt is paid for through larger prediction sets rather than a uniformly better encoder; FNR robustness and set size are associated across the roster (Spearman rho=-0.66, p=0.017).

We package the analysis as a four-number pre-deployment report card: the in-distribution guarantee, shifted debt, labeled target-slice cost of repair, and worst-class coverage hidden by a marginal guarantee. The manuscript also states where the report card does not add information. Above an empirical accuracy boundary near 0.80, marginal single-label conformal sets collapse to singletons and reproduce accuracy. Standard unlabeled corrections do not close the observed debt because density-ratio effective sample size collapses; the validated repair requires labeled target-region calibration and is presented as a priced data requirement, not a label-free solution.

The principal evidence is cross-European optical transfer, complemented by a multi-city LCZ arm. A Sentinel-1 cross-sensor probe failed its in-distribution control and is withheld, so no cross-sensor claim is made. Encoder rankings remain exploratory; the powered results are the universal 13/13 FNR debt, the set-size tradeoff, and the worst-class gap.

The manuscript is original, is not under consideration elsewhere, and includes the required declarations and reproducibility records.

Sincerely,
Zeyu Fu
fuzeyu09@gmail.com
