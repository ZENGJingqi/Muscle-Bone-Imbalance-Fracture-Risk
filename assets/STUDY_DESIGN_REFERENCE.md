# Current study design reference (2026-10-05)

The current PNG is an AI-generated raster layout reference, accepted provisionally for its design direction. It is not an editable or final submission figure, and no new statistical results are implied. Previous previews remain unchanged. The survey populations are analyzed separately, not linked or pooled.

| Analytic sample | Design count | Role |
| --- | --- | --- |
| Chinese BIA | 152,449 reported records | Discovery and age/sex distribution; not independently reconstructed unique persons |
| NHANES paired BIA/DXA | 11,731 paired participants | Selected soft-tissue component correspondence; five DXA imputations, not five times as many persons |
| NHANES bone health | 1,592 eligible participants | Cross-sectional FRAX/fracture associations and within-dataset component comparisons |
| KNHANES bone health | 9,113 eligible participants | DXA bone status and within-dataset component comparisons |
| HRS clinical context | 28,462 participants; 105,869 person-waves | Age/sex clinical-event context, no MBR |
| CHARLS clinical context | 22,563 participants; 79,051 person-waves | Age/sex clinical-event context, no MBR |
| SHARE clinical context | 156,237 participants; 452,120 person-waves | Age/sex clinical-event context, no MBR |

There is no combined total sample size. The two NHANES samples are distinct analytic populations from different cycles. Eligible counts are not fixed model denominators: complete cases range from 1,505 to 1,581 in NHANES and 7,937 to 8,420 in KNHANES. Context counts describe eligible age >=50 pools before outcome-specific complete-case restrictions; respondent-wave observations are not independent persons.

DXA MBR uses lean soft tissue excluding BMC divided by BMC; lean soft tissue is not isolated skeletal muscle. Component correspondence does not establish BIA/DXA MBR interchangeability. FRAX probabilities are calculated quantities, not observed prospective fracture events. None of HRS, CHARLS or SHARE externally validates MBR.

The [sample-count table](../public_data/study_design_sample_counts.csv) also lists outcome-specific denominators. The [audit script](../code/Publication/audit_study_design_counts.R) reproduces the external contextual counts from authorized local bundles and checks them against the published aggregate tables. The Chinese count remains a reported input rather than an independent reconstruction.

Generated with OpenAI image generation from the project's preceding design reference; human review checked the displayed counts and roles. The illustration uses generic conceptual and measurement symbols, not actual scans or specific devices. Editable reconstruction and journal-specific review remain necessary before submission.
