# Feature-Based Visual Working Memory EEG Analysis

MATLAB code accompanying an EEG study of condition-dependent neural activity during feature-based visual working memory.

The analyses examine EEG activity across encoding, maintenance, and retrieval for three visual working-memory conditions: color, orientation, and conjunction.

## Associated Manuscript

**Working title:**  
*Condition-Dependent Spectral and Time-Domain EEG Differences in Feature-Based Visual Working Memory Were Predominantly Observed During Maintenance*

This repository contains the analysis code used to generate the main spectral, time-domain, behavioral, and robustness results reported in the manuscript.

## Study Overview

EEG was recorded using a 64-channel system during a visual working-memory task involving three experimental conditions:

- Color
- Orientation
- Conjunction

Each participant completed three task runs.

The analyses focused on three task phases:

- Encoding
- Maintenance
- Retrieval

Primary statistical inference was performed at the participant level.

## Repository Structure

```text
code/
├── 01_preprocessing_and_validation/
├── 02_behavior/
├── 03_spectral_analysis/
├── 04_erp_analysis/
├── 05_maintenance_slow_wave/
└── 06_robustness/
