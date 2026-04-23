library(broom)
library(dplyr)
library(ggplot2)
library(ggsci)
library(readr)
library(tidyr)

root_dir <- normalizePath(".", winslash = "/", mustWork = TRUE)
clean_path <- file.path(root_dir, "data", "processed", "HRS", "HRS_fat_2012_2022_event_bundle.rds")
analysis_dir <- file.path(root_dir, "outputs", "hrs")
hrs_dir <- analysis_dir
figure_dir <- file.path(analysis_dir, "figures")
dir.create(hrs_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(clean_path)) stop("Run prepare_hrs_fat_2012_2022.R first.")

hrs <- readRDS(clean_path)

cell_palette <- pal_npg("nrc")(10)
pick_cols <- function(values, labels) stats::setNames(unname(values), labels)

theme_gsci_cell <- function() {
  theme_bw(base_size = 20) +
    theme(
      panel.grid = element_blank(),
      panel.border = element_rect(color = "black", linewidth = 0.85),
      strip.background = element_rect(fill = "white", color = "black", linewidth = 0.85),
      strip.text = element_text(size = 24, face = "bold"),
      axis.title = element_text(size = 28, face = "bold"),
      axis.text = element_text(size = 22, color = "black"),
      legend.title = element_text(size = 24, face = "bold"),
      legend.text = element_text(size = 22),
      legend.position = "top",
      legend.direction = "horizontal",
      legend.box = "horizontal",
      legend.margin = margin(0, 0, 0, 0),
      legend.box.margin = margin(0, 0, 4, 0),
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

analysis_50 <- hrs %>%
  filter(age >= 50, !is.na(sex))

prev_tbl <- analysis_50 %>%
  group_by(survey_year, sex) %>%
  summarise(
    fall_past2y = mean(fall_past2y == 1, na.rm = TRUE),
    fall_injury = mean(fall_injury == 1, na.rm = TRUE),
    broken_hip = mean(broken_hip == 1, na.rm = TRUE),
    osteoporosis = mean(osteoporosis == 1, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  pivot_longer(cols = c(fall_past2y, fall_injury, broken_hip, osteoporosis),
               names_to = "outcome", values_to = "prevalence") %>%
  mutate(
    outcome = recode(
      outcome,
      fall_past2y = "Fall in past 2 years",
      fall_injury = "Fall-related injury",
      broken_hip = "Broken hip",
      osteoporosis = "Osteoporosis"
    ),
    prevalence_pct = prevalence * 100
  )

age_sex_tbl_2022 <- analysis_50 %>%
  filter(survey_year == 2022, age_group != "<50") %>%
  group_by(age_group, sex) %>%
  summarise(
    fall_past2y = mean(fall_past2y == 1, na.rm = TRUE),
    fall_injury = mean(fall_injury == 1, na.rm = TRUE),
    broken_hip = mean(broken_hip == 1, na.rm = TRUE),
    osteoporosis = mean(osteoporosis == 1, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  pivot_longer(cols = c(fall_past2y, fall_injury, broken_hip, osteoporosis),
               names_to = "outcome", values_to = "prevalence") %>%
  mutate(
    outcome = recode(
      outcome,
      fall_past2y = "Fall in past 2 years",
      fall_injury = "Fall-related injury",
      broken_hip = "Broken hip",
      osteoporosis = "Osteoporosis"
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
        fall_past2y = "Fall in past 2 years",
        fall_injury = "Fall-related injury",
        broken_hip = "Broken hip",
        osteoporosis = "Osteoporosis"
      ),
      label = recode(
        term,
        age10 = "Per 10-year age increase",
        female = "Female vs male"
      ),
      n = nrow(model_data),
      events = sum(model_data$outcome == 1)
    )
}

forest_tbl <- bind_rows(
  fit_one(analysis_50, "fall_past2y"),
  fit_one(analysis_50, "fall_injury"),
  fit_one(analysis_50, "broken_hip"),
  fit_one(analysis_50, "osteoporosis")
) %>%
  select(outcome, label, estimate, conf.low, conf.high, p.value, n, events)

write_csv(prev_tbl, file.path(hrs_dir, "HRS_Table_S1_Prevalence_By_Year_Sex.csv"))
write_csv(age_sex_tbl_2022, file.path(hrs_dir, "HRS_Table_S2_2022_AgeSex_Prevalence.csv"))
write_csv(forest_tbl, file.path(hrs_dir, "HRS_Table_S3_Adjusted_Associations.csv"))

figure1 <- ggplot(prev_tbl, aes(x = factor(survey_year), y = prevalence_pct, color = sex, group = sex)) +
  geom_line(linewidth = 1.4) +
  geom_point(size = 3.4) +
  facet_wrap(~ outcome, scales = "free_y", ncol = 2) +
  scale_color_manual(values = pick_cols(cell_palette[c(1, 2)], c("Male", "Female"))) +
  labs(x = "Survey year", y = "Prevalence (%)", color = NULL) +
  theme_gsci_cell()

save_pub_plot(figure1, "Figure_HRS_1_Prevalence_By_Wave", width = 14, height = 10)

figure2 <- ggplot(age_sex_tbl_2022, aes(x = age_group, y = prevalence_pct, color = sex, group = sex)) +
  geom_line(linewidth = 1.4) +
  geom_point(size = 3.4) +
  facet_wrap(~ outcome, scales = "free_y", ncol = 2) +
  scale_color_manual(values = pick_cols(cell_palette[c(1, 2)], c("Male", "Female"))) +
  labs(x = "Age group", y = "Prevalence (%)", color = NULL) +
  theme_gsci_cell()

save_pub_plot(figure2, "Figure_HRS_2_2022_AgeSex_Prevalence", width = 14, height = 10)

forest_plot_df <- forest_tbl %>%
  mutate(
    outcome = factor(outcome, levels = rev(c("Fall in past 2 years", "Fall-related injury", "Broken hip", "Osteoporosis"))),
    label = factor(label, levels = c("Per 10-year age increase", "Female vs male"))
  )

figure3 <- ggplot(forest_plot_df, aes(x = estimate, y = outcome, color = label)) +
  geom_vline(xintercept = 1, linetype = "dashed", linewidth = 0.8, color = "grey40") +
  geom_errorbarh(aes(xmin = conf.low, xmax = conf.high),
                 position = position_dodge(width = 0.6), height = 0.24, linewidth = 1.2) +
  geom_point(position = position_dodge(width = 0.6), size = 3.6) +
  scale_color_manual(values = pick_cols(cell_palette[c(3, 1)], c("Per 10-year age increase", "Female vs male"))) +
  labs(x = "Adjusted OR", y = NULL, color = NULL) +
  theme_gsci_cell()

save_pub_plot(figure3, "Figure_HRS_3_Adjusted_Forest", width = 12, height = 8)

cat("Saved HRS analysis outputs to:\n", hrs_dir, "\n")

