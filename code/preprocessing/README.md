# Preprocessing and QC

This folder contains preprocessing-related validation and task-EEG mapping/QC scripts used by the manuscript code companion.

## Suggested order

1. `STEP01B_RESTING_QC_FINAL.m`  
   Performs strict resting-state EO/EC QC using locally available resting outputs.

2. `STEP01D_RESTING_FINAL.m`  
   Uses STEP01B outputs for the final resting-state validation/report stage.

3. `STEP03T_TPHASES_ONLY.m`  
   Scans local MAT files for `T_phases` information and creates the selected task-phase map.

4. `STEP03U_TPHASES_TO_EDF_MAP.m`  
   Maps task-phase information to the available EEG recordings.

5. `STEP03V3_TASK_EEG_FINALQC.m`  
   Reconstructed final-QC bridge that applies the documented final N=22 set, checks three-run completeness, audits duplicate keys, and writes the canonical `*_FINAL.csv` outputs expected downstream.

## Important provenance note

The historical original STEP03V3 source was not available when the public repository was assembled.

The included STEP03V3 is explicitly a transparent reconstruction. It does not re-extract spectral features or redefine phase windows. It expects locally available run-level feature outputs from the historical extraction stage.

The manuscript-aligned primary spectral windows are implemented separately in:

`../robustness/STEP10_FINAL_ARTICLE1_MATCHED_WINDOWS_N22.m`

Primary windows there are 0–0.6 s stimulus, 0–1.0 s maintenance, and 0–0.6 s retrieval, without a spectral pre-event baseline.
