# ============================================================
# _setup.R — one-shot setup
# ============================================================
# Run ONCE after cloning the repo:
#   source("_setup.R")
# ============================================================

if (!requireNamespace("renv", quietly = TRUE)) {
  install.packages("renv", repos = "https://cloud.r-project.org")
}

# Initialize / restore environment
if (file.exists("renv.lock")) {
  message("[setup] renv.lock found — restoring locked package versions ...")
  renv::restore(prompt = FALSE)
} else {
  message("[setup] no renv.lock — initializing fresh renv environment ...")
  renv::init(bare = TRUE)
  pkgs <- c(
    "haven", "data.table", "dplyr", "tidyr", "purrr", "stringr",
    "ggplot2", "patchwork", "scales", "RColorBrewer",
    "survival", "broom", "broom.helpers", "survminer",
    "metafor", "meta",
    "rdrobust", "rddensity", "rddtools",
    "fixest", "bacondecomp",
    "Synth",
    "TwoSampleMR", "MendelianRandomization", "MRPRESSO",
    "mice", "lavaan",
    "knitr", "rmarkdown", "quarto",
    "targets", "tarchetypes",
    "officer", "flextable",
    "here", "fs", "glue", "cli", "logger"
  )
  renv::install(pkgs)
  renv::snapshot(prompt = FALSE)
}

# Create output directories if missing
dirs_needed <- c(
  "data/raw", "data/derived",
  "results/tables", "results/figures", "results/logs",
  "manuscript", "docs"
)
for (d in dirs_needed) {
  if (!dir.exists(d)) {
    dir.create(d, recursive = TRUE)
    message("[setup] created ", d)
  }
}

message("\n[setup] complete. Next: run targets::tar_make()\n")
