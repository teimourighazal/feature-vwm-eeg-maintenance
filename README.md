# Feature-Based Visual Working Memory EEG Analysis

MATLAB code accompanying an EEG study of condition-dependent neural activity during feature-based visual working memory.

The analyses examine EEG activity across encoding, maintenance, and retrieval for three visual working-memory conditions: color, orientation, and conjunction.

## Associated Manuscript

**Working title:**  
*Condition-Dependent Spectral and Time-Domain EEG Differences in Feature-Based Visual Working Memory Were Predominantly Observed During Maintenance*

## Study Overview

EEG was recorded from 64 channels during a visual working-memory task. Each participant completed three task runs.

Primary EEG analyses were conducted in 22 participants, with statistical inference performed at the participant level rather than treating individual trials or runs as independent observations.

Some secondary analyses used smaller samples according to data availability:

- reconstructed behavioral response-interval analysis: N = 20, complete-case N = 19;
- exploratory correct-versus-incorrect ERP analysis: N = 14.

The behavioral timing measure used in the reconstructed interval analyses corresponds to retrieval onset to next-trial onset. It is not treated as a conventional reaction time.

## Primary Analysis Windows

The manuscript-aligned spectral analysis uses the following post-onset windows:

- stimulus / early encoding: 0 to 0.6 s;
- maintenance: 0 to 1.0 s;
- retrieval: 0 to 0.6 s.

No pre-event baseline interval is included in spectral feature calculation.

An equal-duration 0 to 0.6 s window is used only for direct cross-phase sensitivity analysis.

## Repository Structure

### `code/preprocessing`

Preprocessing-related validation, resting-state checks, task-phase mapping, and final-QC support.

### `code/behavior`

Behavioral-data discovery, reconstruction support, participant-level summaries, condition statistics, report tables, and exploratory EEG–behavior associations.

### `code/spectral_analysis`

Primary channel-level, ROI-level, and focused spectral analyses.

### `code/erp_analysis`

Time-domain condition analyses and exploratory correct-versus-incorrect ERP analyses.

### `code/maintenance_slow_wave`

Maintenance-period slow-wave analyses and robustness checks.

### `code/robustness`

Sensitivity and stability analyses, including equal-duration windows, ICA sensitivity, higher-frequency-only robustness, and leave-one-participant-out stability.

Each code subfolder contains its own `README.md` with the local execution order and main dependencies.

## Analysis Principles

Statistical inference was conducted at the participant level.

Individual trials and runs were not treated as independent participants.

False discovery rate (FDR) correction was applied where appropriate.

Sensitivity analyses were used to evaluate dependence on analysis-window duration, artifact-removal strategy, lower-frequency activity, and individual participants.

## Main Findings

Condition-dependent EEG differences were predominantly observed during maintenance.

The main spectral findings included:

- a posterior alpha effect during maintenance, with higher alpha activity in the color condition;
- a posterior gamma effect during maintenance, with higher gamma activity for orientation-related conditions relative to color;
- no reliable posterior-minus-anterior alpha-gradient effect after correction.

Time-domain analyses also identified condition-dependent differences during maintenance, including sustained maintenance-related activity.

Robustness analyses supported the overall maintenance-centered pattern, while not indicating uniform superiority of maintenance across every analysis.

## Reproducibility Scope

This repository is intended as the public code companion to the manuscript.

Raw EEG recordings and participant-identifiable data are not distributed here. Some scripts therefore require local de-identified raw data or intermediate CSV/MAT files generated in the original analysis environment.

Two historical source scripts were not available when the public repository was assembled:

- `STEP03V3_TASK_EEG_FINALQC.m`
- `STEP04D_RT_FINAL_REPORT.m`

The versions included here are explicitly labeled **transparent reconstructions**. They preserve documented inputs, outputs, participant-level rules, and downstream file interfaces, but they should not be represented as the original historical source files.

`STEP03V3_TASK_EEG_FINALQC.m` is a QC/compatibility bridge and does not redefine spectral windows or re-extract the manuscript-aligned spectral features.

`STEP04D_RT_FINAL_REPORT.m` reconstructs the behavioral report-building stage from STEP04C outputs and does not re-estimate the behavioral intervals from raw data.

The revised manuscript-aligned spectral re-analysis is implemented separately in:

`code/robustness/STEP10_FINAL_ARTICLE1_MATCHED_WINDOWS_N22.m`

## Running the Code

Most scripts now use project-relative paths and interactive file/folder selection rather than machine-specific absolute paths.

A practical workflow is:

1. clone or download the repository;
2. install MATLAB and required EEGLAB dependencies;
3. prepare the required local de-identified raw/intermediate inputs;
4. run the relevant scripts in the order described in each subfolder README;
5. verify generated QC summaries before using downstream outputs.

The repository was statically audited for path portability, but not every script can be executed without the private/raw data environment.

## Software Requirements

The analysis code was written in MATLAB.

Relevant software includes:

- MATLAB;
- EEGLAB;
- MATLAB Statistics and Machine Learning Toolbox.

Some robustness analyses additionally use EEGLAB ICA/component-classification functionality.

Several scripts are compatible with MATLAB R2021a.

Exact MATLAB, EEGLAB, and plugin versions used for the archived publication release should be documented when those version records are available.

## Data Availability

Raw EEG and participant-identifiable data are not included because of ethical, privacy, and participant-consent considerations.

Requests for access to de-identified data may be considered by the corresponding author in accordance with applicable ethical and institutional requirements.

## Citation

If you use this code, please cite the associated article and this repository.

Repository citation metadata are provided in `CITATION.cff`.

The citation information can be updated when final article publication details and DOI become available.

## License

The source code in this repository is released under the MIT License.

See `LICENSE` for details.

## Contact

For questions regarding the analysis code, please use the GitHub Issues section of this repository.
