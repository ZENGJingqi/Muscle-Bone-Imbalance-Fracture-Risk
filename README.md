# Muscle-Bone-Imbalance-Fracture-Risk

This repository accompanies a manuscript on a muscle-bone imbalance phenotype associated with fracture-related and osteoporosis-related burden. It documents the study scope, dataset access routes, downloaded external files, and lightweight public preprocessing and analysis workflows that can help readers reproduce the external extension analyses.

## Study Overview

![Study overview](assets/study_overview.png)

This overview summarizes the methodological logic of the study and the rationale for evaluating a body composition-based muscle-bone imbalance phenotype in relation to osteoporosis and fracture-related risk. The manuscript combines one original Chinese discovery dataset with four external datasets that address bridge validity, structural consistency, and older-adult clinical outcome context.

## How to Use This Repository

This repository is structured around the manuscript rather than around a software package.

Recommended reading order:

1. Start with the current `README.md` for the study rationale and dataset roles.
2. Open `datasets/Chinese-Human-Body-Composition/README.md` for the discovery cohort access note.
3. Open `datasets/NHANES`, `datasets/KNHANES`, `datasets/HRS`, and `datasets/CHARLS` for dataset-specific scope, data-source URLs, preprocessing notes, and concise findings.
4. Use `code/` only if you want to reproduce the public external workflows locally after obtaining the source datasets yourself.

## Study Scope

The manuscript combines:

- one original Chinese discovery dataset
- four external datasets used for extension and validation:
  - `NHANES`
  - `KNHANES`
  - `HRS`
  - `CHARLS`

The goal is not to claim universal transferability of the original Chinese cutoff. Instead, the combined analyses were used to address four distinct questions:

1. Can BIA-derived body composition be bridged to DXA-derived body composition?
2. Does a DXA-derived muscle-to-bone ratio show structural and risk consistency in external populations?
3. Do U.S. older-adult clinical outcomes show a compatible age- and sex-related context?
4. Do Chinese older-adult clinical outcomes show a compatible age- and sex-related context?

## Chinese Discovery Dataset

The original Chinese dataset is not redistributed in this repository.

### Availability of Data and Material

The **"Human Body Composition Dataset for the Chinese Population"** can be accessed through the National Population Health Data Center:

- main portal: <https://www.ncmi.cn/>
- direct dataset page: <https://www.ncmi.cn//phda/dataDetails.do?id=CSTR:A0006.11.A0005.201905.000346>

License:

- `Creative Commons - Attribution 4.0 International`

This repository instead focuses on the external datasets and the associated reproducible workflow.

## External Datasets

### NHANES

- role: `BIA-DXA bridge` and `DXA-derived MBR` risk consistency
- range used: `1999-2004` and `2013-2014`
- official source: <https://wwwn.cdc.gov/nchs/nhanes/>

### KNHANES

- role: `East Asian DXA external validation`
- range used: `2008-2011`
- official source: <https://knhanes.kdca.go.kr/knhanes/eng/index.do>

### HRS

- role: `U.S. older-adult clinical outcome context`
- range used: `RAND HRS Fat Files 2012-2022`
- official source: <https://hrsdata.isr.umich.edu/data-products>

### CHARLS

- role: `Chinese older-adult clinical outcome context`
- range used: `2011, 2013, 2015, 2018, 2020 main waves` plus `Harmonized CHARLS`
- official source: <https://charls.charlsdata.com/>

## Reproducibility Map

| Question | Dataset | Main Folder |
| --- | --- | --- |
| Original discovery signal | Chinese Human Body Composition Dataset | `datasets/Chinese-Human-Body-Composition` |
| BIA-to-DXA bridge and DXA-based risk consistency | `NHANES` | `datasets/NHANES` and `code/NHANES` |
| East Asian DXA external consistency | `KNHANES` | `datasets/KNHANES` and `code/KNHANES` |
| U.S. older-adult clinical outcome context | `HRS` | `datasets/HRS` and `code/HRS` |
| Chinese older-adult clinical outcome context | `CHARLS` | `datasets/CHARLS` and `code/CHARLS` |

## Repository Structure

```text
Muscle-Bone-Imbalance-Fracture-Risk/
  README.md
  .gitignore
  assets/
    study_overview.png
  code/
    NHANES/
    KNHANES/
    HRS/
    CHARLS/
  datasets/
    Chinese-Human-Body-Composition/
      README.md
    NHANES/
      README.md
    KNHANES/
      README.md
    HRS/
      README.md
    CHARLS/
      README.md
    TEMPLATE_NEW_DATASET.md
```

## Current Interpretation

- Original Chinese cohort: `BIA-based MBR`
- NHANES / KNHANES: `DXA-derived MBR`
- HRS / CHARLS: `older-adult clinical outcome context`
- Overall concept: `muscle-bone imbalance phenotype`

The current evidence supports the biological, structural, and clinical relevance of this phenotype, while indicating that the original Chinese threshold should be treated as a cohort-specific discovery threshold rather than a universally transferable screening cutoff.

## Data Availability

This repository does **not** include the original Chinese participant-level data, external raw data files, cleaned participant-level datasets, or large local result bundles.

Reasons:

- some datasets require registration or application
- large files are not appropriate for a lightweight GitHub methods repository
- the purpose here is to document dataset access, preprocessing logic, analysis design, and key findings

## What This Repository Provides

- dataset-specific notes for the Chinese cohort and the four external datasets
- official dataset source URLs and the exact survey ranges used
- downloaded file names, formats, and locally checked version notes for the external datasets
- lightweight public code for NHANES, KNHANES, HRS, and CHARLS
- a template for adding future datasets such as `SHARE`

## Public Analysis Code

The public code in this repository is limited to the external datasets:

- `code/NHANES`
- `code/KNHANES`
- `code/HRS`
- `code/CHARLS`

No public participant-level code or data release is provided here for the original Chinese discovery cohort.

## Citation

If this repository supports your work, please cite the associated manuscript once the final paper details are available.
