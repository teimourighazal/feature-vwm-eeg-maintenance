# Feature-Based Visual Working Memory EEG Analysis

MATLAB code accompanying an EEG study of condition-dependent neural activity during feature-based visual working memory.

The analyses examine EEG activity across encoding, maintenance, and retrieval for three visual working-memory conditions: color, orientation, and conjunction.

## Associated Manuscript

**Working title:**  
*Condition-Dependent Spectral and Time-Domain EEG Differences in Feature-Based Visual Working Memory Were Predominantly Observed During Maintenance*

This repository contains MATLAB code for the spectral, behavioral, time-domain, maintenance-period, and robustness analyses associated with the manuscript.

## Study Overview

EEG was recorded from 64 channels during a visual working-memory task involving three experimental conditions:

- Color
- Orientation
- Conjunction

Each participant completed three task runs.

The analyses focused on three task phases:

- Encoding
- Maintenance
- Retrieval

Primary EEG analyses were conducted in 22 participants, with statistical inference performed at the participant level rather than treating individual trials or runs as independent observations.

Some secondary analyses used smaller samples according to data availability:

- Reconstructed behavioral response-interval analysis: complete-case N = 19
- Exploratory correct-versus-incorrect ERP analysis: N = 14

## Repository Structure

### `code/preprocessing`

Scripts for preprocessing-related validation, resting-state checks, and mapping task-phase information to EEG recordings.

### `code/behavior`

Scripts for behavioral-data processing, reconstruction of response-related intervals, participant-level summaries, and statistical comparisons.

### `code/spectral_analysis`

Scripts for the primary EEG spectral analyses at the channel, region-of-interest (ROI), and focused posterior-region levels.

These analyses evaluate condition-dependent spectral activity across encoding, maintenance, and retrieval.

### `code/erp_analysis`

Scripts for time-domain EEG analyses, including phase-locked amplitude measures and exploratory correct-versus-incorrect ERP analyses.

### `code/maintenance_slow_wave`

Scripts for analyses of sustained EEG amplitude during the maintenance period and associated robustness assessments.

### `code/robustness`

Sensitivity and stability analyses used to evaluate the main EEG findings, including:

- Equal-duration phase comparisons
- ICA-based artifact-removal sensitivity analysis
- Alpha-, beta-, and gamma-band restricted analyses
- Leave-one-participant-out stability analysis

## Analysis Principles

Statistical inference was conducted at the participant level.

Individual trials and runs were not treated as independent participants.

False discovery rate (FDR) correction was applied where appropriate to control for multiple comparisons.

Sensitivity analyses were used to assess whether the main findings depended on analysis-window duration, artifact-removal strategy, lower-frequency activity, or individual participants.

## Main Findings

Condition-dependent EEG differences were predominantly observed during the maintenance period.

The main spectral findings included:

- A posterior alpha effect during maintenance, with higher alpha activity in the color condition.
- A posterior gamma effect during maintenance, with higher gamma activity for orientation-related conditions relative to color.
- No reliable posterior-minus-anterior alpha-gradient effect after correction.

Time-domain analyses also identified condition-dependent differences during the maintenance period, including sustained maintenance-related activity.

The robustness analyses supported the overall maintenance-centered pattern, while the results did not indicate uniform superiority of maintenance across every analysis.

## Software Requirements

The analysis code was written in MATLAB.

Relevant software includes:

- MATLAB
- EEGLAB
- MATLAB Statistics and Machine Learning Toolbox

Some robustness analyses additionally use EEGLAB functions related to ICA and component classification.

Several scripts are compatible with MATLAB R2021a. Exact MATLAB, EEGLAB, and plugin versions used for the archived publication release should be documented before final repository release.

## Running the Code

Most helper functions are included as local functions within the corresponding MATLAB scripts.

Before running the analyses:

1. Download or clone this repository.
2. Install MATLAB and the required EEGLAB dependencies.
3. Prepare the required de-identified input data.
4. Replace project-specific local paths with paths appropriate for your system.
5. Run the relevant scripts from the corresponding analysis directory.

The raw EEG recordings are not distributed with this GitHub repository.

## Data Availability

Raw EEG and participant-identifiable data are not included in this repository because of ethical, privacy, and participant-consent considerations.

Requests for access to de-identified data may be considered by the corresponding author, subject to applicable ethical and institutional approvals.

## Reproducibility

This repository includes code for the primary analyses and sensitivity analyses used to evaluate the robustness and stability of the reported findings.

Leave-one-participant-out analysis is used as a stability assessment and should not be interpreted as a substitute for independent replication in a larger sample.

## Citation

If you use this code, please cite the associated article and this repository.

Repository citation metadata are provided in `CITATION.cff`.

The citation information will be updated when the final article publication details and DOI become available.

## License

The source code in this repository is released under the MIT License.

See the `LICENSE` file for details.

## Contact

For questions regarding the analysis code, please use the GitHub Issues section of this repository.
