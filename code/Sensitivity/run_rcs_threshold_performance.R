suppressPackageStartupMessages({
  library(dplyr)
  library(pROC)
  library(readr)
  library(rms)
  library(tibble)
})

root_dir <- normalizePath(".", winslash = "/", mustWork = TRUE)
table_dir <- file.path(root_dir, "outputs", "sensitivity", "tables")
figure_dir <- file.path(root_dir, "outputs", "sensitivity", "figures")
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

standardize <- function(x) as.numeric(scale(x))

to_yes_no <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  dplyr::case_when(
    x == 1 ~ 1,
    x == 2 ~ 0,
    TRUE ~ NA_real_
  )
}

prepare_nhanes <- function() {
  path <- file.path(root_dir, "data", "processed", "NHANES", "NHANES_2013_2014_outcome_bundle.csv.gz")
  if (!file.exists(path)) stop("Missing NHANES outcome bundle: ", path)

  readr::read_csv(path, show_col_types = FALSE) %>%
    transmute(
      dataset = "NHANES 2013-2014",
      age = DEMO_H__RIDAGEYR,
      sex_male = ifelse(DEMO_H__RIAGENDR == 1, 1, 0),
      weight = BMX_H__BMXWT,
      dxa_lean = DXX_H__DXDTOLE,
      dxa_bmc = DXX_H__DXDTOBMC,
      dxa_mbr = dxa_lean / dxa_bmc,
      prev_fracture = to_yes_no(DXXFRX_H__DXXPRVFX),
      self_report_osteoporosis = to_yes_no(OSQ_H__OSQ060)
    ) %>%
    filter(age >= 40, age <= 59, is.finite(dxa_mbr), !is.na(weight))
}

prepare_knhanes <- function() {
  path <- file.path(root_dir, "data", "processed", "KNHANES", "KNHANES_2008_2011_ALL_DXA_merged.rds")
  if (!file.exists(path)) stop("Missing KNHANES processed file: ", path)

  readRDS(path) %>%
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
      dataset = "KNHANES 2008-2011"
    ) %>%
    filter(age >= 50, is.finite(dxa_mbr), !is.na(weight))
}

fit_rcs_logistic <- function(data, outcome_name, dataset, subgroup, outcome_label) {
  model_data <- data %>%
    transmute(
      outcome = .data[[outcome_name]],
      mbr_z = standardize(dxa_mbr),
      age_z = standardize(age),
      sex_male = sex_male,
      weight_z = standardize(weight)
    ) %>%
    filter(!is.na(outcome), !is.na(mbr_z), !is.na(age_z), !is.na(sex_male), !is.na(weight_z))

  if (nrow(model_data) < 100 || length(unique(model_data$outcome)) < 2) {
    return(tibble())
  }

  dd <- rms::datadist(model_data)
  assign("dd", dd, envir = .GlobalEnv)
  old_options <- options(datadist = "dd")
  on.exit(options(old_options), add = TRUE)
  on.exit(rm("dd", envir = .GlobalEnv), add = TRUE)

  linear_fit <- rms::lrm(outcome ~ mbr_z + age_z + sex_male + weight_z, data = model_data, x = TRUE, y = TRUE)
  rcs_fit <- rms::lrm(outcome ~ rcs(mbr_z, 4) + age_z + sex_male + weight_z, data = model_data, x = TRUE, y = TRUE)
  lr_chisq <- unname(rcs_fit$stats[["Model L.R."]] - linear_fit$stats[["Model L.R."]])
  lr_df <- unname(rcs_fit$stats[["d.f."]] - linear_fit$stats[["d.f."]])
  lr_p <- stats::pchisq(lr_chisq, df = lr_df, lower.tail = FALSE)

  tibble(
    dataset = dataset,
    subgroup = subgroup,
    outcome = outcome_label,
    n = nrow(model_data),
    events = sum(model_data$outcome == 1),
    linear_aic = AIC(linear_fit),
    rcs_aic = AIC(rcs_fit),
    lr_df = lr_df,
    lr_chisq = lr_chisq,
    lr_p_value = lr_p
  )
}

threshold_metrics <- function(data, outcome_name, dataset, subgroup, outcome_label, threshold, threshold_label) {
  model_data <- data %>%
    transmute(
      outcome = .data[[outcome_name]],
      dxa_mbr = dxa_mbr
    ) %>%
    filter(!is.na(outcome), is.finite(dxa_mbr))

  if (nrow(model_data) < 50 || length(unique(model_data$outcome)) < 2) {
    return(tibble())
  }

  pred <- ifelse(model_data$dxa_mbr >= threshold, 1, 0)
  tp <- sum(pred == 1 & model_data$outcome == 1)
  tn <- sum(pred == 0 & model_data$outcome == 0)
  fp <- sum(pred == 1 & model_data$outcome == 0)
  fn <- sum(pred == 0 & model_data$outcome == 1)

  roc_obj <- pROC::roc(model_data$outcome, model_data$dxa_mbr, quiet = TRUE, direction = "<")

  tibble(
    dataset = dataset,
    subgroup = subgroup,
    outcome = outcome_label,
    threshold_label = threshold_label,
    threshold = threshold,
    n = nrow(model_data),
    events = sum(model_data$outcome == 1),
    auc = as.numeric(pROC::auc(roc_obj)),
    sensitivity = ifelse(tp + fn > 0, tp / (tp + fn), NA_real_),
    specificity = ifelse(tn + fp > 0, tn / (tn + fp), NA_real_),
    ppv = ifelse(tp + fp > 0, tp / (tp + fp), NA_real_),
    npv = ifelse(tn + fn > 0, tn / (tn + fn), NA_real_)
  )
}

