# Reproduction

## Run the revised analysis

Tested with R 4.5.1. Package versions are recorded in `sessionInfo.txt`. Required R packages: readr, dplyr, tidyr, survey, mitools, ggplot2 and pROC; splines is supplied with R. An optional `MBR_R_LIB` environment variable adds a user-managed R library; it is not needed when packages are normally installed.

From the repository root:

```sh
Rscript code/Publication/reanalyse.R data/processed/NHANES/NHANES_2013_2014_outcome_bundle.csv.gz data/processed/KNHANES/KNHANES_2008_2011_ALL_DXA_merged.rds data/processed/NHANES/NHANES_bridge_1999_2004_BIA_DXA.csv.gz outputs/publication
python code/check_public_release.py
```

All three inputs must be obtained or recreated by authorized users. Input hashes identify the exact reviewed bundles; differences require an explanation, not automatic replacement of the reference hashes. Outputs are written only to the fourth argument. Use a new output directory to retain earlier runs.

## Inputs and preparation

- NHANES: download the source XPT files from the [official portal](https://wwwn.cdc.gov/nchs/nhanes/). The retained `code/NHANES/prepare_nhanes_inputs.py` expects cycle folders under `data/raw/` and prepares the bundled tables. Python pandas is required. The 1999-2004 DXA release contains five imputations, and the cycle-person-imputation key must be retained. Never deduplicate it on SEQN alone.
- KNHANES: use authorized SAS examination and DXA files for 2008-2011. The retained preparation script expects `data/raw/KNHANES_2008_2011/all/hnYY_all.sas7bdat` and `dxa/hnYY_dxa.sas7bdat`; it requires haven, dplyr, readr and stringr. Run it from the repository root. Exact case-sensitive filenames should match the script on non-Windows systems.
- The new statistical pipeline was rerun on the existing cleaned bundles. The entire raw-download/preprocessing chain was not freshly rerun; the two preparation scripts are retained for provenance and require provider access.

## Definitions

NHANES MBR = DXDTOLE / DXDTOBMC. KNHANES MBR = (DW_WBT_LN - DW_WBT_BMC) / DW_WBT_BMC. KNHANES source SAS labels identify DW_WBT_LN as bone-inclusive lean mass. Both numerator and denominator are in grams.

NHANES 1999-2004 survey weighting uses 2/3 WTMEC4YR for 1999-2002 and 1/3 WTMEC2YR for 2003-2004. Correlations are Fisher-z transformed, estimated separately per imputation and Rubin-pooled. NHANES 2013-2014 uses WTMEC2YR. KNHANES sensitivity uses WT_ITVEX/4 and year-nested strata/PSUs. General examination weights do not fully address partial-year DXA participation in 2008 and 2011; weighted results are sensitivity analyses, not calibrated national prevalence estimates.

Natural splines use three internal knots (10%, 50%, 90%) plus range boundaries, giving four exposure degrees of freedom. Nonlinearity is tested on three explicitly constructed nonlinear contrasts after projecting the basis on the intercept and linear exposure. Weighted AUC uses pairwise concordance with half credit for ties, not an unweighted ROC coupled to weighted sensitivities.

Eight component models use the same complete cases and outcome-stratified ten-fold split, seed 20260804. Transformations for flexible models are trained within folds. Comparisons are exploratory, unweighted internal validation without cluster-aware folds or confidence intervals for performance differences. They are not independent validation of a clinical model.

## Warnings and limits

The survey software may report singleton strata after domain restriction; the script explicitly uses the grand-mean adjustment. The script reads only the required NHANES columns and stops if they produce parsing problems; unused questionnaire fields are not parsed. Inspect warnings when adapting to different releases. Rare outcomes and flexible models may be unstable. The Chinese discovery analysis was not reconstructed from participant-level data in this release.

## Clinical-context reanalysis

`code/Publication/reanalyse_context.R` takes six arguments: HRS event RDS, CHARLS context RDS, SHARE long-form RDS, RAND HRS longitudinal SAS file, CHARLS wave-weight root folder, and a new output directory. It additionally requires haven. For example:

```sh
Rscript code/Publication/reanalyse_context.R data/processed/HRS/HRS_fat_2012_2022_event_bundle.rds data/processed/CHARLS/CHARLS_2011_2020_clinical_context_bundle.rds data/processed/SHARE/share_rel9_outcomes_long_age50plus.rds data/raw/HRS/randhrs1992_2022v1.sas7bdat data/raw/CHARLS/weights outputs/context
```

The weight folder must contain one weight.dta/Weights.dta per year in subdirectories named with 2011, 2013, 2015, 2018 and 2020. Access is governed by the original providers; the inputs are not redistributed. The HRS input uses HHIDPN, the CHARLS input uses harmonized ID, and the SHARE bundle uses mergeid with fields fall_s, hip_ever and osteoporosis_med. Preparation scripts retained under the dataset folders are historical references; their output schemas must be checked against these contracts.

Models adjust for age per ten years, sex and categorical wave; SHARE also adjusts for country. Both unweighted and response-weighted models cluster observations by respondent. Positive available response/individual weights are required only for weighted models. CHARLS eleven-character IDs are normalized before joining 2011 weights. These are sensitivity analyses, not full complex-survey design estimates. None of the context datasets measures MBR. Unique respondents, respondent-wave observations and events are reported separately.

Official sources: [DXA imputation guidance](https://wwwn.cdc.gov/nchs/nhanes/dxa/dxafaq.aspx), [NHANES weights](https://wwwn.cdc.gov/nchs/nhanes/tutorials/weighting.aspx), [whole-body variable definitions](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2013/DataFiles/DXX_H.htm), [KNHANES](https://knhanes.kdca.go.kr/knhanes/eng/index.do), [HRS](https://hrsdata.isr.umich.edu/data-products), [CHARLS](https://charls.charlsdata.com/), [SHARE](https://releases.sharedataportal.eu/).
