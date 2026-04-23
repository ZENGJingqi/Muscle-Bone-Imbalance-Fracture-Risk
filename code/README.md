# Code

This folder contains lightweight public code corresponding to the three external datasets used in the project.

The code is organized by dataset:

- `code/NHANES`
- `code/KNHANES`
- `code/HRS`

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

## Minimal Reproduction Order

1. Obtain the relevant external dataset files through the official source.
2. Place the downloaded files under `data/raw/` using your own approved local naming.
3. Run the dataset-specific preprocessing script first.
4. Run the dataset-specific analysis script second.
5. Inspect generated outputs under `outputs/`.
