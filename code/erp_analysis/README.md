# ERP and Time-Domain Analysis

This folder contains the condition-based time-domain analyses and the exploratory correct-versus-incorrect ERP branch.

## Main condition-based branch

1. `STEP09A2_CONDITION_ERP_WINDOWS_N22_ROIFIX.m`  
   Main N=22 condition-based ERP/time-domain analysis. Generates the merged trial-phase table also used by downstream maintenance and robustness analyses.

2. `STEP09C3_ERP_PHASE_FIGURE_PACKAGE_A2B3.m`  
   Figure/table packaging based on STEP09A2 and maintenance slow-wave outputs.

## Correct-versus-incorrect exploratory branch

1. `STEP08C6_FORCED_CORRECTNESS_FROM_TRIALDATA_ONLY.m`
2. `STEP08D2_ERP_FORCED_C6_CORRECTNESS_N14_KEYFIX.m`

The correct-versus-incorrect ERP analysis used the smaller available sample (N=14) and did not yield FDR-corrected effects. It should therefore remain exploratory/negative rather than being presented as a primary positive result.

## Notes

Condition-based maintenance-onset amplitude windows should not be described as classical sensory ERP components when they occur after maintenance onset.
