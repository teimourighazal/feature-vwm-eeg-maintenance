# Behavioral Analysis

This folder contains behavioral-data discovery, participant-level timing summaries, alignment with the final EEG sample, report generation, and exploratory EEG–behavior association analyses.

## Suggested order

1. `STEP02_BEHAVIOR_SCAN.m`
2. `STEP02B_BEHAVIOR_TABLE_INSPECT.m`
3. `STEP02C_BEHAVIOR_EXTRACT.m`
4. `STEP02D_BEHAVIOR_FINAL.m`
5. `STEP04A0_BEHAVIOR_SOURCE_AUDIT.m`
6. `STEP04C_ALIGN_STEP122_RT_WITH_EEG.m`
7. `STEP04D_RT_FINAL_REPORT.m`
8. `STEP04D4_RT_SUBJECT_LEVEL_REPORT_TABLES.m`
9. `STEP05_RT_EEG_CORRELATION.m`
10. `STEP05B_RT_EEG_ROBUSTNESS_CHECK.m`

## Behavioral timing definition

The reconstructed timing measure is based on retrieval onset to next-trial onset.

Legacy filenames retain `RT` for compatibility, but the measure should be described as a **reconstructed response interval**, not as conventional reaction time.

## STEP04D provenance

The historical original STEP04D source was not available when the public repository was assembled.

`STEP04D_RT_FINAL_REPORT.m` is therefore an explicitly labeled transparent reconstruction. It builds the report-stage files from STEP04C outputs and preserves the filenames required by STEP04D4 and STEP05. It does not re-estimate behavioral intervals from raw data.

## Intermediate inputs

STEP04C requires the locally generated STEP122 reconstructed-interval trial-level input. That historical upstream data-generation stage is not distributed in this public repository.

Exploratory STEP05/STEP05B EEG–behavior associations should be interpreted as secondary analyses.
