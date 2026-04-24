library(dplyr)
library(haven)
library(readr)
library(stringr)

root_dir <- normalizePath(".", winslash = "/", mustWork = TRUE)
charls_dir <- file.path(root_dir, "外部数据", "CHARLS")
extract_dir <- file.path(charls_dir, "extracted")
clean_dir <- file.path(root_dir, "外部数据", "cleaned", "05_CHARLS")
check_dir <- file.path(root_dir, "工作记录", "analysis_outputs", "05_CHARLS", "checks")

dir.create(clean_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(check_dir, recursive = TRUE, showWarnings = FALSE)

harm_path <- file.path(extract_dir, "harmonized", "H_CHARLS_D_Data.dta")
if (!file.exists(harm_path)) stop("Missing harmonized file: ", harm_path)

harm <- read_dta(
  harm_path,
  col_select = c(ID, ragender, r1agey, r2agey, r3agey, r4agey, r1mbmi, r2mbmi, r3mbmi)
) %>%
  mutate(
    ID = as.character(ID),
    sex_h = case_when(
      as.numeric(ragender) == 1 ~ "Male",
      as.numeric(ragender) == 2 ~ "Female",
      TRUE ~ NA_character_
    )
  ) %>%
  select(ID, sex_h, r1agey, r2agey, r3agey, r4agey, r1mbmi, r2mbmi, r3mbmi)

clean_binary <- function(x) {
  x <- as.numeric(x)
  case_when(
    is.na(x) ~ NA_real_,
    x == 1 ~ 1,
    x == 2 ~ 0,
    TRUE ~ NA_real_
  )
}

clean_count <- function(x, upper = 98) {
  x <- suppressWarnings(as.numeric(x))
  case_when(
    is.na(x) ~ NA_real_,
    x < 0 ~ NA_real_,
    x >= upper ~ NA_real_,
    TRUE ~ x
  )
}

normalize_charls_id <- function(x) {
  x <- as.character(x)
  dplyr::case_when(
    nchar(x) == 11 ~ paste0(substr(x, 1, 9), "0", substr(x, 10, 11)),
    TRUE ~ x
  )
}

age_group_50plus <- function(age) {
  case_when(
    is.na(age) ~ NA_character_,
    age < 50 ~ "<50",
    age < 60 ~ "50-59",
    age < 70 ~ "60-69",
    age < 80 ~ "70-79",
    TRUE ~ "80+"
  )
}

read_wave_health <- function(path, year) {
  if (!file.exists(path)) stop("Missing wave file: ", path)

  if (year %in% c(2011, 2013, 2015)) {
    dat <- read_dta(path, col_select = c(ID, da022, da023, da024, da025)) %>%
      transmute(
        ID = normalize_charls_id(ID),
        survey_year = year,
        fall_recent = clean_binary(da023),
        hip_fracture = clean_binary(da025),
        fall_count = clean_count(da024, upper = 98),
        fall_medical_treat_count = NA_real_,
        injury_limit_daily = clean_binary(da022),
        question_frame = "general_or_recent_self_report"
      ) %>%
      mutate(
        fall_count = case_when(
          fall_recent == 0 & is.na(fall_count) ~ 0,
          TRUE ~ fall_count
        )
      )
  } else if (year == 2018) {
    dat <- read_dta(path, col_select = c(ID, da023_w4, da024, da025_w4)) %>%
      transmute(
        ID = normalize_charls_id(ID),
        survey_year = year,
        fall_recent = clean_binary(da023_w4),
        hip_fracture = clean_binary(da025_w4),
        fall_count = NA_real_,
        fall_medical_treat_count = clean_count(da024, upper = 98),
        injury_limit_daily = NA_real_,
        question_frame = "since_last_interview"
      ) %>%
      mutate(
        fall_medical_treat_count = case_when(
          fall_recent == 0 & is.na(fall_medical_treat_count) ~ 0,
          TRUE ~ fall_medical_treat_count
        )
      )
  } else if (year == 2020) {
    dat <- read_dta(path, col_select = c(ID, da022, da024, da025)) %>%
      transmute(
        ID = normalize_charls_id(ID),
        survey_year = year,
        fall_recent = clean_binary(da022),
        hip_fracture = clean_binary(da025),
        fall_count = NA_real_,
        fall_medical_treat_count = clean_count(da024, upper = 98),
        injury_limit_daily = NA_real_,
        question_frame = "since_last_interview"
      ) %>%
      mutate(
        fall_medical_treat_count = case_when(
          fall_recent == 0 & is.na(fall_medical_treat_count) ~ 0,
          TRUE ~ fall_medical_treat_count
        )
      )
  } else {
    stop("Unsupported year: ", year)
  }

  dat
}

read_wave_demo2020 <- function(path) {
  read_dta(path, col_select = c(ID, xrage, xrgender)) %>%
    transmute(
      ID = normalize_charls_id(ID),
      age = suppressWarnings(as.numeric(xrage)),
      sex = case_when(
        suppressWarnings(as.numeric(xrgender)) == 1 ~ "Male",
        suppressWarnings(as.numeric(xrgender)) == 2 ~ "Female",
        TRUE ~ NA_character_
      )
    )
}

wave_files <- tibble::tribble(
  ~survey_year, ~health_path, ~demo_path,
  2011, file.path(extract_dir, "2011_wave1", "health_status_and_functioning.dta"), NA_character_,
  2013, file.path(extract_dir, "2013_wave2", "Health_Status_and_Functioning.dta"), NA_character_,
  2015, file.path(extract_dir, "2015_wave3", "Health_Status_and_Functioning.dta"), NA_character_,
  2018, file.path(extract_dir, "2018_wave4", "Health_Status_and_Functioning.dta"), NA_character_,
  2020, file.path(extract_dir, "2020_wave5", "Health_Status_and_Functioning.dta"), file.path(extract_dir, "2020_wave5", "Demographic_Background.dta")
)

charls_bundle <- purrr::pmap_dfr(
  wave_files,
  function(survey_year, health_path, demo_path) {
    base_dat <- read_wave_health(health_path, survey_year)

    if (survey_year == 2011) {
      base_dat %>%
        left_join(harm %>% transmute(ID, age = r1agey, sex = sex_h, bmi = r1mbmi), by = "ID")
    } else if (survey_year == 2013) {
      base_dat %>%
        left_join(harm %>% transmute(ID, age = r2agey, sex = sex_h, bmi = r2mbmi), by = "ID")
    } else if (survey_year == 2015) {
      base_dat %>%
        left_join(harm %>% transmute(ID, age = r3agey, sex = sex_h, bmi = r3mbmi), by = "ID")
    } else if (survey_year == 2018) {
      base_dat %>%
        left_join(harm %>% transmute(ID, age = r4agey, sex = sex_h, bmi = NA_real_), by = "ID")
    } else if (survey_year == 2020) {
      demo20 <- read_wave_demo2020(demo_path)
      base_dat %>%
        left_join(demo20 %>% mutate(bmi = NA_real_), by = "ID")
    } else {
      stop("Unsupported year in merge: ", survey_year)
    }
  }
) %>%
  mutate(
    sex = factor(sex, levels = c("Male", "Female")),
    age_group = factor(age_group_50plus(age), levels = c("<50", "50-59", "60-69", "70-79", "80+")),
    fall_medical_treat = case_when(
      is.na(fall_medical_treat_count) ~ NA_real_,
      fall_medical_treat_count > 0 ~ 1,
      fall_medical_treat_count == 0 ~ 0,
      TRUE ~ NA_real_
    ),
    fall_count_ge1 = case_when(
      is.na(fall_count) ~ NA_real_,
      fall_count > 0 ~ 1,
      fall_count == 0 ~ 0,
      TRUE ~ NA_real_
    )
  )

availability <- charls_bundle %>%
  group_by(survey_year) %>%
  summarise(
    n = n(),
    age_non_missing = sum(!is.na(age)),
    sex_non_missing = sum(!is.na(sex)),
    bmi_non_missing = sum(!is.na(bmi)),
    fall_non_missing = sum(!is.na(fall_recent)),
    hip_non_missing = sum(!is.na(hip_fracture)),
    injury_limit_non_missing = sum(!is.na(injury_limit_daily)),
    fall_medical_non_missing = sum(!is.na(fall_medical_treat)),
    question_frame = dplyr::first(question_frame),
    .groups = "drop"
  )

older50_summary <- charls_bundle %>%
  filter(age >= 50, !is.na(sex)) %>%
  group_by(survey_year, sex) %>%
  summarise(
    n = n(),
    mean_age = mean(age, na.rm = TRUE),
    mean_bmi = mean(bmi, na.rm = TRUE),
    fall_prev = mean(fall_recent == 1, na.rm = TRUE),
    hip_prev = mean(hip_fracture == 1, na.rm = TRUE),
    injury_limit_prev = mean(injury_limit_daily == 1, na.rm = TRUE),
    medical_treat_prev = mean(fall_medical_treat == 1, na.rm = TRUE),
    .groups = "drop"
  )

saveRDS(charls_bundle, file.path(clean_dir, "CHARLS_2011_2020_clinical_context_bundle.rds"))
write_csv(charls_bundle, file.path(clean_dir, "CHARLS_2011_2020_clinical_context_bundle.csv.gz"))
write_csv(availability, file.path(check_dir, "CHARLS_Wave_Availability_2026-04-24.csv"))
write_csv(older50_summary, file.path(check_dir, "CHARLS_Age50plus_Summary_By_Wave_Sex_2026-04-24.csv"))

cat("Saved CHARLS clinical context bundle.\n")
