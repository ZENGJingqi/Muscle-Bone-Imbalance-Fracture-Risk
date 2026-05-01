suppressPackageStartupMessages({
  library(broom)
  library(dplyr)
  library(readr)
  library(survey)
})

options(survey.lonely.psu = "adjust")

root_dir <- normalizePath(".", winslash = "/", mustWork = TRUE)
table_dir <- file.path(root_dir, "outputs", "sensitivity", "tables")
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)

standardize <- function(x) as.numeric(scale(x))

to_yes_no <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  dplyr::case_when(
    x == 1 ~ 1,
    x == 2 ~ 0,
    TRUE ~ NA_real_
  )
}

fit_svy_model <- function(data, outcome_name, family, dataset, subgroup, outcome_label) {
  model_data <- data %>%
    transmute(
      outcome = .data[[outcome_name]],
      mbr_z = standardize(dxa_mbr),
      age_z = standardize(age),
      sex_male = sex_male,
      weight_z = standardize(weight),
      survey_weight = survey_weight,
      psu = psu,
      strata = strata
    ) %>%
    filter(
      !is.na(outcome), !is.na(mbr_z), !is.na(age_z), !is.na(sex_male),
      !is.na(weight_z), !is.na(survey_weight), !is.na(psu), !is.na(strata),
      survey_weight > 0
    )

  if (nrow(model_data) < 50 || length(unique(model_data$outcome)) < 2 && family != "gaussian") {
    return(tibble())
  }

  design <- survey::svydesign(
    ids = ~psu,
    strata = ~strata,
    weights = ~survey_weight,
    nest = TRUE,
    data = model_data
  )

  model_family <- if (family == "gaussian") gaussian() else quasibinomial()
  fit <- survey::svyglm(outcome ~ mbr_z + age_z + sex_male + weight_z, design = design, family = model_family)
  co <- summary(fit)$coefficients["mbr_z", ]
  estimate <- unname(co[["Estimate"]])
  se <- unname(co[["Std. Error"]])
  p_value <- unname(co[ncol(summary(fit)$coefficients)])

  if (family == "gaussian") {
    effect <- estimate
    ci_low <- estimate - 1.96 * se
    ci_high <- estimate + 1.96 * se
    effect_type <- "beta_per_1SD"
  } else {
    effect <- exp(estimate)
    ci_low <- exp(estimate - 1.96 * se)
    ci_high <- exp(estimate + 1.96 * se)
    effect_type <- "OR_per_1SD"
  }

  tibble(
    dataset = dataset,
    subgroup = subgroup,
    outcome = outcome_label,
    effect_type = effect_type,
    estimate = effect,
    conf_low = ci_low,
    conf_high = ci_high,
    p_value = p_value,
    n = nrow(model_data),
    events = if (family == "gaussian") NA_real_ else sum(model_data$outcome == 1)
  )
}

prepare_nhanes_outcome <- function() {
  path <- file.path(root_dir, "data", "processed", "NHANES", "NHANES_2013_2014_outcome_bundle.csv.gz")
  if (!file.exists(path)) stop("Missing NHANES outcome bundle: ", path)

  readr::read_csv(path, show_col_types = FALSE) %>%
    transmute(
      age = DEMO_H__RIDAGEYR,
      sex_male = ifelse(DEMO_H__RIAGENDR == 1, 1, 0),
      sex = ifelse(DEMO_H__RIAGENDR == 1, "Male", "Female"),
      weight = BMX_H__BMXWT,
      dxa_lean = DXX_H__DXDTOLE,
      dxa_bmc = DXX_H__DXDTOBMC,
      dxa_mbr = dxa_lean / dxa_bmc,
      hip_frax = ifelse(DXXFRX_H__DXXPRVFX == 1, DXXFRX_H__DXXFRAX1, ifelse(DXXFRX_H__DXXPRVFX == 2, DXXFRX_H__DXXFRAX3, NA_real_)),
      major_frax = ifelse(DXXFRX_H__DXXPRVFX == 1, DXXFRX_H__DXXFRAX2, ifelse(DXXFRX_H__DXXPRVFX == 2, DXXFRX_H__DXXFRAX4, NA_real_)),
      prev_fracture = to_yes_no(DXXFRX_H__DXXPRVFX),
      self_report_osteoporosis = to_yes_no(OSQ_H__OSQ060),
      survey_weight = DEMO_H__WTMEC2YR,
      psu = DEMO_H__SDMVPSU,
      strata = DEMO_H__SDMVSTRA
    ) %>%
    filter(age >= 40, age <= 59, is.finite(dxa_mbr))
}

