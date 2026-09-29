# Aggregate data dictionary

All CSV files in this directory are aggregate, non-identifying outputs. `manifest.json` specifies exact headers, row counts and SHA-256 hashes.

Source data remain with their providers. Follow the [HRS conditions](https://hrs.isr.umich.edu/data-products/access-to-public-data/conditions-of-use), [CHARLS agreement](https://charls.charlsdata.com/users/sign_up/agreement/en.html), and [SHARE conditions and citation requirements](https://www.share-eric.eu/data/data-access/conditions-of-use) when using or citing these analyses. Public access to these summary tables does not grant access to the underlying survey records or a software/data reuse license.

| File | Unit and meaning |
| --- | --- |
| adjusted_associations.csv | One dataset-outcome-estimation method; OR or FRAX percentage-point beta per outcome-specific SD MBR, confidence interval, P value and participant/event counts |
| sample_flow.csv | One dataset-outcome; source records, eligible positive-component sample, outcome/covariate complete cases and survey-domain count |
| component_cv_performance.csv | One dataset-outcome-model; out-of-fold AUC or R-squared, identical ten folds within outcome, seed 20260804 |
| bridge_pooled.csv | One component pair and weighting method; Rubin-pooled correlation and 95% CI across five DXA imputations |
| bridge_per_imputation.csv | One component pair, method and imputation; unique-person count, correlation, Fisher z, its variance and design degrees of freedom |
| spline_tests.csv | One dataset-outcome; four-df overall and three-df nonlinear Wald tests, internal/boundary knots in sample z-score units |
| spline_curves.csv | Aggregate fitted OR and pointwise 95% CI on an evaluation grid, not participant predictions |
| threshold_performance.csv | One outcome-score-method-threshold strategy; apparent AUC, threshold, sensitivity, specificity, PPV and NPV; all metrics consistently weighted or unweighted |
| NHANES_description.csv | Sex-specific eligible body-composition summary, ages 40-59 |
| KNHANES_description.csv | Sex-specific eligible body-composition summary, ages >=50; lean excludes BMC |
| weight_coverage_audit.csv | Year-level count showing legacy WT_EX coverage and harmonized WT_ITVEX coverage |
| context_clustered_associations.csv | Age/sex ORs for HRS, CHARLS and SHARE, with respondent-clustered confidence intervals; no MBR models |
| context_weight_coverage.csv | HRS/CHARLS year-level eligible records, unique respondents and positive-weight counts after identifier harmonization |

For DXA/bridge analyses, `n`, `events` and flow counts are unweighted participant counts, never sums of imputation rows. In context analyses, `n` and `events` count respondent-wave observations; `participants` counts unique respondents. `weighted` is Boolean. Lean and BMC are in grams; ratios are dimensionless. `conf_low/conf_high` refer to the corresponding metric, not a common scale across rows. `variance_z` is Fisher-z variance. Threshold metrics lack independent validation and interval estimates. P values are exploratory and not adjusted for multiplicity. NA is missing/not applicable, not zero.
