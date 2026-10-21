# Muscle-to-bone proportionality across population datasets

Analysis code and non-identifying aggregate results for **Muscle-to-bone mass ratio as a candidate proportional phenotype across population datasets**.

## Current development snapshot

The 21 October 2026 update adds the reviewed internal-validation extension: 100 additional shared ten-fold allocations and 1000 paired participant-level bootstrap resamples with model refitting. The repository now contains **18 aggregate CSV tables** and four canonical R analysis entry points. The original 14 aggregate tables and original model point estimates are unchanged.

Cite the exact Git commit used. The version label `0.3.1-dev` is descriptive metadata, not a Git tag, formal Release or archival DOI.

- [Reproduction instructions](REPRODUCIBILITY.md)
- [Aggregate data dictionary and checksums](public_data/README.md)
- [Citation and release status](RELEASE.md)
- [Machine-readable software citation](CITATION.cff)
- [Current study design PDF](assets/study_design_current.pdf) and [dataset-role definitions](assets/STUDY_DESIGN_REFERENCE.md)

## Scientific contribution

Complementary datasets characterize a candidate, platform-dependent proportional phenotype and its bone-health associations. Same-sample comparisons evaluate the information retained by the ratio relative to its numerator, denominator and joint component representations. This is not development or external validation of a clinical fracture prediction rule.

| Data source | Analytical role |
| --- | --- |
| Chinese BIA records | Age- and sex-specific descriptive proportionality; archived outputs, without clinical bone outcomes |
| NHANES 1999-2004 | Paired BIA/DXA correspondence for selected soft-tissue components, accounting for five DXA imputations |
| NHANES 2013-2014 | Cross-sectional associations with BMD-informed FRAX probabilities and reported bone-health indicators; within-sample component comparisons |
| KNHANES 2008-2011 | Cross-sectional associations with DXA-defined bone status; within-sample component comparisons |
| HRS 2012-2022 | Separate age- and sex-related clinical context, without MBR |
| CHARLS 2011-2020 | Separate clinical context and a recent-wave comparison, without MBR |
| SHARE release 9 | Separate clinical context, without MBR |

Participants are not linked or pooled across sources. Different roles and endpoints are complementary evidence, not interchangeable replications of one outcome. Record counts, people and person-waves must not be added into a pooled sample size.

DXA MBR equals lean soft tissue excluding BMC divided by BMC. BIA muscle mass, fat-free mass and DXA lean soft tissue are not identical compartments. The paired NHANES comparison does not calibrate the BIA bone estimate, the complete BIA ratio or Chinese device algorithms. The Chinese value of 16 is an empirical distribution feature, not a diagnostic cutoff.

## Main numerical interpretation

For KNHANES overall osteoporosis, covariates-only and covariates-plus-MBR cross-validated AUCs were 0.853 and 0.912; BMC and raw joint-component models both rounded to 0.918. The BMC-minus-MBR difference was 0.006 (approximate 95% basic interval 0.003 to 0.009), with positive differences in all 100 additional allocations.

For NHANES hip FRAX, MBR and flexible-component R-squared values were 0.162 and 0.194. The flexible-minus-MBR difference was 0.032 (approximate 95% basic interval -0.021 to 0.118), despite positive differences in all additional allocations. Fold stability is not sampling certainty. Neither MBR nor BMC was uniformly favored across endpoints; no consistent ratio advantage, equivalence or clinical benefit is claimed.

These are complete models containing common covariates, not performance attributable to MBR alone. FRAX probabilities incorporate BMD and are not observed incident fractures. No prospective fragility-fracture prediction, clinical calibration, decision benefit or increment over an established BMD/FRAX clinical model was tested.

## Canonical analysis entry points

| File | Purpose |
| --- | --- |
| `code/Publication/reanalyse.R` | Original bridge/DXA association, component, spline and operating-characteristic analyses |
| `code/Publication/reanalyse_context.R` | Separate respondent-clustered HRS/CHARLS/SHARE contextual analyses |
| `code/Publication/audit_study_design_counts.R` | Audit of sample-role and outcome-specific denominators |
| `code/Publication/extend_model_validation.R` | Repeated ten-fold allocations and paired refitting-bootstrap uncertainty |

The entry points require authorized, already-cleaned inputs. Source acquisition and older preparation scripts remain for provenance; this update does not claim a fresh execution of the full raw-to-clean processing chain or a participant-level reconstruction of the Chinese discovery analysis. Older scripts and images are historical references, not the current manuscript's figures or numerical specification.

```text
python code/check_public_release.py
```

This standard-library check verifies aggregate schemas, counts and hashes, selected numerical relationships, validation-summary consistency and the public checksum manifest. It does not refit models.

## Data access and privacy

No raw or cleaned participant records, identifiers, individual outcomes/predictions, fold assignments, resampling frequencies or checkpoints are distributed. Bootstrap iteration performance metrics are model-level aggregates, not participant observations. Do not upload the `private/` directory generated by the validation program.

Obtain underlying data through the source providers and comply with their conditions:
[Chinese discovery data](https://www.ncmi.cn/phda/dataDetails.do?id=CSTR:A0006.11.A0005.201905.000346),
[NHANES](https://wwwn.cdc.gov/nchs/nhanes/),
[KNHANES](https://knhanes.kdca.go.kr/knhanes/eng/index.do),
[HRS](https://hrsdata.isr.umich.edu/data-products),
[CHARLS](https://charls.charlsdata.com/), and
[SHARE](https://releases.sharedataportal.eu/).

Packaging does not grant a software license or transfer source-data redistribution rights. The known maintainer in CITATION.cff is not a confirmed manuscript author list. This repository contains no manuscript Word files, submission correspondence or author/ethics documents.
