# Count design denominators from authorized bundles without fitting models.
if (.Platform$OS.type == 'windows') invisible(Sys.setlocale('LC_CTYPE', 'Chinese_China.utf8'))
a <- enc2utf8(commandArgs(TRUE))
stopifnot(length(a) == 5L)
public <- normalizePath(a[1], winslash = '/', mustWork = TRUE)
out <- a[5]
flow <- read.csv(file.path(public, 'sample_flow.csv'), stringsAsFactors = FALSE)
bridge <- read.csv(file.path(public, 'bridge_pooled.csv'), stringsAsFactors = FALSE)
context <- read.csv(file.path(public, 'context_clustered_associations.csv'), stringsAsFactors = FALSE)
coverage <- read.csv(file.path(public, 'context_weight_coverage.csv'), stringsAsFactors = FALSE)
spec <- list(
  HRS = list(file = a[2], id = 'HHIDPN', wave = 'survey_year',
             outcomes = c(fall_past2y = 'Fall in past 2 years', fall_injury = 'Fall-related injury',
                          broken_hip = 'Reported hip fracture', osteoporosis = 'Self-reported osteoporosis')),
  CHARLS = list(file = a[3], id = 'ID', wave = 'survey_year',
                outcomes = c(fall_recent = 'Recent fall', hip_fracture = 'Reported hip fracture')),
  SHARE = list(file = a[4], id = 'mergeid', wave = 'wave',
               outcomes = c(fall_s = 'Fall-related limitation', hip_ever = 'Ever hip fracture',
                            osteoporosis_med = 'Osteoporosis medication'))
)
rows <- list()
put <- function(dataset, sample, measure, n, definition, source) {
  rows[[length(rows) + 1L]] <<- data.frame(dataset, sample, measure, n = as.integer(n), definition, source)
}
put('Chinese BIA', 'Discovery', 'records', 152449,
    'Reported discovery records; not independently verified unique persons',
    'Current manuscript discovery paragraph; original individual reconstruction unavailable')
stopifnot(length(unique(bridge$n)) == 1L, unique(bridge$n) == 11731)
put('NHANES', 'Paired components', 'paired_participants', unique(bridge$n),
    'Persons counted once within each of five DXA imputations; age 8-49', 'bridge_pooled.csv')
for (ds in c('NHANES', 'KNHANES')) {
  z <- flow[flow$dataset == ds, ]
  stopifnot(length(unique(z$eligible)) == 1L)
  put(ds, 'DXA bone health', 'eligible_participants', unique(z$eligible),
      if (ds == 'NHANES') 'Age 40-59 and positive lean/BMC' else 'Age >=50 and positive harmonized LST/BMC',
      'sample_flow.csv')
  for (i in seq_len(nrow(z))) {
    put(ds, z$outcome[i], 'complete_case_participants', z$complete_cases[i],
        'Outcome-specific complete cases used in adjusted and component comparisons', 'sample_flow.csv')
  }
}
for (ds in names(spec)) {
  sp <- spec[[ds]]
  d <- readRDS(sp$file)
  d$pid <- as.character(d[[sp$id]])
  d$age10 <- d$age / 10
  d$female <- ifelse(d$sex == 'Female', 1, 0)
  d$analysis_wave <- as.factor(d[[sp$wave]])
  d <- d[!is.na(d$age) & d$age >= 50 & !is.na(d$female), , drop = FALSE]
  stopifnot(!anyNA(d$pid), !anyNA(d$analysis_wave),
            !anyDuplicated(paste(d$pid, d$analysis_wave)))
  if (ds != 'SHARE') stopifnot(nrow(d) == sum(coverage$records[coverage$dataset == ds]))
  put(ds, 'Clinical context', 'eligible_unique_participants', length(unique(d$pid)),
      'Age >=50, available sex; before outcome-specific complete-case restriction',
      paste('Authorized', ds, 'input; not redistributed'))
  put(ds, 'Clinical context', 'eligible_person_waves', nrow(d),
      'Repeated participant-wave records; not independent persons',
      paste('Authorized', ds, 'input; not redistributed'))
  covars <- c('pid', 'age10', 'female', 'analysis_wave', if (ds == 'SHARE') 'country')
  for (y in names(sp$outcomes)) {
    model <- d[complete.cases(d[, c(covars, y)]), , drop = FALSE]
    expected <- context[context$dataset == ds & !context$weighted &
                        context$contrast == 'Per 10-year age increase' & context$outcome == sp$outcomes[[y]], ]
    if (ds == 'CHARLS') expected <- expected[expected$scope == '2011-2020', ]
    stopifnot(nrow(expected) == 1L, nrow(model) == expected$n,
              length(unique(model$pid)) == expected$participants)
    put(ds, sp$outcomes[[y]], 'complete_case_unique_participants', length(unique(model$pid)),
        'Unweighted clustered-model sample; matches published aggregate table', 'context_clustered_associations.csv')
    put(ds, sp$outcomes[[y]], 'complete_case_person_waves', nrow(model),
        'Unweighted clustered-model records; matches published aggregate table', 'context_clustered_associations.csv')
  }
}
ans <- do.call(rbind, rows)
reference <- read.csv(file.path(public, 'study_design_sample_counts.csv'), stringsAsFactors = FALSE)
stopifnot(identical(ans, reference))
if (file.exists(out)) {
  stopifnot(identical(read.csv(out, stringsAsFactors = FALSE), ans))
} else {
  dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
  write.csv(ans, out, row.names = FALSE)
}
cat('PASS: ', nrow(ans), ' aggregate denominators match; no models fitted.\n', sep = '')
