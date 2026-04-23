library(dplyr)
library(forcats)
library(ggplot2)
library(ggsci)
library(patchwork)
library(readr)
library(scales)
library(tidyr)
library(broom)

root_dir <- normalizePath(".", winslash = "/", mustWork = TRUE)
analysis_dir <- file.path(root_dir, "outputs", "knhanes")
figure_dir <- file.path(analysis_dir, "figures")
dir.create(analysis_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(figure_dir, showWarnings = FALSE, recursive = TRUE)

cell_palette <- pal_npg("nrc")(10)
names(cell_palette) <- paste0("c", seq_along(cell_palette))
pick_cols <- function(values, labels) {
  stats::setNames(unname(values), labels)
}

theme_gsci_cell <- function() {
  theme_bw(base_size = 20) +
    theme(
      panel.grid = element_blank(),
      panel.border = element_rect(color = "black", linewidth = 0.85),
      strip.background = element_rect(fill = "white", color = "black", linewidth = 0.85),
      strip.text = element_text(size = 24, face = "bold"),
      axis.title = element_text(size = 30, face = "bold"),
      axis.text = element_text(size = 24, color = "black"),
      legend.title = element_text(size = 28, face = "bold"),
      legend.text = element_text(size = 26),
      legend.key.height = grid::unit(0.9, "cm"),
      legend.key.width = grid::unit(1.7, "cm"),
      legend.position = "top",
      legend.direction = "horizontal",
      legend.box = "horizontal",
      legend.justification = "center",
      legend.margin = margin(0, 0, 0, 0),
      legend.box.margin = margin(0, 0, 4, 0),
      legend.spacing.x = grid::unit(0.35, "cm"),
      panel.spacing = grid::unit(1.15, "lines"),
      plot.title = element_blank(),
      plot.subtitle = element_blank(),
      plot.caption = element_blank(),
      plot.tag = element_blank(),
      plot.margin = margin(12, 12, 10, 12)
    )
}

save_pub_plot <- function(plot_obj, stem, width, height) {
  ggsave(file.path(figure_dir, paste0(stem, ".png")), plot_obj, width = width, height = height, dpi = 400, bg = "white")
  ggsave(file.path(figure_dir, paste0(stem, ".pdf")), plot_obj, width = width, height = height, device = cairo_pdf, bg = "white")
}

standardize <- function(x) {
  (x - mean(x, na.rm = TRUE)) / stats::sd(x, na.rm = TRUE)
}

clean_numeric <- function(x) suppressWarnings(as.numeric(x))

fit_logistic <- function(data, outcome_name, group_name, include_sex = TRUE) {
  vars <- c("age", "he_wt", "survey_year", "dxa_mbr", outcome_name)
  if (include_sex) vars <- c(vars, "sex_male")

  model_data <- data %>%
    select(all_of(vars)) %>%
    drop_na()

  if (nrow(model_data) < 120 || dplyr::n_distinct(model_data[[outcome_name]]) < 2) return(NULL)

  model_data <- model_data %>%
    mutate(
      dxa_mbr_z = standardize(dxa_mbr),
      age_z = standardize(age),
      he_wt_z = standardize(he_wt),
      survey_year = factor(survey_year)
    )

  rhs <- c("dxa_mbr_z", "age_z", "he_wt_z", "survey_year")
  if (include_sex) rhs <- c(rhs, "sex_male")

  fit <- glm(reformulate(rhs, response = outcome_name), data = model_data, family = binomial())
  coef_row <- summary(fit)$coefficients["dxa_mbr_z", ]
  est <- unname(coef_row["Estimate"])
  se <- unname(coef_row["Std. Error"])

  tibble(
    group = group_name,
    outcome = outcome_name,
    n = nrow(model_data),
    events = sum(model_data[[outcome_name]] == 1, na.rm = TRUE),
    estimate = exp(est),
    conf_low = exp(est - 1.96 * se),
    conf_high = exp(est + 1.96 * se),
    p_value = unname(coef_row["Pr(>|z|)"])
  )
}

clean_path <- file.path(root_dir, "data", "processed", "KNHANES", "KNHANES_2008_2011_ALL_DXA_merged.rds")
if (!file.exists(clean_path)) stop("Missing KNHANES merged file.")

dat <- readRDS(clean_path) %>%
  mutate(
    survey_year = clean_numeric(survey_year),
    sex = clean_numeric(sex),
    age = clean_numeric(age),
    he_wt = clean_numeric(he_wt),
    he_ht = clean_numeric(he_ht),
    he_bmi = clean_numeric(he_bmi),
    dw_wbt_ln = clean_numeric(dw_wbt_ln),
    dw_wbt_bmc = clean_numeric(dw_wbt_bmc),
    dw_wbt_bmd = clean_numeric(dw_wbt_bmd),
    dw_wbt_ft = clean_numeric(dw_wbt_ft),
    dw_wbt_pft = clean_numeric(dw_wbt_pft),
    dw_sbt_ln = clean_numeric(dw_sbt_ln),
    dw_sbt_bmc = clean_numeric(dw_sbt_bmc),
    dw_trk_ln = clean_numeric(dw_trk_ln),
    dw_trk_ft = clean_numeric(dw_trk_ft),
    dx_ost = clean_numeric(dx_ost),
    dx_ost_tf = clean_numeric(dx_ost_tf),
    dx_ost_fn = clean_numeric(dx_ost_fn),
    dx_ost_ls = clean_numeric(dx_ost_ls)
  ) %>%
  mutate(
    sex_label = factor(ifelse(sex == 1, "Male", ifelse(sex == 2, "Female", NA_character_)), levels = c("Male", "Female")),
    sex_male = ifelse(sex == 1, 1, ifelse(sex == 2, 0, NA_real_)),
    dxa_mbr = dw_wbt_ln / dw_wbt_bmc,
    osteoporosis_any = ifelse(dx_ost == 3, 1, ifelse(dx_ost %in% c(1, 2), 0, NA_real_)),
    low_bone_mass = ifelse(dx_ost %in% c(2, 3), 1, ifelse(dx_ost == 1, 0, NA_real_)),
    osteoporosis_tf = ifelse(dx_ost_tf == 3, 1, ifelse(dx_ost_tf %in% c(1, 2), 0, NA_real_)),
    osteoporosis_fn = ifelse(dx_ost_fn == 3, 1, ifelse(dx_ost_fn %in% c(1, 2), 0, NA_real_)),
    osteoporosis_ls = ifelse(dx_ost_ls == 3, 1, ifelse(dx_ost_ls %in% c(1, 2), 0, NA_real_))
  )

analysis_50 <- dat %>%
  filter(
    !is.na(age), age >= 50,
    !is.na(sex_label),
    !is.na(he_wt),
    !is.na(dxa_mbr), is.finite(dxa_mbr),
    !is.na(dw_wbt_ln), !is.na(dw_wbt_bmc), !is.na(dw_wbt_bmd), !is.na(dw_wbt_ft)
  ) %>%
  group_by(sex_label) %>%
  mutate(
    dxa_mbr_quartile = ntile(dxa_mbr, 4),
    dxa_mbr_quartile = factor(paste0("Q", dxa_mbr_quartile), levels = c("Q1", "Q2", "Q3", "Q4"))
  ) %>%
  ungroup()

female_50 <- analysis_50 %>% filter(sex_label == "Female")
male_50 <- analysis_50 %>% filter(sex_label == "Male")

dist_summary <- analysis_50 %>%
  group_by(sex_label) %>%
  summarise(
    n = n(),
    median_mbr = median(dxa_mbr, na.rm = TRUE),
    q1 = quantile(dxa_mbr, 0.25, na.rm = TRUE),
    q3 = quantile(dxa_mbr, 0.75, na.rm = TRUE),
    .groups = "drop"
  )
write_csv(dist_summary, file.path(analysis_dir, "KNHANES_Table_S1_MBR_Distribution_Age50plus.csv"))

structure_summary <- analysis_50 %>%
  group_by(sex_label) %>%
  mutate(
    lean_z = standardize(dw_wbt_ln),
    bmc_z = standardize(dw_wbt_bmc),
    bmd_z = standardize(dw_wbt_bmd),
    fat_z = standardize(dw_wbt_ft),
    weight_z = standardize(he_wt)
  ) %>%
  ungroup() %>%
  group_by(sex_label, dxa_mbr_quartile) %>%
  summarise(
    lean_z = mean(lean_z, na.rm = TRUE),
    bmc_z = mean(bmc_z, na.rm = TRUE),
    bmd_z = mean(bmd_z, na.rm = TRUE),
    fat_z = mean(fat_z, na.rm = TRUE),
    weight_z = mean(weight_z, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  pivot_longer(cols = c(lean_z, bmc_z, bmd_z, fat_z, weight_z), names_to = "metric", values_to = "value") %>%
  mutate(
    metric = recode(
      metric,
      lean_z = "Lean mass",
      bmc_z = "Bone mineral content",
      bmd_z = "Bone mineral density",
      fat_z = "Fat mass",
      weight_z = "Body weight"
    )
  )
write_csv(structure_summary, file.path(analysis_dir, "KNHANES_Table_S2_Structure_By_Quartile.csv"))

prevalence_summary <- analysis_50 %>%
  group_by(sex_label, dxa_mbr_quartile) %>%
  summarise(
    osteoporosis_any = mean(osteoporosis_any == 1, na.rm = TRUE),
    osteoporosis_tf = mean(osteoporosis_tf == 1, na.rm = TRUE),
    osteoporosis_fn = mean(osteoporosis_fn == 1, na.rm = TRUE),
    osteoporosis_ls = mean(osteoporosis_ls == 1, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  pivot_longer(cols = starts_with("osteoporosis_"), names_to = "outcome", values_to = "prevalence") %>%
  mutate(
    outcome = recode(
      outcome,
      osteoporosis_any = "Overall osteoporosis",
      osteoporosis_tf = "Total femur osteoporosis",
      osteoporosis_fn = "Femoral neck osteoporosis",
      osteoporosis_ls = "Lumbar spine osteoporosis"
    ),
    prevalence_pct = prevalence * 100
  )
write_csv(prevalence_summary, file.path(analysis_dir, "KNHANES_Table_S3_Osteoporosis_Prevalence_By_Quartile.csv"))

assoc_tbl <- bind_rows(
  fit_logistic(analysis_50, "osteoporosis_any", "Overall >=50", include_sex = TRUE),
  fit_logistic(analysis_50, "low_bone_mass", "Overall >=50", include_sex = TRUE),
  fit_logistic(analysis_50, "osteoporosis_tf", "Overall >=50", include_sex = TRUE),
  fit_logistic(analysis_50, "osteoporosis_fn", "Overall >=50", include_sex = TRUE),
  fit_logistic(analysis_50, "osteoporosis_ls", "Overall >=50", include_sex = TRUE),
  fit_logistic(female_50, "osteoporosis_any", "Female >=50", include_sex = FALSE),
  fit_logistic(female_50, "low_bone_mass", "Female >=50", include_sex = FALSE),
  fit_logistic(female_50, "osteoporosis_tf", "Female >=50", include_sex = FALSE),
  fit_logistic(female_50, "osteoporosis_fn", "Female >=50", include_sex = FALSE),
  fit_logistic(female_50, "osteoporosis_ls", "Female >=50", include_sex = FALSE),
  fit_logistic(male_50, "osteoporosis_any", "Male >=50", include_sex = FALSE),
  fit_logistic(male_50, "low_bone_mass", "Male >=50", include_sex = FALSE),
  fit_logistic(male_50, "osteoporosis_tf", "Male >=50", include_sex = FALSE),
  fit_logistic(male_50, "osteoporosis_fn", "Male >=50", include_sex = FALSE),
  fit_logistic(male_50, "osteoporosis_ls", "Male >=50", include_sex = FALSE)
) %>%
  mutate(
    outcome = recode(
      outcome,
      osteoporosis_any = "Overall osteoporosis",
      low_bone_mass = "Low bone mass",
      osteoporosis_tf = "Total femur osteoporosis",
      osteoporosis_fn = "Femoral neck osteoporosis",
      osteoporosis_ls = "Lumbar spine osteoporosis"
    ),
    p_label = ifelse(p_value < 0.001, "<0.001", sprintf("%.3f", p_value))
  )
write_csv(assoc_tbl, file.path(analysis_dir, "KNHANES_Table_S4_Adjusted_Associations.csv"))

figure1 <- ggplot(analysis_50, aes(x = dxa_mbr, color = sex_label, fill = sex_label)) +
  geom_density(alpha = 0.20, linewidth = 1.7) +
  geom_vline(
    data = dist_summary,
    aes(xintercept = median_mbr, color = sex_label),
    linewidth = 1.1,
    linetype = "dashed",
    show.legend = FALSE
  ) +
  scale_color_manual(values = pick_cols(cell_palette[c(1, 2)], c("Male", "Female"))) +
  scale_fill_manual(values = alpha(pick_cols(cell_palette[c(1, 2)], c("Male", "Female")), 0.22)) +
  labs(x = "DXA-derived MBR", y = "Density", color = NULL, fill = NULL) +
  theme_gsci_cell()
save_pub_plot(figure1, "Figure_KN_1_MBR_Distribution", width = 11.0, height = 7.2)

figure2 <- ggplot(structure_summary, aes(x = dxa_mbr_quartile, y = value, color = metric, group = metric)) +
  geom_line(linewidth = 1.8) +
  geom_point(size = 4.3) +
  facet_wrap(~sex_label, nrow = 1) +
  scale_color_manual(
    values = pick_cols(cell_palette[c(1, 2, 3, 4, 5)],
                       c("Lean mass", "Bone mineral content", "Bone mineral density", "Fat mass", "Body weight"))
  ) +
  labs(x = "DXA-derived MBR quartile", y = "Standardized mean", color = NULL) +
  theme_gsci_cell() +
  guides(color = guide_legend(nrow = 2, byrow = TRUE)) +
  theme(
    legend.text = element_text(size = 22),
    legend.key.width = grid::unit(1.35, "cm"),
    legend.key.height = grid::unit(0.80, "cm")
  )
save_pub_plot(figure2, "Figure_KN_2_Structure_By_Quartile", width = 15.6, height = 8.2)

figure3 <- ggplot(prevalence_summary, aes(x = dxa_mbr_quartile, y = prevalence_pct, color = outcome, group = outcome)) +
  geom_line(linewidth = 1.8) +
  geom_point(size = 4.2) +
  facet_wrap(~sex_label, nrow = 1) +
  scale_color_manual(
    values = pick_cols(cell_palette[c(1, 3, 4, 6)],
                       c("Overall osteoporosis", "Total femur osteoporosis", "Femoral neck osteoporosis", "Lumbar spine osteoporosis"))
  ) +
  labs(x = "DXA-derived MBR quartile", y = "Prevalence (%)", color = NULL) +
  theme_gsci_cell() +
  guides(color = guide_legend(nrow = 2, byrow = TRUE)) +
  theme(
    legend.text = element_text(size = 21),
    legend.key.width = grid::unit(1.25, "cm"),
    legend.key.height = grid::unit(0.78, "cm")
  )
save_pub_plot(figure3, "Figure_KN_3_Osteoporosis_Prevalence", width = 16.2, height = 8.4)

forest_dat <- assoc_tbl %>%
  mutate(
    outcome = factor(outcome, levels = c("Overall osteoporosis", "Low bone mass", "Total femur osteoporosis", "Femoral neck osteoporosis", "Lumbar spine osteoporosis")),
    group = factor(group, levels = c("Overall >=50", "Female >=50", "Male >=50"))
  )

figure4 <- ggplot(forest_dat, aes(x = estimate, y = fct_rev(outcome), color = group)) +
  geom_vline(xintercept = 1, linetype = "dashed", linewidth = 0.8, color = "gray35") +
  geom_errorbarh(aes(xmin = conf_low, xmax = conf_high), height = 0.18, linewidth = 1.2, position = position_dodge(width = 0.60)) +
  geom_point(size = 4.0, position = position_dodge(width = 0.60)) +
  scale_x_continuous(labels = number_format(accuracy = 0.1)) +
  scale_color_manual(values = pick_cols(cell_palette[c(1, 2, 4)], c("Overall >=50", "Female >=50", "Male >=50"))) +
  labs(x = "Adjusted OR per 1 SD increase in DXA-derived MBR", y = NULL, color = NULL) +
  theme_gsci_cell() +
  theme(
    axis.text.y = element_text(size = 22),
    panel.border = element_rect(color = "black", linewidth = 0.9)
  )
save_pub_plot(figure4, "Figure_KN_4_Adjusted_Forest", width = 14.0, height = 8.4)

results_lines <- c(
  "# KNHANES 2008-2011 初步分析结果",
  paste0("日期：", Sys.Date()),
  "",
  "## 数据范围",
  paste0("- 分析样本：年龄 >=50 岁，且具备 DXA-derived MBR 所需变量。n = ", nrow(analysis_50)),
  paste0("- 女性亚组：n = ", nrow(female_50)),
  paste0("- 男性亚组：n = ", nrow(male_50)),
  "",
  "## 口径说明",
  "- 本轮 KNHANES 结果使用 DXA-derived MBR，而不是中国原始 BIA-based MBR。",
  "- 当前为 pooled 2008-2011 的未加权初步分析，用于判断外部方向一致性。",
  "- 目前将 dx_ost 及其分位字段中的 3 解释为 osteoporosis positive；正式入文前仍建议结合说明书复核。",
  "",
  "## 主要输出",
  paste0("- Figure KN1: ", file.path(figure_dir, "Figure_KN_1_MBR_Distribution.pdf")),
  paste0("- Figure KN2: ", file.path(figure_dir, "Figure_KN_2_Structure_By_Quartile.pdf")),
  paste0("- Figure KN3: ", file.path(figure_dir, "Figure_KN_3_Osteoporosis_Prevalence.pdf")),
  paste0("- Figure KN4: ", file.path(figure_dir, "Figure_KN_4_Adjusted_Forest.pdf")),
  paste0("- Table S4: ", file.path(analysis_dir, "KNHANES_Table_S4_Adjusted_Associations.csv"))
)
writeLines(results_lines, file.path(analysis_dir, "KNHANES_results_summary.txt"))

