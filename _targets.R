# ============================================================
# _targets.R — pipeline definition for cognitive-reserve-LMIC-NE-IPD
# ============================================================
# Run with:   targets::tar_make()
# Inspect:    targets::tar_visnetwork()
# Read out:   targets::tar_read(target_name)
# ============================================================

library(targets)
library(tarchetypes)

# ---- Required packages (loaded in every worker) ----
# Global packages for workers. TwoSampleMR / MRPRESSO are GitHub-only — loaded
# only for tar_target(mr_hic) so tar_make(prep_HRS) works without them.
# After: source("_install_optional_MR.R")
tar_option_set(
  packages = c(
    "haven", "data.table", "dplyr", "tidyr", "purrr", "stringr",
    "ggplot2", "patchwork", "scales",
    "survival", "broom", "broom.helpers",
    "metafor",
    "rdrobust", "rddensity",
    "fixest", "bacondecomp",
    "Synth",
    "MendelianRandomization",
    "mice", "lavaan",
    "knitr", "rmarkdown", "quarto"
  ),
  format  = "rds",
  memory  = "transient",
  garbage_collection = TRUE,
  workspace_on_error = TRUE
)

# ---- Source all helpers + scripts ----
lapply(list.files("R/helpers", pattern = "\\.R$", full.names = TRUE), source)
lapply(list.files("R", pattern = "^[0-9]{2}_.*\\.R$", full.names = TRUE), source)

# ============================================================
# Pipeline
# ============================================================
list(

  # ---- Stage 1: cohort preparation ----
  tar_target(prep_HRS,    prep_HRS_fn(),    format = "rds"),
  tar_target(prep_ELSA,   prep_ELSA_fn(),   format = "rds"),
  tar_target(prep_SHARE,  prep_SHARE_fn(),  format = "rds"),  # placeholder until SHARE approval
  tar_target(prep_CHARLS, prep_CHARLS_fn(), format = "rds"),
  tar_target(prep_LASI,   prep_LASI_fn(),   format = "rds"),
  tar_target(prep_MHAS,   prep_MHAS_fn(),   format = "rds"),

  # ---- Stage 2: cross-cohort harmonized panel ----
  tar_target(combined_5cohorts,
             combine_5cohorts_fn(prep_HRS, prep_ELSA, prep_CHARLS, prep_LASI, prep_MHAS),
             format = "rds"),

  # ---- Stage 3: descriptives (Table 1) ----
  tar_target(table1, build_table1(combined_5cohorts), format = "rds"),

  # ---- Stage 4a: D3 main IPD meta-analysis ----
  tar_target(cox_per_cohort, run_cox_per_cohort(combined_5cohorts), format = "rds"),
  tar_target(meta_pooled,    pool_HR_meta(cox_per_cohort),         format = "rds"),

  # ---- Stage 4b: D1 China RDD ----
  tar_target(rdd_china, run_RDD_China(prep_CHARLS), format = "rds"),

  # ---- Stage 4c: D2 India DID ----
  tar_target(did_india, run_DID_India(prep_LASI), format = "rds"),

  # ---- Stage 4d: D4 MR (HIC subset) ----
  tar_target(
    mr_hic,
    run_MR_HIC(),
    format = "rds",
    packages = c("TwoSampleMR", "MendelianRandomization", "MRPRESSO")
  ),

  # ---- Stage 5: triangulation (main inference figure) ----
  tar_target(fig5_triangulation,
             build_triangulation_fig5(meta_pooled, rdd_china, did_india, mr_hic),
             format = "rds"),

  # ---- Stage 6: sensitivity panel (eFigures) ----
  tar_target(sensitivity_panel,
             run_sensitivity_panel(combined_5cohorts, meta_pooled),
             format = "rds"),

  # ---- Stage 7: render manuscript figures + tables ----
  tar_target(write_outputs, render_all_outputs(
    table1, meta_pooled, rdd_china, did_india, mr_hic,
    fig5_triangulation, sensitivity_panel
  ))
)