youden_threshold <- function(data, outcome_name) {
  model_data <- data %>%
    transmute(outcome = .data[[outcome_name]], dxa_mbr = dxa_mbr) %>%
    filter(!is.na(outcome), is.finite(dxa_mbr))

  roc_obj <- pROC::roc(model_data$outcome, model_data$dxa_mbr, quiet = TRUE, direction = "<")
  as.numeric(pROC::coords(roc_obj, x = "best", best.method = "youden", ret = "threshold"))
}

nhanes <- prepare_nhanes()
knhanes <- prepare_knhanes()

rcs_results <- bind_rows(
  fit_rcs_logistic(nhanes, "prev_fracture", "NHANES 2013-2014", "Age 40-59", "Previous fracture"),
  fit_rcs_logistic(nhanes, "self_report_osteoporosis", "NHANES 2013-2014", "Age 40-59", "Self-reported osteoporosis"),
  fit_rcs_logistic(filter(nhanes, age >= 50), "prev_fracture", "NHANES 2013-2014", "Age 50-59", "Previous fracture"),
  fit_rcs_logistic(filter(nhanes, age >= 50), "self_report_osteoporosis", "NHANES 2013-2014", "Age 50-59", "Self-reported osteoporosis"),
  fit_rcs_logistic(knhanes, "osteoporosis_any", "KNHANES 2008-2011", "Age >=50", "Overall osteoporosis"),
  fit_rcs_logistic(knhanes, "osteoporosis_fn", "KNHANES 2008-2011", "Age >=50", "Femoral neck osteoporosis"),
  fit_rcs_logistic(knhanes, "osteoporosis_ls", "KNHANES 2008-2011", "Age >=50", "Lumbar spine osteoporosis")
)

threshold_results <- bind_rows(
  threshold_metrics(nhanes, "prev_fracture", "NHANES 2013-2014", "Age 40-59", "Previous fracture", 16, "Fixed MBR 16"),
  threshold_metrics(nhanes, "self_report_osteoporosis", "NHANES 2013-2014", "Age 40-59", "Self-reported osteoporosis", 16, "Fixed MBR 16"),
  threshold_metrics(nhanes, "prev_fracture", "NHANES 2013-2014", "Age 40-59", "Previous fracture", quantile(nhanes$dxa_mbr, 0.75, na.rm = TRUE), "Upper quartile"),
  threshold_metrics(nhanes, "self_report_osteoporosis", "NHANES 2013-2014", "Age 40-59", "Self-reported osteoporosis", quantile(nhanes$dxa_mbr, 0.75, na.rm = TRUE), "Upper quartile"),
  threshold_metrics(nhanes, "prev_fracture", "NHANES 2013-2014", "Age 40-59", "Previous fracture", youden_threshold(nhanes, "prev_fracture"), "Youden"),
  threshold_metrics(nhanes, "self_report_osteoporosis", "NHANES 2013-2014", "Age 40-59", "Self-reported osteoporosis", youden_threshold(nhanes, "self_report_osteoporosis"), "Youden"),
  threshold_metrics(knhanes, "osteoporosis_any", "KNHANES 2008-2011", "Age >=50", "Overall osteoporosis", quantile(knhanes$dxa_mbr, 0.75, na.rm = TRUE), "Upper quartile"),
  threshold_metrics(knhanes, "osteoporosis_fn", "KNHANES 2008-2011", "Age >=50", "Femoral neck osteoporosis", quantile(knhanes$dxa_mbr, 0.75, na.rm = TRUE), "Upper quartile"),
  threshold_metrics(knhanes, "osteoporosis_ls", "KNHANES 2008-2011", "Age >=50", "Lumbar spine osteoporosis", quantile(knhanes$dxa_mbr, 0.75, na.rm = TRUE), "Upper quartile"),
  threshold_metrics(knhanes, "osteoporosis_any", "KNHANES 2008-2011", "Age >=50", "Overall osteoporosis", youden_threshold(knhanes, "osteoporosis_any"), "Youden"),
  threshold_metrics(knhanes, "osteoporosis_fn", "KNHANES 2008-2011", "Age >=50", "Femoral neck osteoporosis", youden_threshold(knhanes, "osteoporosis_fn"), "Youden"),
  threshold_metrics(knhanes, "osteoporosis_ls", "KNHANES 2008-2011", "Age >=50", "Lumbar spine osteoporosis", youden_threshold(knhanes, "osteoporosis_ls"), "Youden")
)

readr::write_csv(rcs_results, file.path(table_dir, "RCS_Logistic_Model_Comparison.csv"))
readr::write_csv(threshold_results, file.path(table_dir, "Threshold_Sensitivity_Specificity_Table.csv"))

cat("Saved RCS and threshold-performance tables to:\n", table_dir, "\n")
