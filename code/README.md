# Code

This folder contains lightweight public code corresponding to the external datasets and sensitivity analyses used in the project.

The code is organized by dataset:

- `code/NHANES`
- `code/KNHANES`
- `code/HRS`
- `code/CHARLS`
- `code/SHARE`
- `code/Sensitivity`

## Expected Local Directory Layout

The scripts assume a simple project layout:

```text
Muscle-Bone-Imbalance-Fracture-Risk/
  code/
  data/
    raw/
    processed/
  outputs/
```

## Principles

- Raw data are not included in the repository.
- Processed participant-level data are not included in the repository.
- The scripts are provided to document preprocessing logic, analysis structure, and output generation.
- Users should adapt file naming and access requirements according to their own approved dataset downloads.
- No public participant-level code or data release is provided here for the original Chinese discovery cohort.
- Scripts used only for manuscript drafting, Word/PDF generation, submission formatting, or local writing records are not included.

## Script Summary

### NHANES

- `prepare_nhanes_inputs.py`
- `check_nhanes_consistency.py`
- `run_nhanes_external_analysis.R`

### KNHANES

- `prepare_knhanes_2008_2011.R`
- `run_knhanes_external_analysis.R`

### HRS

- `prepare_hrs_fat_2012_2022.R`
- `run_hrs_fat_event_analysis.R`

### CHARLS

- `prepare_charls_clinical_context.R`
- `run_charls_clinical_context_analysis.R`

### SHARE

- `analyze_share_rel9.R`

### Sensitivity

- `run_survey_weighted_sensitivity.R`
- `run_rcs_threshold_performance.R`

## Minimal Reproduction Order

1. Obtain the relevant external dataset files through the official source.
2. Place the downloaded files under `data/raw/` using your own approved local naming.
3. Run the dataset-specific preprocessing script first.
4. Run the dataset-specific analysis script second.
5. Run the SHARE script after obtaining Gateway Harmonized SHARE Release 9.0.0 if European older-adult clinical outcome context outputs are needed.
6. After NHANES and KNHANES processed files are available, run the sensitivity scripts if survey-weighted, restricted cubic spline, or threshold-performance outputs are needed.
7. Inspect generated outputs under `outputs/`.
