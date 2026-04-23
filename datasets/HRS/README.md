# HRS

## Role in the Project

HRS was not used to directly validate the original MBR marker. Instead, it was used to provide an older-adult clinical outcome context in a large U.S. aging population.

This part of the project asked a different question:

Do older adults show clear age- and sex-related gradients in fall, hip fracture, and osteoporosis outcomes that are compatible with the broader clinical relevance of a muscle-bone imbalance phenotype?

## Data Components Used

### RAND HRS Fat Files

Waves included:

- 2012
- 2014
- 2016
- 2018
- 2020
- 2022

Main variables extracted across waves:

- age
- sex
- fall in past 2 years
- number of falls
- fall-related injury
- broken hip
- self-reported osteoporosis
- bone density test
- height
- weight

## Preprocessing

The fat files were harmonized across waves by mapping wave-specific prefixes to common variable names. Binary variables were recoded using a simple working convention:

- `1 = yes`
- `5 = no`
- all other special codes = missing

The main analytic sample included adults aged `50 years or older`.

## Analysis Strategy

The HRS workflow was designed as a repeated cross-sectional analysis, not as a formal causal longitudinal model.

Three summary layers were produced:

1. prevalence by survey wave and sex
2. prevalence by age group and sex in 2022
3. pooled adjusted OR for age and sex

Main outcomes:

- fall in past 2 years
- fall-related injury
- broken hip
- osteoporosis

Main covariates:

- age
- sex
- survey year

## Main Results

Across pooled 2012-2022 data in adults aged `>=50`:

- fall in past 2 years
  - per 10-year age increase: `OR 1.47`
  - female vs male: `OR 1.14`
- fall-related injury
  - per 10-year age increase: `OR 1.24`
  - female vs male: `OR 1.70`
- broken hip
  - per 10-year age increase: `OR 2.28`
  - female vs male: `OR 1.64`
- osteoporosis
  - per 10-year age increase: `OR 1.42`
  - female vs male: `OR 6.22`

These results showed a clear older-adult clinical burden gradient, especially in women and in the oldest age groups.

## Interpretation

HRS should be interpreted as:

- an older-adult clinical outcome context
- a background support layer for the manuscript

HRS should **not** be interpreted as:

- direct validation of `BIA-based MBR`
- direct validation of `DXA-derived MBR`
- a formal longitudinal causal analysis of the marker

## Local Script References

- `code/HRS/prepare_hrs_fat_2012_2022.R`
- `code/HRS/run_hrs_fat_event_analysis.R`