prepare_knhanes <- function() {
  path <- file.path(root_dir, "data", "processed", "KNHANES", "KNHANES_2008_2011_ALL_DXA_merged.rds")
  if (!file.exists(path)) stop("Missing KNHANES processed file: ", path)

  dat <- readRDS(path)
  if (!"wt_ex" %in% names(dat)) dat$wt_ex <- 1
  if (!"psu" %in% names(dat)) dat$psu <- seq_len(nrow(dat))
  if (!"kstrata" %in% names(dat)) dat$kstrata <- 1

  dat %>%
    mutate(
      age = suppressWarnings(as.numeric(age)),
      sex = suppressWarnings(as.numeric(sex)),
      he_wt = suppressWarnings(as.numeric(he_wt)),
      dw_wbt_ln = suppressWarnings(as.numeric(dw_wbt_ln)),
      dw_wbt_bmc = suppressWarnings(as.numeric(dw_wbt_bmc)),
      dx_ost = suppressWarnings(as.numeric(dx_ost)),
      dx_ost_fn = suppressWarnings(as.numeric(dx_ost_fn)),
      dx_ost_ls = suppressWarnings(as.numeric(dx_ost_ls)),
      dxa_mbr = dw_wbt_ln / dw_wbt_bmc,
      osteoporosis_any = ifelse(dx_ost == 3, 1, ifelse(dx_ost %in% c(1, 2), 0, NA_real_)),
      osteoporosis_fn = ifelse(dx_ost_fn == 3, 1, ifelse(dx_ost_fn %in% c(1, 2), 0, NA_real_)),
      osteoporosis_ls = ifelse(dx_ost_ls == 3, 1, ifelse(dx_ost_ls %in% c(1, 2), 0, NA_real_)),
      sex_male = ifelse(sex == 1, 1, 0),
      weight = he_wt,
      survey_weight = suppressWarnings(as.numeric(wt_ex)),
      psu = psu,
      strata = kstrata
    ) %>%
    filter(age >= 50, is.finite(dxa_mbr), !is.na(weight))
}

nhanes <- prepare_nhanes_outcome()
knhanes <- prepare_knhanes()

nhanes_models <- bind_rows(
  fit_svy_model(nhanes, "hip_frax", "gaussian", "NHANES 2013-2014", "Age 40-59", "Hip FRAX"),
  fit_svy_model(nhanes, "major_frax", "gaussian", "NHANES 2013-2014", "Age 40-59", "Major osteoporotic FRAX"),
  fit_svy_model(nhanes, "prev_fracture", "binomial", "NHANES 2013-2014", "Age 40-59", "Previous fracture"),
  fit_svy_model(nhanes, "self_report_osteoporosis", "binomial", "NHANES 2013-2014", "Age 40-59", "Self-reported osteoporosis"),
  fit_svy_model(filter(nhanes, age >= 50), "hip_frax", "gaussian", "NHANES 2013-2014", "Age 50-59", "Hip FRAX"),
  fit_svy_model(filter(nhanes, age >= 50), "major_frax", "gaussian", "NHANES 2013-2014", "Age 50-59", "Major osteoporotic FRAX"),
  fit_svy_model(filter(nhanes, age >= 50), "prev_fracture", "binomial", "NHANES 2013-2014", "Age 50-59", "Previous fracture"),
  fit_svy_model(filter(nhanes, age >= 50), "self_report_osteoporosis", "binomial", "NHANES 2013-2014", "Age 50-59", "Self-reported osteoporosis")
)

knhanes_models <- bind_rows(
  fit_svy_model(knhanes, "osteoporosis_any", "binomial", "KNHANES 2008-2011", "Age >=50", "Overall osteoporosis"),
  fit_svy_model(knhanes, "osteoporosis_fn", "binomial", "KNHANES 2008-2011", "Age >=50", "Femoral neck osteoporosis"),
  fit_svy_model(knhanes, "osteoporosis_ls", "binomial", "KNHANES 2008-2011", "Age >=50", "Lumbar spine osteoporosis"),
  fit_svy_model(filter(knhanes, sex_male == 0), "osteoporosis_any", "binomial", "KNHANES 2008-2011", "Female age >=50", "Overall osteoporosis"),
  fit_svy_model(filter(knhanes, sex_male == 1), "osteoporosis_any", "binomial", "KNHANES 2008-2011", "Male age >=50", "Overall osteoporosis")
)

survey_results <- bind_rows(nhanes_models, knhanes_models)
readr::write_csv(survey_results, file.path(table_dir, "Survey_Weighted_Sensitivity_Models.csv"))

cat("Saved survey-weighted sensitivity tables to:\n", table_dir, "\n")
