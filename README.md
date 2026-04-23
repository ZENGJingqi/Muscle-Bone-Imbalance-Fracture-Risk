# Muscle-Bone-Imbalance-Fracture-Risk

This repository documents the external data processing and analysis workflow used to support a muscle-bone imbalance phenotype associated with fracture-related and osteoporosis-related burden outside the original Chinese cohort.

The current repository focuses on three external datasets:

- `NHANES`
- `KNHANES`
- `HRS`

The goal is not to claim universal transferability of the original Chinese cutoff. Instead, these external analyses were used to address three distinct questions:

1. Can BIA-derived body composition be bridged to DXA-derived body composition?
2. Does a DXA-derived muscle-to-bone ratio show structural and risk consistency in external populations?
3. Do older-adult clinical outcomes show a compatible age- and sex-related context?

## Repository Structure

```text
Muscle-Bone-Imbalance-Fracture-Risk/
  README.md
  .gitignore
  datasets/
    NHANES/
      README.md
    KNHANES/
      README.md
    HRS/
      README.md
    TEMPLATE_NEW_DATASET.md
```

## Current Interpretation

- Original Chinese cohort: `BIA-based MBR`
- NHANES / KNHANES: `DXA-derived MBR`
- HRS: `older-adult clinical outcome context`
- Overall concept: `muscle-bone imbalance phenotype`

The current evidence supports the biological, structural, and clinical relevance of this phenotype, while indicating that the original Chinese threshold should be treated as a cohort-specific discovery threshold rather than a universally transferable screening cutoff.

## Data Availability

This repository does **not** include raw data files, cleaned participant-level datasets, or large figure outputs.

Reasons:

- Some datasets require registration or application.
- Large files are not appropriate for a lightweight GitHub methods repository.
- The purpose here is to document preprocessing logic, analysis design, and key findings.

## Local Analysis Scripts

The analyses described here were implemented locally using the following scripts:

- `scripts/run_nhanes_external_analysis.R`
- `scripts/run_knhanes_external_analysis.R`
- `scripts/prepare_hrs_fat_2012_2022.R`
- `scripts/run_hrs_fat_event_analysis.R`

## Planned Expansion

The current repository includes documentation for:

- `NHANES`
- `KNHANES`
- `HRS`

Additional datasets can be added later using:

- `datasets/TEMPLATE_NEW_DATASET.md`
