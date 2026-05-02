# SHARE

## Role in the Project

SHARE was used as the European older-adult clinical outcome context dataset. It was not used to directly validate the original Chinese `BIA-based MBR`, because SHARE does not provide the BIA or DXA body-composition variables required to construct MBR.

The analysis was used to evaluate whether fall-related limitation, hip fracture, and osteoporosis medication followed coherent age- and sex-related gradients in a European ageing population. This complements the HRS and CHARLS clinical-outcome layers.

## Official Source

- release portal: <https://releases.sharedataportal.eu/>
- SHARE project website: <https://share-eric.eu/>

## Scope Used in This Project

Data product used:

- `Gateway Harmonized SHARE`
- release `9.0.0`
- R-format archive: `GH_SHARE_g_rel9-0-0_ALL_datasets_R.zip`

Supporting documentation/data package checked:

- `easySHARE_rel9-0-0_R.zip`

Waves used:

- `1, 2, 4, 5, 6, 7, 8, 9`

Approximate calendar coverage:

- `2004-2022`

Main analytic restriction:

- age `>=50 years`
- non-missing sex

## Downloaded Files Used Locally

Local source archives:

- `GH_SHARE_g_rel9-0-0_ALL_datasets_R.zip`
- `easySHARE_rel9-0-0_R.zip`

File format:

- compressed `.zip` archives
- extracted `.rdata` / `.rda` files
- extracted PDF release guides and codebooks

Local integrity checks:

- `GH_SHARE_g_rel9-0-0_ALL_datasets_R.zip`
  - SHA256: `437CA1D3B526F16B0A006F7BF3B31F367E4D6A9280720134373FF3725176B9B7`
- `easySHARE_rel9-0-0_R.zip`
  - SHA256: `965C2347ED2F87DC339E861AEA609DC6216FADFB33A554E139929F834EA7B5FE`

Download/check date:

- `2026-05-01`

## Data Objects

Primary object:

- `GH_SHARE_g.rdata`
- loaded object: `H_SHARE_g`
- raw dimensions checked locally: `158,764 rows x 8,096 columns`

Supporting object:

- `easySHARE_rel9_0_0.rda`
- loaded object: `easySHARE_rel9_0_0`
- raw dimensions checked locally: `488,400 rows x 108 columns`

## Variables Used

Main outcomes:

- `rWfall_s`: bothered by a fall in the last 6 months
- `rWhipe`: ever had hip fracture
- `rWhip`: hip fracture since previous wave
- `rWosteoe`: ever had osteoporosis, limited wave coverage
- `rWrxosteo`: osteoporosis medication

Main covariates:

- `rWagey`: age in years
- `ragender`: sex
- `country`: country
- `wave`: survey wave
- `rWwtresp`: respondent-level response weight

Important interpretation note:

- `rWfall_s` is a fall-related limitation/problem item, not a direct count of all falls.
- `rWosteoe` has limited wave coverage; osteoporosis medication was therefore used as the more complete osteoporosis-related context variable.

## Preprocessing

The SHARE workflow:

1. loaded `H_SHARE_g`
2. converted respondent-level wide data into a respondent-wave long table
3. retained waves `1, 2, 4, 5, 6, 7, 8, 9`
4. restricted the analytic sample to age `>=50`
5. recoded binary outcomes to `0/1`
6. treated negative or special missing values as missing
7. generated descriptive prevalence tables and adjusted logistic models

Local processed output:

- `share_rel9_outcomes_long_age50plus.rds`

This processed participant-level file is not included in the public repository.

## Analysis Strategy

Descriptive analysis:

- weighted prevalence by age group and sex
- age groups: `50-59`, `60-69`, `70-79`, `>=80`
- response weight: `rWwtresp`

Adjusted model:

```text
outcome ~ age per 10 years + sex + wave + country
```

Models were run as:

- unweighted logistic regression
- response-weighted sensitivity analysis using `rWwtresp`

The response-weighted model should not be interpreted as a full complex-survey design analysis because complete PSU/strata design handling was not implemented for this SHARE layer.

## Main Results

Analytic size:

- `452,120` respondent-wave records
- `156,237` participants aged `>=50`

Weighted prevalence among participants aged `>=80`:

- women:
  - fall-related limitation: `20.3%`
  - ever hip fracture: `13.4%`
  - osteoporosis medication: `12.8%`
- men:
  - fall-related limitation: `12.6%`
  - ever hip fracture: `7.1%`
  - osteoporosis medication: `2.4%`

Adjusted unweighted associations:

- age per 10 years:
  - fall-related limitation: `OR 1.901`
  - ever hip fracture: `OR 2.082`
  - hip fracture since previous wave: `OR 2.170`
  - osteoporosis medication: `OR 1.466`
- female vs male:
  - fall-related limitation: `OR 1.742`
  - ever hip fracture: `OR 1.307`
  - hip fracture since previous wave: `OR 1.691`
  - osteoporosis medication: `OR 6.722`

Response-weighted sensitivity results were directionally consistent.

## Interpretation

SHARE strengthens the European clinical-outcome context for the manuscript. Together with HRS and CHARLS, it supports the idea that fracture-related outcomes cluster in expected high-risk strata, especially older age and female sex.

SHARE should **not** be interpreted as:

- direct validation of `BIA-based MBR`
- direct validation of `DXA-derived MBR`
- validation of `MBR >= 16`
- proof that MBR is a stand-alone diagnostic tool

The correct role is:

- European older-adult clinical outcome context

## Local Script Reference

- `code/SHARE/analyze_share_rel9.R`

