library(haven)
library(dplyr)
library(readr)
library(stringr)

root_dir <- normalizePath(".", winslash = "/", mustWork = TRUE)
raw_dir <- file.path(root_dir, "data", "raw", "KNHANES_2008_2011")
clean_dir <- file.path(root_dir, "data", "processed", "KNHANES")
out_dir <- file.path(root_dir, "outputs", "knhanes", "checks")

dir.create(clean_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

years <- c("08", "09", "10", "11")
merged_list <- list()
merge_summary <- list()

normalize_vector <- function(x) {
  if (inherits(x, "haven_labelled")) {
    x <- haven::zap_labels(x)
  }
  x
}

cast_vector <- function(x, target) {
  if (target == "character") {
    return(as.character(x))
  }
  if (target == "numeric") {
    return(suppressWarnings(as.numeric(as.character(x))))
  }
  x
}

for (yy in years) {
  year_full <- paste0("20", yy)
  all_path <- file.path(raw_dir, "all", sprintf("hn%s_all.sas7bdat", yy))
  dxa_path <- file.path(raw_dir, "dxa", sprintf("hn%s_dxa.sas7bdat", yy))

  all_dat <- read_sas(all_path)
  dxa_dat <- read_sas(dxa_path)

  names(all_dat) <- tolower(names(all_dat))
  names(dxa_dat) <- tolower(names(dxa_dat))
  all_dat <- all_dat %>% mutate(across(everything(), normalize_vector))
  dxa_dat <- dxa_dat %>% mutate(across(everything(), normalize_vector))

  stopifnot("id" %in% names(all_dat), "id" %in% names(dxa_dat))

  overlap_cols <- intersect(names(all_dat), names(dxa_dat))
  dxa_only <- setdiff(names(dxa_dat), names(all_dat))

  merged <- all_dat %>%
    left_join(dxa_dat %>% select(id, all_of(dxa_only)), by = "id") %>%
    mutate(survey_year = as.integer(year_full))

  merged_list[[yy]] <- merged

  merge_summary[[yy]] <- tibble(
    survey_year = as.integer(year_full),
    all_nrow = nrow(all_dat),
    dxa_nrow = nrow(dxa_dat),
    all_unique_id = n_distinct(all_dat$id),
    dxa_unique_id = n_distinct(dxa_dat$id),
    matched_id = nrow(inner_join(all_dat %>% distinct(id), dxa_dat %>% distinct(id), by = "id")),
    merged_nrow = nrow(merged),
    overlap_col_count = length(overlap_cols),
    dxa_only_col_count = length(dxa_only)
  )

  write_csv(
    merged %>% select(id, survey_year, sex, age, contains("dx_"), contains("dw_")),
    file.path(out_dir, sprintf("knhanes_%s_merged_keyvars.csv", yy))
  )
}

all_cols <- unique(unlist(lapply(merged_list, names)))

for (nm in names(merged_list)) {
  missing_cols <- setdiff(all_cols, names(merged_list[[nm]]))
  if (length(missing_cols) > 0) {
    for (mc in missing_cols) {
      merged_list[[nm]][[mc]] <- NA
    }
  }
  merged_list[[nm]] <- merged_list[[nm]][, all_cols]
}

target_types <- sapply(all_cols, function(col) {
  cls <- unlist(lapply(merged_list, function(df) class(df[[col]])[1]))
  if (any(cls %in% c("character"))) {
    "character"
  } else if (any(cls %in% c("double", "numeric", "integer"))) {
    "numeric"
  } else {
    "character"
  }
}, USE.NAMES = TRUE)

merged_list <- lapply(merged_list, function(df) {
  for (col in names(target_types)) {
    df[[col]] <- cast_vector(df[[col]], target_types[[col]])
  }
  df
})

combined <- bind_rows(merged_list)
summary_tbl <- bind_rows(merge_summary)

write_csv(summary_tbl, file.path(out_dir, "knhanes_2008_2011_merge_summary_v2.csv"))
write_rds(combined, file.path(clean_dir, "KNHANES_2008_2011_ALL_DXA_merged.rds"), compress = "gz")
write_csv(combined, file.path(clean_dir, "KNHANES_2008_2011_ALL_DXA_merged.csv.gz"))

keyvar_names <- names(combined)[str_detect(names(combined), "^(id|survey_year|sex|age|wt_|dx_|dw_)")]
write_lines(keyvar_names, file.path(out_dir, "knhanes_2008_2011_key_variable_names.txt"))

cat("Merged file written to:", file.path(clean_dir, "KNHANES_2008_2011_ALL_DXA_merged.rds"), "\n")
print(summary_tbl)

