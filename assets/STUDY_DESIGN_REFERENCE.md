# Current study design

The [current PDF](study_design_current.pdf) was exported from the retained native PowerPoint diagram used in the current manuscript. OpenAI Codex assisted with layout; analytical roles and counts came from documented study sources. Generic icons do not depict actual devices, scans or participants. Earlier AI-generated PNGs remain historical layout previews and are not the current figure. The survey populations are analyzed separately, not linked or pooled.

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

The PDF contains no statistical results, diagnostic cutoffs or pooled total sample. Native construction does not itself establish journal-policy compliance; the manuscript retains the AI-assistance disclosure for author review.
