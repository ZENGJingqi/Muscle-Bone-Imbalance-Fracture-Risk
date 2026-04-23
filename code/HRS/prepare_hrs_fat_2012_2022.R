library(dplyr)
library(haven)
library(readr)
library(stringr)

root_dir <- normalizePath(".", winslash = "/", mustWork = TRUE)
raw_dir <- file.path(root_dir, "data", "raw", "HRS", "raw")
clean_dir <- file.path(root_dir, "data", "processed", "HRS")
analysis_dir <- file.path(root_dir, "outputs", "hrs", "checks")
dir.create(clean_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(analysis_dir, recursive = TRUE, showWarnings = FALSE)

wave_map <- tibble::tribble(
  ~survey_year, ~prefix, ~subdir,     ~sas_name,
  2012,         "N",     "fat2012",   "h12f3a.sas7bdat",
  2014,         "O",     "fat2014",   "h14f2b.sas7bdat",
  2016,         "P",     "fat2016",   "h16f2c.sas7bdat",
  2018,         "Q",     "fat2018",   "h18f2c.sas7bdat",
  2020,         "R",     "fat2020",   "h20f1b.sas7bdat",
  2022,         "S",     "fat2022",   "h22e3a.sas7bdat"
)

recode_binary_hrs <- function(x) {
  case_when(
    is.na(x) ~ NA_real_,
    x == 1 ~ 1,
    x == 5 ~ 0,
    TRUE ~ NA_real_
  )
}

clean_numeric <- function(x) suppressWarnings(as.numeric(x))

clean_measure <- function(x, upper = Inf) {
  x <- clean_numeric(x)
  case_when(
    is.na(x) ~ NA_real_,
    x < 0 ~ NA_real_,
    x >= upper ~ NA_real_,
    TRUE ~ x
  )
}

read_one_wave <- function(survey_year, prefix, subdir, sas_name) {
  sas_path <- file.path(raw_dir, subdir, sas_name)
  if (!file.exists(sas_path)) stop("Missing file: ", sas_path)

  vars <- c(
    "HHIDPN",
    paste0(prefix, "A019"),
    paste0(prefix, "X060_R"),
    paste0(prefix, "C079"),
    paste0(prefix, "C080"),
    paste0(prefix, "C081"),
    paste0(prefix, "C082"),
    paste0(prefix, "C280"),
    paste0(prefix, "C281"),
    paste0(prefix, "C139"),
    paste0(prefix, "C141"),
    paste0(prefix, "C142"),
    paste0(prefix, "Z110")
  )

  dat <- read_sas(sas_path, col_select = all_of(vars)) %>%
    transmute(
      HHIDPN = clean_numeric(HHIDPN),
      survey_year = survey_year,
      age = clean_numeric(.data[[paste0(prefix, "A019")]]),
      sex_code = clean_numeric(.data[[paste0(prefix, "X060_R")]]),
      fall_past2y = recode_binary_hrs(clean_numeric(.data[[paste0(prefix, "C079")]])),
      fall_count = clean_measure(.data[[paste0(prefix, "C080")]], upper = 98),
      fall_injury = recode_binary_hrs(clean_numeric(.data[[paste0(prefix, "C081")]])),
      broken_hip = recode_binary_hrs(clean_numeric(.data[[paste0(prefix, "C082")]])),
      osteoporosis = recode_binary_hrs(clean_numeric(.data[[paste0(prefix, "C280")]])),
      bone_density_test = recode_binary_hrs(clean_numeric(.data[[paste0(prefix, "C281")]])),
      weight_lb = clean_measure(.data[[paste0(prefix, "C139")]], upper = 900),
      height_feet = clean_measure(.data[[paste0(prefix, "C141")]], upper = 20),
      height_inches_only = clean_measure(.data[[paste0(prefix, "C142")]], upper = 98),
      prev_wave_broken_hip = recode_binary_hrs(clean_numeric(.data[[paste0(prefix, "Z110")]]))
    ) %>%
    mutate(
      sex = factor(case_when(
        sex_code == 1 ~ "Male",
        sex_code == 2 ~ "Female",
        TRUE ~ NA_character_
      ), levels = c("Male", "Female")),
      height_in = ifelse(!is.na(height_feet) & !is.na(height_inches_only),
                         height_feet * 12 + height_inches_only, NA_real_),
      bmi_calc = ifelse(!is.na(weight_lb) & !is.na(height_in) & height_in > 0,
                        703 * weight_lb / (height_in ^ 2), NA_real_),
      age_group = case_when(
        is.na(age) ~ NA_character_,
        age < 50 ~ "<50",
        age < 60 ~ "50-59",
        age < 70 ~ "60-69",
        age < 80 ~ "70-79",
        TRUE ~ "80+"
      ),
      age_group = factor(age_group, levels = c("<50", "50-59", "60-69", "70-79", "80+"))
    )

  dat
}

hrs_pooled <- purrr::pmap_dfr(wave_map, read_one_wave)

availability <- hrs_pooled %>%
  group_by(survey_year) %>%
  summarise(
    n = n(),
    age_non_missing = sum(!is.na(age)),
    sex_non_missing = sum(!is.na(sex)),
    fall_non_missing = sum(!is.na(fall_past2y)),
    injury_non_missing = sum(!is.na(fall_injury)),
    hip_non_missing = sum(!is.na(broken_hip)),
    osteoporosis_non_missing = sum(!is.na(osteoporosis)),
    weight_non_missing = sum(!is.na(weight_lb)),
    height_non_missing = sum(!is.na(height_in)),
    bmi_non_missing = sum(!is.na(bmi_calc)),
    .groups = "drop"
  )

sex_summary <- hrs_pooled %>%
  filter(age >= 50, !is.na(sex)) %>%
  group_by(survey_year, sex) %>%
  summarise(
    n = n(),
    mean_age = mean(age, na.rm = TRUE),
    mean_bmi = mean(bmi_calc, na.rm = TRUE),
    fall_prev = mean(fall_past2y == 1, na.rm = TRUE),
    injury_prev = mean(fall_injury == 1, na.rm = TRUE),
    hip_prev = mean(broken_hip == 1, na.rm = TRUE),
    osteoporosis_prev = mean(osteoporosis == 1, na.rm = TRUE),
    .groups = "drop"
  )

saveRDS(hrs_pooled, file.path(clean_dir, "HRS_fat_2012_2022_event_bundle.rds"))
write_csv(hrs_pooled, file.path(clean_dir, "HRS_fat_2012_2022_event_bundle.csv.gz"))
write_csv(availability, file.path(analysis_dir, "hrs_2012_2022_availability_summary.csv"))
write_csv(sex_summary, file.path(analysis_dir, "hrs_2012_2022_age50plus_summary_by_year_sex.csv"))

cat("Saved pooled HRS fat file bundle.\n")

