library(broom)
library(dplyr)
library(ggplot2)
library(ggsci)
library(readr)
library(tidyr)

root_dir <- normalizePath(".", winslash = "/", mustWork = TRUE)
clean_path <- file.path(root_dir, "外部数据", "cleaned", "05_CHARLS", "CHARLS_2011_2020_clinical_context_bundle.rds")
charls_dir <- file.path(root_dir, "工作记录", "analysis_outputs", "05_CHARLS")
figure_dir <- file.path(charls_dir, "figures")
table_dir <- file.path(charls_dir, "tables")

dir.create(charls_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(clean_path)) stop("Run prepare_charls_clinical_context.R first.")

charls <- readRDS(clean_path)
cell_palette <- pal_npg("nrc")(10)
pick_cols <- function(values, labels) stats::setNames(unname(values), labels)

theme_gsci_cell <- function() {
  theme_bw(base_size = 20) +
    theme(
      panel.grid = element_blank(),
      panel.border = element_rect(color = "black", linewidth = 0.9),
      strip.background = element_rect(fill = "white", color = "black", linewidth = 0.85),
      strip.text = element_text(size = 24, face = "bold"),
      axis.title = element_text(size = 28, face = "bold"),
      axis.text = element_text(size = 22, color = "black"),
      legend.title = element_text(size = 24, face = "bold"),
      legend.text = element_text(size = 22),
      legend.position = "top",
      legend.direction = "horizontal",
      legend.box = "horizontal",
      legend.key.width = grid::unit(1.5, "cm"),
      panel.spacing = grid::unit(1.1, "lines"),
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

analysis_50 <- charls %>%
  filter(age >= 50, !is.na(sex))

prev_wave_tbl <- analysis_50 %>%
  group_by(survey_year, sex) %>%
  summarise(
    fall_recent = mean(fall_recent == 1, na.rm = TRUE),
    hip_fracture = mean(hip_fracture == 1, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  pivot_longer(cols = c(fall_recent, hip_fracture), names_to = "outcome", values_to = "prevalence") %>%
  mutate(
    outcome = recode(
      outcome,
      fall_recent = "Recent fall",
      hip_fracture = "Reported hip fracture"
    ),
    prevalence_pct = prevalence * 100
  )

recent_2020_tbl <- analysis_50 %>%
  filter(survey_year == 2020, age_group != "<50") %>%
  group_by(age_group, sex) %>%
  summarise(
    recent_fall = mean(fall_recent == 1, na.rm = TRUE),
    fall_medical_treat = mean(fall_medical_treat == 1, na.rm = TRUE),
    hip_fracture = mean(hip_fracture == 1, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  pivot_longer(cols = c(recent_fall, fall_medical_treat, hip_fracture), names_to = "outcome", values_to = "prevalence") %>%
  mutate(
    outcome = recode(
      outcome,
      recent_fall = "Recent fall",
      fall_medical_treat = "Fall needing medical treatment",
      hip_fracture = "Recent hip fracture"
    ),
    prevalence_pct = prevalence * 100
  )

fit_one <- function(data, outcome_name) {
  model_data <- data %>%
    transmute(
      age10 = age / 10,
      female = ifelse(sex == "Female", 1, 0),
      survey_year = factor(survey_year),
      outcome = .data[[outcome_name]]
    ) %>%
    filter(!is.na(outcome), !is.na(age10), !is.na(female))

  fit <- glm(outcome ~ age10 + female + survey_year, data = model_data, family = binomial())
  broom::tidy(fit, conf.int = TRUE, exponentiate = TRUE) %>%
    filter(term %in% c("age10", "female")) %>%
    mutate(
      outcome = recode(
        outcome_name,
        fall_recent = "Recent fall",
        hip_fracture = "Reported hip fracture",
        fall_medical_treat = "Fall needing medical treatment"
      ),
      label = recode(
        term,
        age10 = "Per 10-year age increase",
        female = "Female vs male"
      ),
      n = nrow(model_data),
      events = sum(model_data$outcome == 1)
    ) %>%
    select(outcome, label, estimate, conf.low, conf.high, p.value, n, events)
}

forest_allwaves_tbl <- bind_rows(
  fit_one(analysis_50, "fall_recent"),
  fit_one(analysis_50, "hip_fracture")
) %>%
  mutate(model_scope = "2011-2020 age>=50")

recent_1820 <- analysis_50 %>%
  filter(survey_year %in% c(2018, 2020))

forest_recent_tbl <- bind_rows(
  fit_one(recent_1820, "fall_recent"),
  fit_one(recent_1820, "fall_medical_treat"),
  fit_one(recent_1820, "hip_fracture")
) %>%
  mutate(model_scope = "2018-2020 age>=50")

wave_availability_tbl <- charls %>%
  filter(age >= 50, !is.na(sex)) %>%
  mutate(question_frame = as.character(question_frame)) %>%
  group_by(survey_year, question_frame) %>%
  summarise(
    n = n(),
    fall_non_missing = sum(!is.na(fall_recent)),
    hip_non_missing = sum(!is.na(hip_fracture)),
    medical_treat_non_missing = sum(!is.na(fall_medical_treat)),
    injury_limit_non_missing = sum(!is.na(injury_limit_daily)),
    .groups = "drop"
  )

write_csv(wave_availability_tbl, file.path(table_dir, "CHARLS_Table_S1_Wave_Availability.csv"))
write_csv(prev_wave_tbl, file.path(table_dir, "CHARLS_Table_S2_Prevalence_By_Wave_Sex.csv"))
write_csv(recent_2020_tbl, file.path(table_dir, "CHARLS_Table_S3_2020_AgeSex_Prevalence.csv"))
write_csv(forest_allwaves_tbl, file.path(table_dir, "CHARLS_Table_S4_Adjusted_Associations_AllWaves.csv"))
write_csv(forest_recent_tbl, file.path(table_dir, "CHARLS_Table_S5_Adjusted_Associations_2018_2020.csv"))

figure1 <- ggplot(prev_wave_tbl, aes(x = factor(survey_year), y = prevalence_pct, color = sex, group = sex)) +
  geom_line(linewidth = 1.4) +
  geom_point(size = 3.4) +
  facet_wrap(~ outcome, scales = "free_y", ncol = 2) +
  scale_color_manual(values = pick_cols(cell_palette[c(1, 2)], c("Male", "Female"))) +
  labs(x = "Survey year", y = "Prevalence (%)", color = NULL) +
  theme_gsci_cell()

save_pub_plot(figure1, "Figure_CHARLS_1_Prevalence_By_Wave", width = 13, height = 8.5)

figure2 <- ggplot(recent_2020_tbl, aes(x = age_group, y = prevalence_pct, color = sex, group = sex)) +
  geom_line(linewidth = 1.4) +
  geom_point(size = 3.4) +
  facet_wrap(~ outcome, scales = "free_y", ncol = 3) +
  scale_color_manual(values = pick_cols(cell_palette[c(1, 2)], c("Male", "Female"))) +
  labs(x = "Age group", y = "Prevalence (%)", color = NULL) +
  theme_gsci_cell()

save_pub_plot(figure2, "Figure_CHARLS_2_2020_AgeSex_Prevalence", width = 16, height = 6.5)

forest_all_plot_df <- forest_allwaves_tbl %>%
  mutate(
    outcome = factor(outcome, levels = rev(c("Recent fall", "Reported hip fracture"))),
    label = factor(label, levels = c("Per 10-year age increase", "Female vs male"))
  )

figure3 <- ggplot(forest_all_plot_df, aes(x = estimate, y = outcome, color = label)) +
  geom_vline(xintercept = 1, linetype = "dashed", linewidth = 0.8, color = "grey40") +
  geom_errorbarh(aes(xmin = conf.low, xmax = conf.high),
                 position = position_dodge(width = 0.6), height = 0.24, linewidth = 1.2) +
  geom_point(position = position_dodge(width = 0.6), size = 3.6) +
  scale_color_manual(values = pick_cols(cell_palette[c(3, 1)], c("Per 10-year age increase", "Female vs male"))) +
  labs(x = "Adjusted OR", y = NULL, color = NULL) +
  theme_gsci_cell()

save_pub_plot(figure3, "Figure_CHARLS_3_Adjusted_Forest_AllWaves", width = 11, height = 6.8)

forest_recent_plot_df <- forest_recent_tbl %>%
  mutate(
    outcome = factor(outcome, levels = rev(c("Recent fall", "Fall needing medical treatment", "Reported hip fracture"))),
    label = factor(label, levels = c("Per 10-year age increase", "Female vs male"))
  )

figure4 <- ggplot(forest_recent_plot_df, aes(x = estimate, y = outcome, color = label)) +
  geom_vline(xintercept = 1, linetype = "dashed", linewidth = 0.8, color = "grey40") +
  geom_errorbarh(aes(xmin = conf.low, xmax = conf.high),
                 position = position_dodge(width = 0.6), height = 0.24, linewidth = 1.2) +
  geom_point(position = position_dodge(width = 0.6), size = 3.6) +
  scale_color_manual(values = pick_cols(cell_palette[c(3, 1)], c("Per 10-year age increase", "Female vs male"))) +
  labs(x = "Adjusted OR", y = NULL, color = NULL) +
  theme_gsci_cell()

save_pub_plot(figure4, "Figure_CHARLS_4_Adjusted_Forest_2018_2020", width = 11.5, height = 7.5)

cat("Saved CHARLS analysis outputs to:\n", charls_dir, "\n")
