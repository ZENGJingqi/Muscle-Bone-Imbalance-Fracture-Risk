library(dplyr)
library(forcats)
library(ggplot2)
library(ggsci)
library(patchwork)
library(pROC)
library(readr)
library(scales)
library(tidyr)
library(broom)

root_dir <- normalizePath(".", winslash = "/", mustWork = TRUE)
analysis_dir <- file.path(root_dir, "outputs", "nhanes")
figure_dir <- file.path(analysis_dir, "figures")
dir.create(analysis_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(figure_dir, showWarnings = FALSE, recursive = TRUE)

cell_palette <- pal_npg("nrc")(10)
names(cell_palette) <- paste0("c", seq_along(cell_palette))
pick_cols <- function(values, labels) {
  stats::setNames(unname(values), labels)
}

theme_gsci_cell <- function() {
  theme_bw(base_size = 18) +
    theme(
      panel.grid = element_blank(),
      panel.border = element_rect(color = "black", linewidth = 0.8),
      strip.background = element_rect(fill = "white", color = "black", linewidth = 0.8),
      strip.text = element_text(size = 22, face = "bold"),
      axis.title = element_text(size = 30, face = "bold"),
      axis.text = element_text(size = 24, color = "black"),
      legend.title = element_text(size = 30, face = "bold"),
      legend.text = element_text(size = 28),
      legend.key.height = grid::unit(0.95, "cm"),
      legend.key.width = grid::unit(1.90, "cm"),
      legend.position = "top",
      legend.direction = "horizontal",
      legend.box = "horizontal",
      legend.justification = "center",
      legend.margin = margin(0, 0, 0, 0),
      legend.box.margin = margin(0, 0, 4, 0),
      legend.spacing.x = grid::unit(0.35, "cm"),
      panel.spacing = grid::unit(1.25, "lines"),
      plot.title = element_blank(),
      plot.subtitle = element_blank(),
      plot.caption = element_blank(),
      plot.tag = element_text(size = 30, face = "bold"),
      plot.tag.position = c(0.015, 0.985),
      plot.margin = margin(12, 12, 10, 12)
    )
}

save_pub_plot <- function(plot_obj, stem, width, height) {
  ggsave(file.path(figure_dir, paste0(stem, ".png")), plot_obj, width = width, height = height, dpi = 400, bg = "white")
  ggsave(file.path(figure_dir, paste0(stem, ".pdf")), plot_obj, width = width, height = height, device = cairo_pdf, bg = "white")
}

to_yes_no <- function(x) {
  ifelse(x == 1, 1, ifelse(x == 2, 0, NA_real_))
}

standardize <- function(x) {
  (x - mean(x, na.rm = TRUE)) / stats::sd(x, na.rm = TRUE)
}

fit_linear <- function(data, outcome_name, group_name) {
  model_data <- data %>%
    select(age, sex_male, weight, dxa_mbr, all_of(outcome_name)) %>%
    tidyr::drop_na()
  if (nrow(model_data) < 80) return(NULL)

  model_data <- model_data %>%
    mutate(
      dxa_mbr_z = standardize(dxa_mbr),
      age_z = standardize(age),
      weight_z = standardize(weight)
    )

  fit <- lm(reformulate(c("dxa_mbr_z", "age_z", "sex_male", "weight_z"), response = outcome_name), data = model_data)
  coef_row <- summary(fit)$coefficients["dxa_mbr_z", ]
  tibble(
    group = group_name,
    outcome = outcome_name,
    n = nrow(model_data),
    events = NA_integer_,
    estimate = unname(coef_row["Estimate"]),
    std_error = unname(coef_row["Std. Error"]),
    conf_low = estimate - 1.96 * std_error,
    conf_high = estimate + 1.96 * std_error,
    p_value = unname(coef_row["Pr(>|t|)"]),
    metric = "Beta"
  )
}

fit_logistic <- function(data, outcome_name, group_name) {
  model_data <- data %>%
    select(age, sex_male, weight, dxa_mbr, all_of(outcome_name)) %>%
    tidyr::drop_na()
  if (nrow(model_data) < 80 || dplyr::n_distinct(model_data[[outcome_name]]) < 2) return(NULL)

  model_data <- model_data %>%
    mutate(
      dxa_mbr_z = standardize(dxa_mbr),
      age_z = standardize(age),
      weight_z = standardize(weight)
    )

  fit <- glm(reformulate(c("dxa_mbr_z", "age_z", "sex_male", "weight_z"), response = outcome_name), data = model_data, family = binomial())
  coef_row <- summary(fit)$coefficients["dxa_mbr_z", ]
  est <- unname(coef_row["Estimate"])
  se <- unname(coef_row["Std. Error"])

  tibble(
    group = group_name,
    outcome = outcome_name,
    n = nrow(model_data),
    events = sum(model_data[[outcome_name]] == 1, na.rm = TRUE),
    estimate = exp(est),
    std_error = se,
    conf_low = exp(est - 1.96 * se),
    conf_high = exp(est + 1.96 * se),
    p_value = unname(coef_row["Pr(>|z|)"]),
    metric = "OR"
  )
}

fit_linear_binary <- function(data, outcome_name, group_name) {
  model_data <- data %>%
    select(age, sex_male, weight, mbr16_high, all_of(outcome_name)) %>%
    tidyr::drop_na()
  if (nrow(model_data) < 80 || dplyr::n_distinct(model_data$mbr16_high) < 2) return(NULL)

  model_data <- model_data %>%
    mutate(
      age_z = standardize(age),
      weight_z = standardize(weight)
    )

  fit <- lm(reformulate(c("mbr16_high", "age_z", "sex_male", "weight_z"), response = outcome_name), data = model_data)
  coef_row <- summary(fit)$coefficients["mbr16_high", ]
  tibble(
    group = group_name,
    outcome = outcome_name,
    n = nrow(model_data),
    events = NA_integer_,
    estimate = unname(coef_row["Estimate"]),
    std_error = unname(coef_row["Std. Error"]),
    conf_low = estimate - 1.96 * std_error,
    conf_high = estimate + 1.96 * std_error,
    p_value = unname(coef_row["Pr(>|t|)"]),
    metric = "Beta",
    contrast = "MBR >=16 vs <16"
  )
}

fit_logistic_binary <- function(data, outcome_name, group_name) {
  model_data <- data %>%
    select(age, sex_male, weight, mbr16_high, all_of(outcome_name)) %>%
    tidyr::drop_na()
  if (nrow(model_data) < 80 || dplyr::n_distinct(model_data$mbr16_high) < 2 || dplyr::n_distinct(model_data[[outcome_name]]) < 2) return(NULL)

  model_data <- model_data %>%
    mutate(
      age_z = standardize(age),
      weight_z = standardize(weight)
    )

  fit <- glm(reformulate(c("mbr16_high", "age_z", "sex_male", "weight_z"), response = outcome_name), data = model_data, family = binomial())
  coef_row <- summary(fit)$coefficients["mbr16_high", ]
  est <- unname(coef_row["Estimate"])
  se <- unname(coef_row["Std. Error"])

  tibble(
    group = group_name,
    outcome = outcome_name,
    n = nrow(model_data),
    events = sum(model_data[[outcome_name]] == 1, na.rm = TRUE),
    estimate = exp(est),
    std_error = se,
    conf_low = exp(est - 1.96 * se),
    conf_high = exp(est + 1.96 * se),
    p_value = unname(coef_row["Pr(>|z|)"]),
    metric = "OR",
    contrast = "MBR >=16 vs <16"
  )
}

fit_incremental <- function(data, outcome_name, family_name, group_name) {
  model_data <- data %>%
    select(age, sex_male, weight, dxa_mbr, all_of(outcome_name)) %>%
    tidyr::drop_na()
  if (nrow(model_data) < 80 || (family_name == "binomial" && dplyr::n_distinct(model_data[[outcome_name]]) < 2)) return(NULL)

  model_data <- model_data %>%
    mutate(
      dxa_mbr_z = standardize(dxa_mbr),
      age_z = standardize(age),
      weight_z = standardize(weight)
    )

  if (family_name == "gaussian") {
    fit_base <- lm(reformulate(c("age_z", "sex_male", "weight_z"), response = outcome_name), data = model_data)
    fit_plus <- lm(reformulate(c("age_z", "sex_male", "weight_z", "dxa_mbr_z"), response = outcome_name), data = model_data)
    tibble(
      group = group_name,
      outcome = outcome_name,
      metric = "R2",
      base_value = summary(fit_base)$r.squared,
      plus_value = summary(fit_plus)$r.squared,
      delta_value = summary(fit_plus)$r.squared - summary(fit_base)$r.squared
    )
  } else {
    fit_base <- glm(reformulate(c("age_z", "sex_male", "weight_z"), response = outcome_name), data = model_data, family = binomial())
    fit_plus <- glm(reformulate(c("age_z", "sex_male", "weight_z", "dxa_mbr_z"), response = outcome_name), data = model_data, family = binomial())
    auc_base <- as.numeric(pROC::auc(model_data[[outcome_name]], predict(fit_base, type = "response")))
    auc_plus <- as.numeric(pROC::auc(model_data[[outcome_name]], predict(fit_plus, type = "response")))
    tibble(
      group = group_name,
      outcome = outcome_name,
      metric = "AUC",
      base_value = auc_base,
      plus_value = auc_plus,
      delta_value = auc_plus - auc_base
    )
  }
}

bridge_path <- file.path(analysis_dir, "bridge_usable_subset.csv.gz")
if (!file.exists(bridge_path)) {
  stop("Missing bridge_usable_subset.csv.gz. Run check_external_consistency.py first.")
}

bridge <- readr::read_csv(bridge_path, show_col_types = FALSE) %>%
  mutate(
    sex = factor(ifelse(sex == 1, "Male", "Female"), levels = c("Male", "Female")),
    cycle = factor(nhanes_cycle, levels = c("NHANES_1999_2000", "NHANES_2001_2002", "NHANES_2003_2004")),
    age_group = cut(age, breaks = c(8, 19, 34, 49), include.lowest = TRUE, labels = c("8-19", "20-34", "35-49"))
  )

bridge_summary <- bridge %>%
  group_by(cycle, sex) %>%
  summarise(
    n = n(),
    age_mean = mean(age),
    bia_ffm_mean = mean(bia_ffm),
    dxa_lean_mean = mean(dxa_lean),
    corr_ffm_lean = cor(bia_ffm, dxa_lean),
    corr_fat_fat = cor(bia_fat, dxa_fat),
    .groups = "drop"
  )
readr::write_csv(bridge_summary, file.path(analysis_dir, "table_bridge_summary.csv"))

bridge_cycle_corr <- bind_rows(
  bridge %>%
    group_by(cycle) %>%
    summarise(correlation = cor(bia_ffm, dxa_lean), .groups = "drop") %>%
    mutate(metric = "FFM vs DXA lean"),
  bridge %>%
    group_by(cycle) %>%
    summarise(correlation = cor(bia_fat, dxa_fat), .groups = "drop") %>%
    mutate(metric = "Fat vs DXA fat")
) %>%
  mutate(cycle_short = factor(recode(as.character(cycle),
    NHANES_1999_2000 = "1999-2000",
    NHANES_2001_2002 = "2001-2002",
    NHANES_2003_2004 = "2003-2004"
  ), levels = c("1999-2000", "2001-2002", "2003-2004")))
readr::write_csv(bridge_cycle_corr, file.path(analysis_dir, "table_bridge_cycle_correlations.csv"))

set.seed(20260420)
bridge_plot_sample <- bridge %>%
  group_by(sex) %>%
  group_modify(~ dplyr::slice_sample(.x, n = min(3500, nrow(.x)))) %>%
  ungroup()

bridge_label_lean <- tibble(
  x = quantile(bridge$bia_ffm, 0.03, na.rm = TRUE),
  y = quantile(bridge$dxa_lean, 0.985, na.rm = TRUE),
  label = sprintf("r = %.3f", cor(bridge$bia_ffm, bridge$dxa_lean, use = "complete.obs"))
)

bridge_label_fat <- tibble(
  x = quantile(bridge$bia_fat, 0.03, na.rm = TRUE),
  y = quantile(bridge$dxa_fat, 0.985, na.rm = TRUE),
  label = sprintf("r = %.3f", cor(bridge$bia_fat, bridge$dxa_fat, use = "complete.obs"))
)

bridge_p1 <- ggplot(bridge_plot_sample, aes(bia_ffm, dxa_lean, color = sex)) +
  geom_point(alpha = 0.28, size = 1.1) +
  geom_smooth(method = "lm", se = FALSE, linewidth = 1.1) +
  geom_label(
    data = bridge_label_lean,
    aes(x = x, y = y, label = label),
    inherit.aes = FALSE,
    hjust = 0,
    vjust = 1,
    size = 10.4,
    fontface = "bold",
    label.size = 0,
    fill = alpha("white", 0.90),
    color = "black"
  ) +
  scale_color_manual(values = pick_cols(cell_palette[c(1, 2)], c("Male", "Female"))) +
  scale_x_continuous(
    breaks = pretty_breaks(n = 5),
    labels = label_number(big.mark = ","),
    expand = expansion(mult = c(0.02, 0.04))
  ) +
  scale_y_continuous(
    breaks = pretty_breaks(n = 5),
    labels = label_number(big.mark = ","),
    expand = expansion(mult = c(0.02, 0.04))
  ) +
  labs(x = "BIA fat-free mass", y = "DXA total lean mass", color = NULL) +
  theme_gsci_cell() +
  theme(legend.position = "top")

bridge_p2 <- ggplot(bridge_plot_sample, aes(bia_fat, dxa_fat, color = sex)) +
  geom_point(alpha = 0.28, size = 1.1) +
  geom_smooth(method = "lm", se = FALSE, linewidth = 1.1) +
  geom_label(
    data = bridge_label_fat,
    aes(x = x, y = y, label = label),
    inherit.aes = FALSE,
    hjust = 0,
    vjust = 1,
    size = 10.4,
    fontface = "bold",
    label.size = 0,
    fill = alpha("white", 0.90),
    color = "black"
  ) +
  scale_color_manual(values = pick_cols(cell_palette[c(1, 2)], c("Male", "Female"))) +
  scale_x_continuous(
    breaks = pretty_breaks(n = 5),
    labels = label_number(big.mark = ","),
    expand = expansion(mult = c(0.02, 0.04))
  ) +
  scale_y_continuous(
    breaks = pretty_breaks(n = 5),
    labels = label_number(big.mark = ","),
    expand = expansion(mult = c(0.02, 0.04))
  ) +
  labs(x = "BIA fat mass", y = "DXA total fat mass", color = NULL) +
  theme_gsci_cell() +
  theme(legend.position = "top")

bridge_p3 <- ggplot(filter(bridge_cycle_corr, metric == "FFM vs DXA lean"), aes(cycle_short, correlation, fill = cycle_short)) +
  geom_col(width = 0.65, color = "black") +
  scale_fill_manual(values = pick_cols(cell_palette[c(1, 3, 5)], levels(filter(bridge_cycle_corr, metric == "FFM vs DXA lean")$cycle_short)), guide = "none") +
  geom_text(aes(label = sprintf("%.3f", correlation)), vjust = -0.7, size = 8.8, fontface = "bold") +
  coord_cartesian(ylim = c(0.9, 1.0)) +
  labs(x = NULL, y = "Correlation coefficient") +
  theme_gsci_cell() +
  theme(axis.text.x = element_text(angle = 0, hjust = 0.5), legend.position = "none")

bridge_p4 <- ggplot(filter(bridge_cycle_corr, metric == "Fat vs DXA fat"), aes(cycle_short, correlation, fill = cycle_short)) +
  geom_col(width = 0.65, color = "black") +
  scale_fill_manual(values = pick_cols(cell_palette[c(1, 3, 5)], levels(filter(bridge_cycle_corr, metric == "Fat vs DXA fat")$cycle_short)), guide = "none") +
  geom_text(aes(label = sprintf("%.3f", correlation)), vjust = -0.7, size = 8.8, fontface = "bold") +
  coord_cartesian(ylim = c(0.85, 1.0)) +
  labs(x = NULL, y = "Correlation coefficient") +
  theme_gsci_cell() +
  theme(axis.text.x = element_text(angle = 0, hjust = 0.5), legend.position = "none")

bridge_fig <- ((bridge_p1 + bridge_p2) / (bridge_p3 + bridge_p4)) +
  plot_layout(guides = "collect", heights = c(1.08, 0.92)) &
  theme(legend.position = "top")
save_pub_plot(bridge_fig, "Figure_1_Bridge", width = 15.5, height = 12.5)

outcome_path <- file.path(root_dir, "data", "processed", "NHANES", "NHANES_2013_2014_outcome_bundle.csv.gz")
outcome <- readr::read_csv(outcome_path, show_col_types = FALSE) %>%
  mutate(
    age = DEMO_H__RIDAGEYR,
    sex = factor(ifelse(DEMO_H__RIAGENDR == 1, "Male", "Female"), levels = c("Male", "Female")),
    sex_male = ifelse(sex == "Male", 1, 0),
    weight = BMX_H__BMXWT,
    height = BMX_H__BMXHT,
    dxa_lean = DXX_H__DXDTOLE,
    dxa_bmc = DXX_H__DXDTOBMC,
    dxa_fat = DXX_H__DXDTOFAT,
    dxa_mbr = dxa_lean / dxa_bmc,
    osta = 0.2 * (weight - age),
    osta_risk = -osta,
    hip_frax = ifelse(DXXFRX_H__DXXPRVFX == 1, DXXFRX_H__DXXFRAX1, ifelse(DXXFRX_H__DXXPRVFX == 2, DXXFRX_H__DXXFRAX3, NA_real_)),
    major_frax = ifelse(DXXFRX_H__DXXPRVFX == 1, DXXFRX_H__DXXFRAX2, ifelse(DXXFRX_H__DXXPRVFX == 2, DXXFRX_H__DXXFRAX4, NA_real_)),
    prev_fracture = to_yes_no(DXXFRX_H__DXXPRVFX),
    vertebral_fx = ifelse(DXXVFA_H__DXXVFAST == 2, 1, ifelse(DXXVFA_H__DXXVFAST == 1, 0, NA_real_)),
    self_report_osteoporosis = to_yes_no(OSQ_H__OSQ060),
    self_report_hip_fx = to_yes_no(OSQ_H__OSQ010A),
    self_report_spine_fx = to_yes_no(OSQ_H__OSQ010C),
    direct_fx_any = ifelse(self_report_hip_fx == 1 | self_report_spine_fx == 1 | vertebral_fx == 1, 1,
                           ifelse(self_report_hip_fx == 0 & self_report_spine_fx == 0 & vertebral_fx == 0, 0, NA_real_)),
    age_group = case_when(
      age >= 40 & age <= 49 ~ "40-49",
      age >= 50 & age <= 59 ~ "50-59",
      TRUE ~ NA_character_
    )
  )

availability <- tibble(
  endpoint = c("hip_frax", "major_frax", "prev_fracture", "self_report_hip_fx", "self_report_spine_fx", "vertebral_fx", "self_report_osteoporosis"),
  n_50_59 = c(
    sum(outcome$age >= 50 & outcome$age <= 59 & !is.na(outcome$hip_frax)),
    sum(outcome$age >= 50 & outcome$age <= 59 & !is.na(outcome$major_frax)),
    sum(outcome$age >= 50 & outcome$age <= 59 & !is.na(outcome$prev_fracture)),
    sum(outcome$age >= 50 & outcome$age <= 59 & !is.na(outcome$self_report_hip_fx)),
    sum(outcome$age >= 50 & outcome$age <= 59 & !is.na(outcome$self_report_spine_fx)),
    sum(outcome$age >= 50 & outcome$age <= 59 & !is.na(outcome$vertebral_fx)),
    sum(outcome$age >= 50 & outcome$age <= 59 & !is.na(outcome$self_report_osteoporosis))
  )
)
readr::write_csv(availability, file.path(analysis_dir, "table_outcome_availability_50_59.csv"))

risk_40_59 <- outcome %>%
  filter(!is.na(age_group), !is.na(dxa_mbr)) %>%
  mutate(
    mbr16_high = ifelse(dxa_mbr >= 16, 1, 0),
    mbr16_group = factor(ifelse(dxa_mbr >= 16, ">=16", "<16"), levels = c("<16", ">=16"))
  )

mbr16_distribution <- risk_40_59 %>%
  group_by(age_group, sex) %>%
  summarise(
    n = n(),
    mean_mbr = mean(dxa_mbr, na.rm = TRUE),
    median_mbr = median(dxa_mbr, na.rm = TRUE),
    p25_mbr = quantile(dxa_mbr, 0.25, na.rm = TRUE),
    p75_mbr = quantile(dxa_mbr, 0.75, na.rm = TRUE),
    min_mbr = min(dxa_mbr, na.rm = TRUE),
    max_mbr = max(dxa_mbr, na.rm = TRUE),
    prop_ge16 = mean(mbr16_high == 1, na.rm = TRUE),
    .groups = "drop"
  )
readr::write_csv(mbr16_distribution, file.path(analysis_dir, "table_mbr16_distribution.csv"))

threshold16_summary <- risk_40_59 %>%
  group_by(age_group, mbr16_group) %>%
  summarise(
    n = n(),
    hip_frax_mean = mean(hip_frax, na.rm = TRUE),
    major_frax_mean = mean(major_frax, na.rm = TRUE),
    prev_fracture_rate = mean(prev_fracture, na.rm = TRUE),
    osteoporosis_rate = mean(self_report_osteoporosis, na.rm = TRUE),
    .groups = "drop"
  )
readr::write_csv(threshold16_summary, file.path(analysis_dir, "table_threshold16_summary.csv"))

threshold16_plot_df <- risk_40_59 %>%
  select(age_group, sex, mbr16_group, hip_frax, major_frax, prev_fracture, self_report_osteoporosis) %>%
  pivot_longer(
    cols = c(hip_frax, major_frax, prev_fracture, self_report_osteoporosis),
    names_to = "endpoint",
    values_to = "value"
  ) %>%
  group_by(age_group, mbr16_group, endpoint) %>%
  summarise(
    n = sum(!is.na(value)),
    mean_value = mean(value, na.rm = TRUE),
    se_value = sd(value, na.rm = TRUE) / sqrt(n),
    .groups = "drop"
  ) %>%
  mutate(
    endpoint = recode(
      endpoint,
      hip_frax = "Hip FRAX",
      major_frax = "Major FRAX",
      prev_fracture = "Previous fracture",
      self_report_osteoporosis = "Reported\nosteoporosis"
    )
  )
readr::write_csv(threshold16_plot_df, file.path(analysis_dir, "table_threshold16_plot_df.csv"))

threshold16_linear_specs <- tribble(
  ~subset_name, ~filter_expr, ~outcome,
  "Overall 40-59", quo(!is.na(age_group)), "hip_frax",
  "Overall 40-59", quo(!is.na(age_group)), "major_frax",
  "Age 40-49", quo(age_group == "40-49"), "hip_frax",
  "Age 40-49", quo(age_group == "40-49"), "major_frax",
  "Age 50-59", quo(age_group == "50-59"), "hip_frax",
  "Age 50-59", quo(age_group == "50-59"), "major_frax",
  "Male 50-59", quo(age_group == "50-59" & sex == "Male"), "hip_frax",
  "Male 50-59", quo(age_group == "50-59" & sex == "Male"), "major_frax",
  "Female 50-59", quo(age_group == "50-59" & sex == "Female"), "hip_frax",
  "Female 50-59", quo(age_group == "50-59" & sex == "Female"), "major_frax"
)

threshold16_linear_results <- purrr::pmap_dfr(threshold16_linear_specs, function(subset_name, filter_expr, outcome) {
  fit_linear_binary(filter(risk_40_59, !!filter_expr), outcome, subset_name)
})
readr::write_csv(threshold16_linear_results, file.path(analysis_dir, "table_threshold16_linear_models.csv"))

threshold16_logistic_specs <- tribble(
  ~subset_name, ~filter_expr, ~outcome,
  "Overall 40-59", quo(!is.na(age_group)), "prev_fracture",
  "Overall 40-59", quo(!is.na(age_group)), "self_report_osteoporosis",
  "Age 40-49", quo(age_group == "40-49"), "prev_fracture",
  "Age 40-49", quo(age_group == "40-49"), "self_report_osteoporosis",
  "Age 50-59", quo(age_group == "50-59"), "prev_fracture",
  "Age 50-59", quo(age_group == "50-59"), "self_report_osteoporosis",
  "Male 50-59", quo(age_group == "50-59" & sex == "Male"), "prev_fracture",
  "Female 50-59", quo(age_group == "50-59" & sex == "Female"), "prev_fracture",
  "Female 50-59", quo(age_group == "50-59" & sex == "Female"), "self_report_osteoporosis"
)

threshold16_logistic_results <- purrr::pmap_dfr(threshold16_logistic_specs, function(subset_name, filter_expr, outcome) {
  fit_logistic_binary(filter(risk_40_59, !!filter_expr), outcome, subset_name)
})
readr::write_csv(threshold16_logistic_results, file.path(analysis_dir, "table_threshold16_logistic_models.csv"))

fig_mbr16_distribution <- ggplot(risk_40_59, aes(dxa_mbr, color = age_group, fill = age_group)) +
  geom_density(alpha = 0.10, linewidth = 1.2, adjust = 1.05) +
  geom_vline(xintercept = 16, linetype = "dashed", linewidth = 0.9, color = "black") +
  annotate("text", x = 16.15, y = Inf, label = "MBR = 16", vjust = 1.4, hjust = 0, size = 6.8, fontface = "bold") +
  facet_wrap(~sex, nrow = 1) +
  scale_color_manual(values = pick_cols(cell_palette[c(1, 2)], c("40-49", "50-59"))) +
  scale_fill_manual(values = pick_cols(cell_palette[c(1, 2)], c("40-49", "50-59"))) +
  scale_x_continuous(
    breaks = pretty_breaks(n = 6),
    labels = label_number(accuracy = 0.1),
    expand = expansion(mult = c(0.02, 0.04))
  ) +
  scale_y_continuous(
    breaks = pretty_breaks(n = 4),
    expand = expansion(mult = c(0.02, 0.10))
  ) +
  labs(x = "DXA-derived MBR", y = "Density", color = NULL, fill = NULL) +
  theme_gsci_cell() +
  guides(fill = "none", color = guide_legend(nrow = 1, byrow = TRUE)) +
  theme(legend.position = "top")

fig_mbr16_threshold <- ggplot(threshold16_plot_df, aes(mbr16_group, mean_value, color = age_group, group = age_group)) +
  geom_line(linewidth = 1.1, position = position_dodge(width = 0.16)) +
  geom_point(size = 2.8, position = position_dodge(width = 0.16)) +
  geom_errorbar(
    aes(ymin = mean_value - 1.96 * se_value, ymax = mean_value + 1.96 * se_value),
    width = 0.08,
    linewidth = 0.8,
    position = position_dodge(width = 0.16)
  ) +
  facet_wrap(~endpoint, nrow = 1, scales = "free_y") +
  scale_color_manual(values = pick_cols(cell_palette[c(1, 2)], c("40-49", "50-59"))) +
  scale_y_continuous(
    breaks = pretty_breaks(n = 4),
    expand = expansion(mult = c(0.04, 0.10))
  ) +
  labs(x = "Descriptive split at MBR = 16", y = "Mean value or proportion", color = NULL) +
  theme_gsci_cell() +
  guides(color = guide_legend(nrow = 1, byrow = TRUE)) +
  theme(legend.position = "top")

fig_threshold_bridge <- fig_mbr16_distribution / fig_mbr16_threshold
save_pub_plot(fig_threshold_bridge, "Figure_2_MBR16_Bridge", width = 15.0, height = 11.2)

baseline_50_59 <- risk_40_59 %>%
  filter(age_group == "50-59") %>%
  mutate(mbr_quartile = ntile(dxa_mbr, 4)) %>%
  group_by(mbr_quartile) %>%
  summarise(
    n = n(),
    age_mean = mean(age, na.rm = TRUE),
    male_rate = mean(sex == "Male", na.rm = TRUE),
    weight_mean = mean(weight, na.rm = TRUE),
    lean_mean = mean(dxa_lean, na.rm = TRUE),
    bmc_mean = mean(dxa_bmc, na.rm = TRUE),
    fat_mean = mean(dxa_fat, na.rm = TRUE),
    hip_frax_mean = mean(hip_frax, na.rm = TRUE),
    major_frax_mean = mean(major_frax, na.rm = TRUE),
    prev_fracture_rate = mean(prev_fracture, na.rm = TRUE),
    osteoporosis_rate = mean(self_report_osteoporosis, na.rm = TRUE),
    .groups = "drop"
  )
readr::write_csv(baseline_50_59, file.path(analysis_dir, "table_baseline_50_59_by_mbr_quartile.csv"))

structure_df <- risk_40_59 %>%
  filter(age_group == "50-59") %>%
  group_by(sex) %>%
  mutate(mbr_quartile = factor(ntile(dxa_mbr, 4), levels = 1:4, labels = c("Q1", "Q2", "Q3", "Q4"))) %>%
  group_by(sex, mbr_quartile) %>%
  summarise(
    lean_mean = mean(dxa_lean, na.rm = TRUE),
    bmc_mean = mean(dxa_bmc, na.rm = TRUE),
    fat_mean = mean(dxa_fat, na.rm = TRUE),
    weight_mean = mean(weight, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    lean_z = ave(lean_mean, sex, FUN = standardize),
    bmc_z = ave(bmc_mean, sex, FUN = standardize),
    fat_z = ave(fat_mean, sex, FUN = standardize),
    weight_z = ave(weight_mean, sex, FUN = standardize)
  ) %>%
  select(sex, mbr_quartile, lean_z, bmc_z, fat_z, weight_z) %>%
  pivot_longer(cols = ends_with("_z"), names_to = "component", values_to = "z_mean") %>%
  mutate(component = recode(component, lean_z = "Lean mass", bmc_z = "Bone mineral content", fat_z = "Fat mass", weight_z = "Body weight"))
readr::write_csv(structure_df, file.path(analysis_dir, "table_structure_50_59_sex_specific.csv"))

fig_structure <- ggplot(structure_df, aes(mbr_quartile, z_mean, color = component, group = component)) +
  geom_hline(yintercept = 0, linewidth = 0.6, color = "grey70") +
  geom_line(linewidth = 1.2) +
  geom_point(size = 2.8) +
  facet_wrap(~sex, nrow = 1) +
  scale_color_manual(values = pick_cols(cell_palette[c(1, 4, 2, 5)], c("Lean mass", "Bone mineral content", "Fat mass", "Body weight"))) +
  scale_y_continuous(
    breaks = pretty_breaks(n = 5),
    labels = label_number(accuracy = 0.1),
    expand = expansion(mult = c(0.04, 0.08))
  ) +
  labs(x = "DXA-derived MBR quartile", y = "Standardized mean\n(within sex)", color = NULL) +
  theme_gsci_cell() +
  guides(color = guide_legend(nrow = 2, byrow = TRUE)) +
  theme(legend.position = "top")
save_pub_plot(fig_structure, "Figure_2_Structure_50_59", width = 14.8, height = 8.6)

frax_quartile <- risk_40_59 %>%
  filter(!is.na(hip_frax), !is.na(major_frax)) %>%
  group_by(age_group) %>%
  mutate(mbr_quartile = factor(ntile(dxa_mbr, 4), levels = 1:4, labels = c("Q1", "Q2", "Q3", "Q4"))) %>%
  group_by(age_group, mbr_quartile) %>%
  summarise(
    hip_frax_mean = mean(hip_frax, na.rm = TRUE),
    hip_frax_se = sd(hip_frax, na.rm = TRUE) / sqrt(n()),
    major_frax_mean = mean(major_frax, na.rm = TRUE),
    major_frax_se = sd(major_frax, na.rm = TRUE) / sqrt(n()),
    n = n(),
    .groups = "drop"
  ) %>%
  pivot_longer(cols = c(hip_frax_mean, major_frax_mean, hip_frax_se, major_frax_se), names_to = c("endpoint", ".value"), names_pattern = "(hip_frax|major_frax)_(mean|se)")

frax_quartile <- frax_quartile %>%
  mutate(endpoint = recode(endpoint, hip_frax = "Hip FRAX", major_frax = "Major FRAX"))
readr::write_csv(frax_quartile, file.path(analysis_dir, "table_frax_by_agegroup_quartile.csv"))

fig_frax <- ggplot(frax_quartile, aes(mbr_quartile, mean, color = age_group, group = age_group)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 2.8) +
  geom_errorbar(aes(ymin = mean - 1.96 * se, ymax = mean + 1.96 * se), width = 0.08, linewidth = 0.8) +
  facet_wrap(~endpoint, nrow = 1, scales = "free_y") +
  scale_color_manual(values = pick_cols(cell_palette[c(1, 2)], c("40-49", "50-59"))) +
  scale_y_continuous(
    breaks = pretty_breaks(n = 4),
    labels = label_number(accuracy = 0.1),
    expand = expansion(mult = c(0.05, 0.10))
  ) +
  labs(x = "DXA-derived MBR quartile", y = "Mean FRAX score (%)", color = NULL) +
  theme_gsci_cell() +
  guides(color = guide_legend(nrow = 1, byrow = TRUE)) +
  theme(legend.position = "top")
save_pub_plot(fig_frax, "Figure_3_FRAX_By_Age", width = 13.8, height = 8.2)

linear_specs <- tribble(
  ~subset_name, ~filter_expr, ~outcome,
  "Overall 40-59", quo(!is.na(age_group)), "hip_frax",
  "Overall 40-59", quo(!is.na(age_group)), "major_frax",
  "Age 40-49", quo(age_group == "40-49"), "hip_frax",
  "Age 40-49", quo(age_group == "40-49"), "major_frax",
  "Age 50-59", quo(age_group == "50-59"), "hip_frax",
  "Age 50-59", quo(age_group == "50-59"), "major_frax",
  "Male 50-59", quo(age_group == "50-59" & sex == "Male"), "hip_frax",
  "Male 50-59", quo(age_group == "50-59" & sex == "Male"), "major_frax",
  "Female 50-59", quo(age_group == "50-59" & sex == "Female"), "hip_frax",
  "Female 50-59", quo(age_group == "50-59" & sex == "Female"), "major_frax"
)

linear_results <- purrr::pmap_dfr(linear_specs, function(subset_name, filter_expr, outcome) {
  fit_linear(filter(risk_40_59, !!filter_expr), outcome, subset_name)
})
readr::write_csv(linear_results, file.path(analysis_dir, "table_linear_models.csv"))

logistic_specs <- tribble(
  ~subset_name, ~filter_expr, ~outcome,
  "Overall 40-59", quo(!is.na(age_group)), "prev_fracture",
  "Overall 40-59", quo(!is.na(age_group)), "direct_fx_any",
  "Overall 40-59", quo(!is.na(age_group)), "self_report_osteoporosis",
  "Age 40-49", quo(age_group == "40-49"), "prev_fracture",
  "Age 40-49", quo(age_group == "40-49"), "direct_fx_any",
  "Age 40-49", quo(age_group == "40-49"), "self_report_osteoporosis",
  "Age 50-59", quo(age_group == "50-59"), "prev_fracture",
  "Age 50-59", quo(age_group == "50-59"), "direct_fx_any",
  "Age 50-59", quo(age_group == "50-59"), "self_report_osteoporosis",
  "Male 50-59", quo(age_group == "50-59" & sex == "Male"), "prev_fracture",
  "Male 50-59", quo(age_group == "50-59" & sex == "Male"), "direct_fx_any",
  "Female 50-59", quo(age_group == "50-59" & sex == "Female"), "prev_fracture",
  "Female 50-59", quo(age_group == "50-59" & sex == "Female"), "direct_fx_any",
  "Female 50-59", quo(age_group == "50-59" & sex == "Female"), "self_report_osteoporosis"
)

logistic_results <- purrr::pmap_dfr(logistic_specs, function(subset_name, filter_expr, outcome) {
  fit_logistic(filter(risk_40_59, !!filter_expr), outcome, subset_name)
})
readr::write_csv(logistic_results, file.path(analysis_dir, "table_logistic_models.csv"))

increment_specs <- tribble(
  ~subset_name, ~filter_expr, ~outcome, ~family_name,
  "Overall 40-59", quo(!is.na(age_group)), "hip_frax", "gaussian",
  "Overall 40-59", quo(!is.na(age_group)), "major_frax", "gaussian",
  "Overall 40-59", quo(!is.na(age_group)), "prev_fracture", "binomial",
  "Overall 40-59", quo(!is.na(age_group)), "self_report_osteoporosis", "binomial",
  "Age 50-59", quo(age_group == "50-59"), "hip_frax", "gaussian",
  "Age 50-59", quo(age_group == "50-59"), "major_frax", "gaussian",
  "Age 50-59", quo(age_group == "50-59"), "prev_fracture", "binomial",
  "Age 50-59", quo(age_group == "50-59"), "self_report_osteoporosis", "binomial"
)

increment_results <- purrr::pmap_dfr(increment_specs, function(subset_name, filter_expr, outcome, family_name) {
  fit_incremental(filter(risk_40_59, !!filter_expr), outcome, family_name, subset_name)
})
readr::write_csv(increment_results, file.path(analysis_dir, "table_incremental_value.csv"))

fig_linear_forest <- linear_results %>%
  mutate(
    outcome = recode(outcome, hip_frax = "Hip FRAX", major_frax = "Major FRAX"),
    group = factor(group, levels = c("Overall 40-59", "Age 40-49", "Age 50-59", "Male 50-59", "Female 50-59"))
  ) %>%
  ggplot(aes(estimate, fct_rev(group), color = outcome)) +
  geom_vline(xintercept = 0, linewidth = 0.9, color = "grey65") +
  geom_errorbarh(aes(xmin = conf_low, xmax = conf_high), height = 0.22, linewidth = 1.2, position = position_dodge(width = 0.55)) +
  geom_point(size = 3.6, position = position_dodge(width = 0.55)) +
  scale_x_continuous(
    breaks = seq(0, 2.5, by = 0.5),
    labels = label_number(accuracy = 0.1),
    expand = expansion(mult = c(0.03, 0.06))
  ) +
  scale_color_manual(values = pick_cols(cell_palette[c(1, 2)], c("Hip FRAX", "Major FRAX"))) +
  labs(x = "Adjusted beta per 1 SD increase in DXA-derived MBR", y = NULL, color = NULL) +
  theme_gsci_cell() +
  guides(color = guide_legend(nrow = 1, byrow = TRUE)) +
  theme(legend.position = "top")

fig_logistic_forest <- logistic_results %>%
  mutate(
    outcome = recode(
      outcome,
      prev_fracture = "Previous fracture",
      direct_fx_any = "Direct fracture indicator",
      self_report_osteoporosis = "Self-reported osteoporosis"
    ),
    group = factor(group, levels = c("Overall 40-59", "Age 40-49", "Age 50-59", "Male 50-59", "Female 50-59"))
  ) %>%
  ggplot(aes(estimate, fct_rev(group), color = outcome)) +
  geom_vline(xintercept = 1, linewidth = 0.9, color = "grey65") +
  geom_errorbarh(aes(xmin = conf_low, xmax = conf_high), height = 0.22, linewidth = 1.2, position = position_dodge(width = 0.62)) +
  geom_point(size = 3.6, position = position_dodge(width = 0.62)) +
  scale_x_log10(
    breaks = c(0.5, 1, 2, 4, 6),
    labels = label_number(accuracy = 0.1)
  ) +
  scale_color_manual(values = pick_cols(cell_palette[c(1, 2, 4)], c("Previous fracture", "Direct fracture indicator", "Self-reported osteoporosis"))) +
  labs(x = "Adjusted odds ratio per 1 SD increase in DXA-derived MBR", y = NULL, color = NULL) +
  theme_gsci_cell() +
  guides(color = guide_legend(nrow = 1, byrow = TRUE)) +
  theme(
    legend.position = "top",
    legend.text = element_text(size = 21),
    legend.key.width = grid::unit(1.42, "cm"),
    legend.spacing.x = grid::unit(0.24, "cm")
  )

forest_fig <- fig_linear_forest / fig_logistic_forest
save_pub_plot(forest_fig, "Figure_4_Adjusted_Forest", width = 14.8, height = 11.8)

auc_specs <- tribble(
  ~subset_name, ~filter_expr,
  "Overall 40-59", quo(!is.na(age_group)),
  "Age 50-59", quo(age_group == "50-59"),
  "Female 50-59", quo(age_group == "50-59" & sex == "Female")
)

auc_results <- purrr::pmap_dfr(auc_specs, function(subset_name, filter_expr) {
  df0 <- filter(risk_40_59, !!filter_expr)
  bind_rows(
    lapply(c("prev_fracture", "self_report_osteoporosis", "direct_fx_any"), function(outcome_name) {
      df <- df0 %>% select(dxa_mbr, osta_risk, all_of(outcome_name)) %>% tidyr::drop_na()
      if (nrow(df) < 80 || dplyr::n_distinct(df[[outcome_name]]) < 2) return(NULL)
      roc_mbr <- pROC::roc(df[[outcome_name]], df$dxa_mbr, quiet = TRUE)
      roc_osta <- pROC::roc(df[[outcome_name]], df$osta_risk, quiet = TRUE)
      ci_mbr <- as.numeric(pROC::ci.auc(roc_mbr))
      ci_osta <- as.numeric(pROC::ci.auc(roc_osta))
      compare_p <- if (identical(roc_mbr$direction, roc_osta$direction)) {
        tryCatch(
          pROC::roc.test(roc_mbr, roc_osta, paired = TRUE, method = "delong")$p.value,
          error = function(e) NA_real_
        )
      } else {
        NA_real_
      }
      tibble(
        group = subset_name,
        outcome = outcome_name,
        metric = c("DXA-derived MBR", "OSTA"),
        n = nrow(df),
        cases = sum(df[[outcome_name]] == 1),
        auc = c(
          as.numeric(pROC::auc(roc_mbr)),
          as.numeric(pROC::auc(roc_osta))
        ),
        ci_low = c(ci_mbr[1], ci_osta[1]),
        ci_high = c(ci_mbr[3], ci_osta[3]),
        compare_p = compare_p
      )
    })
  )
})
readr::write_csv(auc_results, file.path(analysis_dir, "table_auc_mbr_vs_osta.csv"))

roc_plot_specs <- tribble(
  ~subset_name, ~filter_expr,
  "Overall 40-59", quo(!is.na(age_group)),
  "Age 50-59", quo(age_group == "50-59"),
  "Female 50-59", quo(age_group == "50-59" & sex == "Female")
)

roc_curve_results <- purrr::pmap_dfr(roc_plot_specs, function(subset_name, filter_expr) {
  df0 <- filter(risk_40_59, !!filter_expr)
  bind_rows(
    lapply(c("prev_fracture", "self_report_osteoporosis", "direct_fx_any"), function(outcome_name) {
      df <- df0 %>% select(dxa_mbr, osta_risk, all_of(outcome_name)) %>% tidyr::drop_na()
      if (nrow(df) < 80 || dplyr::n_distinct(df[[outcome_name]]) < 2) return(NULL)

      roc_mbr <- pROC::roc(df[[outcome_name]], df$dxa_mbr, quiet = TRUE)
      roc_osta <- pROC::roc(df[[outcome_name]], df$osta_risk, quiet = TRUE)

      bind_rows(
        tibble(
          group = subset_name,
          outcome = outcome_name,
          metric = "DXA-derived MBR",
          specificity = roc_mbr$specificities,
          sensitivity = roc_mbr$sensitivities
        ),
        tibble(
          group = subset_name,
          outcome = outcome_name,
          metric = "OSTA",
          specificity = roc_osta$specificities,
          sensitivity = roc_osta$sensitivities
        )
      )
    })
  )
}) %>%
  mutate(false_positive_rate = 1 - specificity)
readr::write_csv(roc_curve_results, file.path(analysis_dir, "table_roc_curve_points.csv"))

roc_panel_labels <- auc_results %>%
  mutate(
    outcome = recode(
      outcome,
      prev_fracture = "Previous fracture",
      self_report_osteoporosis = "Self-reported osteoporosis",
      direct_fx_any = "Direct fracture indicator"
    ),
    group = factor(
      group,
      levels = c("Overall 40-59", "Age 50-59", "Female 50-59"),
      labels = c("Overall 40-59", "Age 50-59", "Female 50-59")
    ),
    metric_short = ifelse(metric == "DXA-derived MBR", "MBR", "OSTA")
  ) %>%
  group_by(group, outcome, n, cases) %>%
  summarise(
    label = paste0(
      "n = ", first(n), "\n",
      "events = ", first(cases), "\n",
      paste0(metric_short, " AUC = ", sprintf("%.3f", auc), collapse = "\n")
    ),
    .groups = "drop"
  ) %>%
  mutate(
    x = 0.36,
    y = 0.06
  )

fig_auc <- roc_curve_results %>%
  mutate(
    outcome = recode(
      outcome,
      prev_fracture = "Previous fracture",
      self_report_osteoporosis = "Self-reported osteoporosis",
      direct_fx_any = "Direct fracture indicator"
    ),
    group = factor(
      group,
      levels = c("Overall 40-59", "Age 50-59", "Female 50-59"),
      labels = c("Overall 40-59", "Age 50-59", "Female 50-59")
    )
  ) %>%
  ggplot(aes(false_positive_rate, sensitivity, color = metric)) +
  geom_abline(intercept = 0, slope = 1, linetype = "dashed", linewidth = 0.7, color = "grey65") +
  geom_path(linewidth = 1.5, alpha = 0.95) +
  geom_label(
    data = roc_panel_labels,
    aes(x = x, y = y, label = label),
    inherit.aes = FALSE,
    hjust = 0,
    vjust = 0,
    size = 8.8,
    label.size = 0,
    fill = alpha("white", 0.90),
    lineheight = 0.95
  ) +
  facet_grid(outcome ~ group) +
  scale_color_manual(values = pick_cols(cell_palette[c(1, 2)], c("DXA-derived MBR", "OSTA"))) +
  scale_x_continuous(
    breaks = c(0, 0.5, 1.0),
    labels = label_number(accuracy = 0.1),
    expand = expansion(mult = c(0.01, 0.01))
  ) +
  scale_y_continuous(
    breaks = seq(0, 1, by = 0.25),
    labels = label_number(accuracy = 0.01),
    expand = expansion(mult = c(0.01, 0.01))
  ) +
  coord_equal(xlim = c(0, 1), ylim = c(0, 1), clip = "off") +
  labs(x = "1 - Specificity", y = "Sensitivity", color = NULL) +
  theme_gsci_cell() +
  guides(color = guide_legend(nrow = 1, byrow = TRUE)) +
  theme(
    legend.position = "top",
    strip.text.x = element_text(size = 26, face = "bold", margin = margin(8, 0, 8, 0)),
    strip.text.y = element_text(size = 26, face = "bold", margin = margin(0, 8, 0, 8)),
    panel.spacing.x = grid::unit(2.7, "lines"),
    panel.spacing.y = grid::unit(1.5, "lines"),
    legend.box.margin = margin(0, 0, 8, 0),
    plot.margin = margin(6, 0, 6, 0)
  )
save_pub_plot(fig_auc, "Figure_5_AUC_Comparison", width = 19.0, height = 17.6)

supp_table_s1 <- baseline_50_59 %>%
  mutate(
    `MBR quartile` = paste0("Q", mbr_quartile),
    `N` = n,
    `Age, mean` = round(age_mean, 2),
    `Male, %` = round(male_rate * 100, 1),
    `Weight (kg), mean` = round(weight_mean, 2),
    `DXA lean mass, mean` = round(lean_mean, 2),
    `DXA BMC, mean` = round(bmc_mean, 2),
    `DXA fat mass, mean` = round(fat_mean, 2),
    `Hip FRAX, mean` = round(hip_frax_mean, 2),
    `Major FRAX, mean` = round(major_frax_mean, 2),
    `Previous fracture, %` = round(prev_fracture_rate * 100, 1),
    `Self-reported osteoporosis, %` = round(osteoporosis_rate * 100, 1)
  ) %>%
  select(
    `MBR quartile`, `N`, `Age, mean`, `Male, %`, `Weight (kg), mean`,
    `DXA lean mass, mean`, `DXA BMC, mean`, `DXA fat mass, mean`,
    `Hip FRAX, mean`, `Major FRAX, mean`, `Previous fracture, %`,
    `Self-reported osteoporosis, %`
  )
readr::write_csv(supp_table_s1, file.path(analysis_dir, "Supplementary_Table_S1_Baseline_50_59_by_MBR_Quartile.csv"))

supp_table_s2 <- bind_rows(
  linear_results %>%
    mutate(model_type = "Linear", effect_type = "Beta"),
  logistic_results %>%
    mutate(model_type = "Logistic", effect_type = "OR")
) %>%
  mutate(
    subgroup = group,
    outcome = recode(
      outcome,
      hip_frax = "Hip FRAX",
      major_frax = "Major FRAX",
      prev_fracture = "Previous fracture",
      direct_fx_any = "Direct fracture indicator",
      self_report_osteoporosis = "Self-reported osteoporosis"
    ),
    `N` = n,
    `Events` = events,
    `Effect (95% CI)` = sprintf("%.3f (%.3f, %.3f)", estimate, conf_low, conf_high),
    `P value` = format.pval(p_value, digits = 3, eps = 0.001)
  ) %>%
  select(
    `Model type` = model_type,
    Subgroup = subgroup,
    Outcome = outcome,
    `Effect type` = effect_type,
    `N`,
    `Events`,
    `Effect (95% CI)`,
    `P value`
  )
readr::write_csv(supp_table_s2, file.path(analysis_dir, "Supplementary_Table_S2_Adjusted_Associations.csv"))

supp_table_s3 <- auc_results %>%
  mutate(
    Outcome = recode(
      outcome,
      prev_fracture = "Previous fracture",
      self_report_osteoporosis = "Self-reported osteoporosis",
      direct_fx_any = "Direct fracture indicator"
    ),
    Subgroup = group,
    metric = ifelse(metric == "DXA-derived MBR", "MBR", "OSTA"),
    auc_ci = sprintf("%.3f (%.3f, %.3f)", auc, ci_low, ci_high)
  ) %>%
  select(Subgroup, Outcome, metric, n, cases, auc_ci, compare_p) %>%
  tidyr::pivot_wider(
    names_from = metric,
    values_from = auc_ci
  ) %>%
  group_by(Subgroup, Outcome) %>%
  summarise(
    `N` = first(n),
    `Cases` = first(cases),
    `MBR AUC (95% CI)` = first(MBR),
    `OSTA AUC (95% CI)` = first(OSTA),
    `MBR vs OSTA P` = format.pval(first(compare_p), digits = 3, eps = 0.001),
    .groups = "drop"
  )
readr::write_csv(supp_table_s3, file.path(analysis_dir, "Supplementary_Table_S3_AUC_Comparison.csv"))

supp_table_s4 <- increment_results %>%
  mutate(
    Outcome = recode(
      outcome,
      hip_frax = "Hip FRAX",
      major_frax = "Major FRAX",
      prev_fracture = "Previous fracture",
      self_report_osteoporosis = "Self-reported osteoporosis"
    ),
    Subgroup = group,
    Metric = metric,
    `Base model` = round(base_value, 3),
    `Base + MBR` = round(plus_value, 3),
    `Increment` = round(delta_value, 3)
  ) %>%
  select(Subgroup, Outcome, Metric, `Base model`, `Base + MBR`, `Increment`)
readr::write_csv(supp_table_s4, file.path(analysis_dir, "Supplementary_Table_S4_Incremental_Value.csv"))

supp_table_s5 <- availability %>%
  mutate(
    Endpoint = recode(
      endpoint,
      hip_frax = "Hip FRAX",
      major_frax = "Major FRAX",
      prev_fracture = "Previous fracture",
      self_report_hip_fx = "Self-reported hip fracture",
      self_report_spine_fx = "Self-reported spine fracture",
      vertebral_fx = "Vertebral fracture on VFA",
      self_report_osteoporosis = "Self-reported osteoporosis"
    ),
    `Available N (age 50-59)` = n_50_59
  ) %>%
  select(Endpoint, `Available N (age 50-59)`)
readr::write_csv(supp_table_s5, file.path(analysis_dir, "Supplementary_Table_S5_Outcome_Availability.csv"))

summary_lines <- c(
  paste0("Bridge complete sample: n = ", nrow(bridge), "; age range ", min(bridge$age), "-", max(bridge$age), "."),
  paste0("BIA FFM vs DXA lean correlation: ", round(cor(bridge$bia_ffm, bridge$dxa_lean), 3), "."),
  paste0("BIA fat vs DXA fat correlation: ", round(cor(bridge$bia_fat, bridge$dxa_fat), 3), "."),
  paste0("Risk consistency sample with DXA-derived MBR and age 40-59: n = ", nrow(risk_40_59), "."),
  paste0("Age 50-59 sample with hip FRAX available: n = ", sum(risk_40_59$age_group == "50-59" & !is.na(risk_40_59$hip_frax)), "."),
  paste0("Proportion with DXA-derived MBR >= 16 in age 40-59: ", round(mean(risk_40_59$mbr16_high == 1) * 100, 1), "%.")
)
writeLines(summary_lines, file.path(analysis_dir, "analysis_summary.txt"))

