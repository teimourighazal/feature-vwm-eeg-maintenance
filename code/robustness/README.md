# Robustness and Sensitivity Analyses

This folder contains the manuscript robustness analyses.

## Suggested order

1. `STEP10_FINAL_ARTICLE1_MATCHED_WINDOWS_N22.m`  
   Manuscript-aligned spectral re-analysis using the final primary windows and an equal-duration direct-phase sensitivity branch.

2. `STEP12B_ICA_RECOVERY_COMPLETE66_N22.m`  
   ICA-based artifact-removal sensitivity analysis across the complete 66-run N=22 dataset.

3. `STEP13_SHORTWINDOW_BAND_ROBUSTNESS_N22.m`  
   Higher-frequency-only robustness analysis assessing whether the maintenance-centered pattern depends on delta/theta activity.

4. `STEP14_SAMPLE_STABILITY_LOO_N22.m`  
   Leave-one-participant-out stability analysis.

## Key interpretation rule

The direct-phase equal-duration analysis supports wording that effects were **predominantly observed during maintenance**.

It does not support a claim that maintenance was uniformly or universally strongest across every analysis.

## Sample stability

STEP14 is a leave-one-participant-out stability analysis. It is not a substitute for independent replication.

No bootstrap analysis is part of the public manuscript workflow.
