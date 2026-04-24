# KNHANES

## Role in the Project

KNHANES was used as an East Asian external DXA validation dataset. Its value was not in replicating the original Chinese BIA-based marker directly, but in testing whether a conceptually corresponding DXA-derived marker showed consistent associations with osteoporosis-related outcomes.

## Official Source

- official portal: <https://knhanes.kdca.go.kr/knhanes/eng/index.do>

## Scope Used in This Project

- `2008-2011`

## Data Components Used

### KNHANES 2008-2011

Files used:

- ALL
- DXA

Main variables used:

- age
- sex
- body weight
- whole-body lean mass
- whole-body bone mineral content
- whole-body bone mineral density
- whole-body fat mass
- osteoporosis-related DXA outcome variables

## Downloaded Files Used Locally

Local raw files used:

- `raw/all/HN08_ALL(SAS).zip`
- `raw/all/HN09_ALL(SAS).zip`
- `raw/all/HN10_ALL(SAS).zip`
- `raw/all/HN11_ALL(SAS).zip`
- `raw/all/hn08_all.sas7bdat`
- `raw/all/hn09_all.sas7bdat`
- `raw/all/hn10_all.sas7bdat`
- `raw/all/hn11_all.sas7bdat`
- `raw/dxa/hn08_dxa.sas7bdat`
- `raw/dxa/hn09_dxa.sas7bdat`
- `raw/dxa/hn10_dxa.sas7bdat`
- `raw/dxa/hn11_dxa.sas7bdat`

Format:

- downloaded SAS archives for ALL tables
- extracted `sas7bdat` files for ALL and DXA tables
- local processed outputs written as `.rds` and `.csv.gz`

Representative local file date:

- checked in local workspace on `2026-04-20`

## Local Version Notes

The KNHANES workflow in this repository corresponds to survey years `2008-2011`.

The locally generated merged files were:

- `KNHANES_2008_2011_ALL_DXA_merged.rds`
- `KNHANES_2008_2011_ALL_DXA_merged.csv.gz`

## Important Clarification

The downloaded KNHANES dataset was used as a **DXA dataset**, not as a BIA dataset for this project.

Accordingly, the external marker was defined as:

`DXA-derived MBR = whole-body lean mass / whole-body bone mineral content`

## Preprocessing

ALL and DXA files were merged by participant identifier. The main analytic sample included adults aged `50 years or older` with the key DXA variables available.

Sex-stratified quartiles of `DXA-derived MBR` were created to describe structural differences across the marker distribution.

Derived outcomes included:

- overall osteoporosis
- low bone mass
- total femur osteoporosis
- femoral neck osteoporosis
- lumbar spine osteoporosis

## Analysis Strategy

The KNHANES analysis addressed four questions:

1. How is `DXA-derived MBR` distributed in adults aged `>=50`?
2. How do body-composition features change across quartiles of the marker?
3. Does osteoporosis prevalence increase across marker quartiles?
4. Is the marker associated with osteoporosis-related outcomes after adjustment?

Main covariates:

- age
- body weight
- survey year
- sex in the overall model

Current pooled models were run as unweighted external consistency analyses.

## Main Results

Analytic sample:

- total `>=50`: `n = 9100`
- female: `n = 5210`
- male: `n = 3890`

Median `DXA-derived MBR`:

- female: `21.20`
- male: `20.77`

Adjusted OR per 1 SD increase in `DXA-derived MBR`:

- overall osteoporosis: `4.09`
- low bone mass: `6.52`
- total femur osteoporosis: `2.71`
- femoral neck osteoporosis: `2.67`
- lumbar spine osteoporosis: `3.72`

## Interpretation

KNHANES supported the same overall direction observed in NHANES:

- higher `DXA-derived MBR` tracked with lower bone status
- the marker behaved as a muscle-bone imbalance phenotype rather than a simple body-size measure

However, KNHANES should be interpreted as **East Asian DXA external validation**, not as a direct external replication of the original Chinese BIA-based threshold.

## Local Script References

- `code/KNHANES/prepare_knhanes_2008_2011.R`
- `code/KNHANES/run_knhanes_external_analysis.R`
