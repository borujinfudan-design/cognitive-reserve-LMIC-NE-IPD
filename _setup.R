# ============================================================
# _setup.R — one-shot environment bootstrap (core dependencies only)
# ============================================================
# Open the .Rproj in RStudio, then in the Console:
#   source("_setup.R")
#
# Optional D4 stack (TwoSampleMR + MRPRESSO from GitHub), run **after** core works:
#   source("_install_optional_MR.R")
#
# Design:
# - renv::init() uses restart = interactive() by default → in RStudio the session
#   restarts mid-script and skips renv::install(). We force restart = FALSE.
# - TwoSampleMR / MRPRESSO are not on CRAN; excluding them here allows
#   tar_make(prep_HRS) without GitHub or IEU toolchain.
# ============================================================

if (!requireNamespace("renv", quietly = TRUE)) {
  install.packages("renv", repos = "https://cloud.r-project.org")
}

# ---- Core packages: prep, targets, RDD, DID, D3 meta, MI, reporting ----
.renv_core_pkgs <- c(
  "haven", "data.table", "dplyr", "tidyr", "purrr", "stringr",
  "ggplot2", "patchwork", "scales", "RColorBrewer",
  "survival", "broom", "broom.helpers", "survminer",
  "metafor", "meta",
  "rdrobust", "rddensity", "rddtools",
  "fixest", "bacondecomp",
  "Synth",
  "MendelianRandomization",
  "mice", "lavaan",
  "knitr", "rmarkdown", "quarto",
  "targets", "tarchetypes",
  "officer", "flextable",
  "here", "fs", "glue", "cli", "logger"
)

if (file.exists("renv.lock")) {
  message("[setup] renv.lock found — restoring locked package versions ...")
  renv::restore(prompt = FALSE)
} else if (dir.exists("renv") && file.exists("renv/activate.R")) {
  message("[setup] renv/ exists but no renv.lock — installing core packages ...")
  renv::install(.renv_core_pkgs)
  renv::snapshot(packages = .renv_core_pkgs, prompt = FALSE)
} else {
  message("[setup] First-time renv init (bare + no session restart) ...")
  renv::init(
    bare = TRUE,
    restart = FALSE,
    load = TRUE
  )
  message("[setup] Installing core packages (may take several minutes) ...")
  renv::install(.renv_core_pkgs)
  message("[setup] Writing renv.lock ...")
  renv::snapshot(packages = .renv_core_pkgs, prompt = FALSE)
}

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

message("\n[setup] complete.")
message("  Next (HRS prep):  targets::tar_make(prep_HRS)")
message("  D4 MR (optional): source(\"_install_optional_MR.R\"); tar_make(mr_hic)\n")
