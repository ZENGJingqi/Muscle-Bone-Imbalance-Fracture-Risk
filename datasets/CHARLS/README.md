# CHARLS

## Role in the Project

CHARLS was used as the Chinese older-adult clinical outcome context dataset. It was not used to directly validate the original Chinese `BIA-based MBR` or the original threshold. Instead, it was used to evaluate whether falls and hip fracture followed coherent age- and sex-related gradients in a Chinese aging population that are compatible with the broader clinical relevance of a muscle-bone imbalance phenotype.

## Official Source

- official portal: <https://charls.charlsdata.com/>

## Scope Used in This Project

Main-wave data used:

- `2011 Wave 1`
- `2013 Wave 2`
- `2015 Wave 3`
- `2018 Wave 4`
- `2020 Wave 5`

Additional harmonized source used:

- `Harmonized CHARLS`

## Data Components Used

Main files used locally:

- wave-specific `Health_Status_and_Functioning`
- `Demographic_Background` for 2020
- `H_CHARLS_D_Data` from Harmonized CHARLS

Main outcomes used:

- recent fall
- reported hip fracture
- fall needing medical treatment (`2018` and `2020` only)

Main covariates used:

- age
- sex
- survey year

## Downloaded Files Used Locally

Representative local archives used:

- `household_and_community_questionnaire_data_2011_CHARLS_Wave1.rar`
- `CHARLS2013_Dataset.zip`
- `CHARLS2015r.zip`
- `CHARLS2018r.zip`
- `CHARLS2020r.zip`
- `H_CHARLS_D_Data.zip`

Additional supporting downloads present locally:

- `2008_pilot_resurvey_2012.zip`
- `CHARLS_Life_History_Data.zip`
- `H_CHARLS_D_do_file.zip`
- `H_CHARLS_LH_a.zip`
- `H_CHARLS_EOL_a.zip`

Documentation files checked locally:

- `Chinese_users_guide_20130407.pdf`
- `CHARLS_codebook.rar`
- `Community_questionnaire_C_and_E_20130312.pdf`

Format:

- downloaded `.rar` and `.zip` archives
- extracted `.dta` files
- local processed outputs written as `.rds` and `.csv.gz`

Representative local file date:

- checked in local workspace on `2026-04-24`

## Local Version Notes

The current CHARLS workflow in this repository corresponds to:

- main waves `2011, 2013, 2015, 2018, 2020`
- `Harmonized CHARLS` used for stable age and sex harmonisation across earlier waves

The locally generated processed files were:

- `CHARLS_2011_2020_clinical_context_bundle.rds`
- `CHARLS_2011_2020_clinical_context_bundle.csv.gz`

## Preprocessing

The CHARLS workflow harmonized conceptually comparable outcomes across waves rather than relying on identical raw variable names in every wave.

Outcome mapping logic:

- `recent fall`: pooled across wave-specific fall items
- `reported hip fracture`: pooled across wave-specific hip fracture items
- `fall needing medical treatment`: restricted to `2018` and `2020` because those waves had directly comparable recent-event follow-up items

Age and sex were obtained from:

- `Harmonized CHARLS` for `2011-2018`
- raw `Demographic_Background` for `2020`

The main analytic sample included adults aged `50 years or older` with non-missing sex.

## Analysis Strategy

Three summary layers were produced:

1. prevalence by wave and sex
2. age- and sex-stratified prevalence in `2020`
3. adjusted logistic regression for age and sex

Main pooled model:

- `2011-2020` for recent fall and reported hip fracture

Restricted recent-event model:

- `2018-2020` for recent fall, fall needing medical treatment, and reported hip fracture

Main covariates:

- age
- sex
- survey year

## Main Results

Analytic sample sizes aged `>=50`:

- `2011`: `13,391`
- `2013`: `14,783`
- `2015`: `16,385`
- `2018`: `17,199`
- `2020`: `17,293`

Cross-wave descriptive pattern:

- women consistently had higher recent-fall prevalence than men
- hip fracture prevalence was lower but still showed a stable female excess

Adjusted associations:

- pooled `2011-2020` recent fall:
  - per 10-year age increase: `OR 1.308`
  - female vs male: `OR 1.514`
- pooled `2011-2020` reported hip fracture:
  - per 10-year age increase: `OR 1.483`
  - female vs male: `OR 1.238`
- restricted `2018-2020` fall needing medical treatment:
  - per 10-year age increase: `OR 1.361`
  - female vs male: `OR 1.778`

## Interpretation

CHARLS supports the Chinese older-adult clinical event layer of the manuscript. It strengthens the claim that the outcome framework most relevant to the muscle-bone imbalance concept, especially falls and hip fracture, behaves in the expected high-risk direction in the target population.

CHARLS should **not** be interpreted as:

- direct validation of `BIA-based MBR`
- direct validation of `MBR = 16`
- a mature standalone screening-tool validation dataset

The correct role is:

- Chinese older-adult clinical outcome context

## Local Script References

- `code/CHARLS/prepare_charls_clinical_context.R`
- `code/CHARLS/run_charls_clinical_context_analysis.R`
