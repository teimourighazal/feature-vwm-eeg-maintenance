# Spectral Analysis

This folder contains the principal channel-level, ROI-level, and focused spectral analyses.

## Suggested order

1. `STEP03W3_TASK_EEG_STATS.m`  
   Participant-level task-EEG spectral statistics from the final subject-feature table.

2. `STEP06A_NEURO_ROI_TOPO_SUMMARY.m`  
   ROI and topographic summary analyses.

3. `STEP06C_HYPOTHESIS_DRIVEN_NEURAL_INDICES.m`  
   Focused neural indices, including posterior alpha and posterior gamma analyses.

4. `STEP06D5_FINAL_NEURO_FIGURE_TABLE_PACKAGE_STRICTCSV.m`  
   Final figure/table packaging for the focused neural results.

## Interpretation constraints

The posterior alpha maintenance effect is color-dominant.

The posterior gamma maintenance effect is orientation-dominant, with conjunction also potentially exceeding color. It should not be described as a conjunction-specific binding effect.

The posterior-minus-anterior alpha gradient was not reliably significant after correction and should not be presented as a confirmed directional effect.

## Spectral windows

The manuscript-aligned re-analysis with the final primary windows is implemented in:

`../robustness/STEP10_FINAL_ARTICLE1_MATCHED_WINDOWS_N22.m`

Those windows are:

- stimulus: 0–0.6 s;
- maintenance: 0–1.0 s;
- retrieval: 0–0.6 s.

No pre-event baseline is included in spectral feature calculation.
