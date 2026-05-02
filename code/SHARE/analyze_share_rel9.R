#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
})

# Public reproducibility script for the SHARE clinical-outcome context analysis.
# Raw SHARE files are not redistributed. Users should download the approved
# Release 9.0.0 R archive from https://releases.sharedataportal.eu/ and update
# `raw_file` below to the local extracted GH_SHARE_g.rdata path.

root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
raw_file <- file.path(root, "data/raw/SHARE/GH_SHARE_g.rdata")
processed_dir <- file.path(root, "data/processed/SHARE")
output_dir <- file.path(root, "outputs/SHARE")
dir.create(processed_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(raw_file)) {
  stop(
    "SHARE raw file was not found. Download Gateway Harmonized SHARE ",
    "Release 9.0.0 and place GH_SHARE_g.rdata at: ", raw_file
  )
}

loaded <- load(raw_file)
if (!"H_SHARE_g" %in% loaded) {
  stop("Expected object H_SHARE_g was not found in GH_SHARE_g.rdata")
}
share <- H_SHARE_g
rm(H_SHARE_g)

get_col <- function(data, name) {
  if (name %in% names(data)) data[[name]] else rep(NA, nrow(data))
}

as_num <- function(x) suppressWarnings(as.numeric(x))

recode01 <- function(x) {
  x <- as_num(x)
  ifelse(x %in% c(0, 1), x, NA_real_)
}

weighted_mean <- function(x, w) {
  ok_x <- !is.na(x)
  if (!any(ok_x)) return(NA_real_)
  ok_w <- ok_x & !is.na(w) & is.finite(w) & w > 0
  if (!any(ok_w) || sum(w[ok_w], na.rm = TRUE) <= 0) return(mean(x[ok_x], na.rm = TRUE))
  weighted.mean(x[ok_w], w[ok_w], na.rm = TRUE)
}

waves <- c(1, 2, 4, 5, 6, 7, 8, 9)

long <- bind_rows(lapply(waves, function(w) {
  data.frame(
    mergeid = get_col(share, "mergeid"),
    country = get_col(share, "country"),
    wave = w,
    gender_code = as_num(get_col(share, "ragender")),
    age = as_num(get_col(share, paste0("r", w, "agey"))),
    wtresp = as_num(get_col(share, paste0("r", w, "wtresp"))),
    fall_related_limitation = recode01(get_col(share, paste0("r", w, "fall_s"))),
    hip_fracture_ever = recode01(get_col(share, paste0("r", w, "hipe"))),
    hip_fracture_since_last_wave = recode01(get_col(share, paste0("r", w, "hip"))),
    osteoporosis_ever = recode01(get_col(share, paste0("r", w, "osteoe"))),
    osteoporosis_medication = recode01(get_col(share, paste0("r", w, "rxosteo")))
  )
}))

long <- long %>%
  mutate(
    sex = case_when(gender_code == 1 ~ "Male", gender_code == 2 ~ "Female", TRUE ~ NA_character_),
    female = case_when(gender_code == 1 ~ 0, gender_code == 2 ~ 1, TRUE ~ NA_real_),
    age_group = cut(
      age,
      breaks = c(50, 60, 70, 80, Inf),
      right = FALSE,
      labels = c("50-59", "60-69", "70-79", ">=80")
    ),
    age10 = age / 10,
    wtresp_valid = ifelse(is.finite(wtresp) & wtresp > 0, wtresp, NA_real_)
  ) %>%
  filter(!is.na(age), age >= 50, !is.na(sex))

saveRDS(long, file.path(processed_dir, "share_rel9_outcomes_long_age50plus.rds"))

outcomes <- c(
  "fall_related_limitation",
  "hip_fracture_ever",
  "hip_fracture_since_last_wave",
  "osteoporosis_ever",
  "osteoporosis_medication"
)

summary_by_age_sex <- bind_rows(lapply(outcomes, function(outcome) {
  long %>%
    filter(!is.na(age_group), !is.na(.data[[outcome]])) %>%
    group_by(outcome = outcome, age_group, sex) %>%
    summarise(
      n = n(),
      events = sum(.data[[outcome]], na.rm = TRUE),
      prevalence = mean(.data[[outcome]], na.rm = TRUE),
      weighted_prevalence = weighted_mean(.data[[outcome]], wtresp_valid),
      .groups = "drop"
    )
}))

fit_one <- function(data, outcome, weighted = FALSE) {
  dat <- data %>%
    filter(!is.na(.data[[outcome]]), !is.na(age10), !is.na(female), !is.na(wave), !is.na(country))
  if (outcome == "hip_fracture_since_last_wave") {
    dat <- dat %>% filter(wave != 1)
  }
  if (weighted) {
    mean_wt <- mean(dat$wtresp_valid[is.finite(dat$wtresp_valid) & dat$wtresp_valid > 0], na.rm = TRUE)
    dat <- dat %>%
      mutate(wtresp_scaled = wtresp_valid / mean_wt) %>%
      filter(is.finite(wtresp_scaled), wtresp_scaled > 0)
  }
  if (nrow(dat) < 100 || length(unique(dat[[outcome]])) < 2) return(data.frame())

  form <- as.formula(paste0(outcome, " ~ age10 + female + factor(wave) + factor(country)"))
  fit <- if (weighted) {
    glm(form, data = dat, weights = wtresp_scaled, family = quasibinomial(), control = list(maxit = 100))
  } else {
    glm(form, data = dat, family = binomial())
  }
  coef_table <- as.data.frame(summary(fit)$coefficients)
  coef_table$term <- rownames(coef_table)
  names(coef_table)[1:4] <- c("estimate_log", "std.error", "statistic", "p.value")
  coef_table %>%
    filter(term %in% c("age10", "female")) %>%
    transmute(
      model = ifelse(weighted, "response_weighted", "unweighted"),
      outcome = outcome,
      term = term,
      estimate = exp(estimate_log),
      conf_low = exp(estimate_log - 1.96 * std.error),
      conf_high = exp(estimate_log + 1.96 * std.error),
      p_value = p.value,
      n = nrow(dat),
      events = sum(dat[[outcome]], na.rm = TRUE)
    )
}

model_results <- bind_rows(lapply(outcomes, function(outcome) {
  bind_rows(
    fit_one(long, outcome, weighted = FALSE),
    fit_one(long, outcome, weighted = TRUE)
  )
}))

write.csv(summary_by_age_sex, file.path(output_dir, "share_rel9_summary_by_age_sex.csv"), row.names = FALSE)
write.csv(model_results, file.path(output_dir, "share_rel9_adjusted_models.csv"), row.names = FALSE)

message("SHARE Release 9.0.0 analysis complete.")
message("Analytic respondent-wave records: ", nrow(long))
message("Participants: ", dplyr::n_distinct(long$mergeid))

