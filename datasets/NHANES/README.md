# NHANES

## Role in the Project

NHANES provided the most important external support for the manuscript. It was used for two purposes:

1. `BIA-DXA bridge`
2. `DXA-derived MBR` association with fracture-related risk markers

## Data Components Used

### NHANES 1999-2004

Used for the bridge analysis between BIA-derived and DXA-derived body composition variables.

Main variables:

- BIA fat-free mass
- BIA fat mass
- DXA total lean mass
- DXA total fat mass

### NHANES 2013-2014

Used for external risk-consistency analyses based on `DXA-derived MBR`.

Main variables:

- whole-body DXA lean mass
- whole-body DXA bone mineral content
- femur/spine DXA outcomes
- hip FRAX
- major osteoporotic FRAX
- previous fracture
- self-reported osteoporosis
- direct fracture indicator
- age
- sex
- body weight

## Preprocessing

### Bridge dataset

Participants with both BIA and whole-body DXA measurements were retained. The bridge workflow focused on aligning BIA soft-tissue variables with DXA body-composition variables and summarizing cross-platform correspondence across survey cycles.

### 2013-2014 outcome dataset

`DXA-derived MBR` was defined as:

`whole-body lean mass / whole-body bone mineral content`

Participants were grouped into the following analytic frames:

- overall `40-59`
- `50-59`
- `female 50-59`

The original Chinese `MBR = 16` threshold was examined descriptively only. It was not treated as a formal external cutoff because very few NHANES participants aged `50-59` had values below 16.

## Analysis Strategy

### 1. Bridge analysis

- scatter plots
- sex-specific linear fits
- cycle-specific correlation summaries

### 2. Continuous outcomes

Linear regression models were fitted for:

- hip FRAX
- major osteoporotic FRAX

Main covariates:

- age
- sex
- body weight

### 3. Binary outcomes

Logistic regression models were fitted for:

- previous fracture
- self-reported osteoporosis
- direct fracture indicator

Main covariates:

- age
- sex
- body weight

### 4. Discrimination analysis

ROC/AUC analyses were used to compare:

- `DXA-derived MBR`
- `OSTA`

## Main Results

### Bridge

- BIA fat-free mass vs DXA lean mass: `r = 0.969`
- BIA fat mass vs DXA fat mass: `r = 0.942`

These findings supported a stable measurement bridge between BIA-based and DXA-based body-composition markers.

### Risk consistency

In NHANES 2013-2014, higher `DXA-derived MBR` was associated with higher fracture-related burden.

Examples:

- In `50-59`, hip FRAX adjusted beta: `0.639`
- In `50-59`, major osteoporotic FRAX adjusted beta: `1.410`
- In `female 50-59`, hip FRAX adjusted beta: `0.922`
- In `female 50-59`, major osteoporotic FRAX adjusted beta: `1.817`
- In overall `40-59`, previous fracture: `OR 1.44`
- In `female 50-59`, self-reported osteoporosis: `OR 2.09`

### Interpretation

NHANES did **not** support direct transferability of the original Chinese `MBR = 16` threshold. Instead, it supported:

- cross-platform bridge validity
- structural relevance of `DXA-derived MBR`
- risk consistency with fracture-related outcomes

## Local Script References

- `code/NHANES/prepare_nhanes_inputs.py`
- `code/NHANES/check_nhanes_consistency.py`
- `code/NHANES/run_nhanes_external_analysis.R`
