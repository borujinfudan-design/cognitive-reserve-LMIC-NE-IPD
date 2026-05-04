# ============================================================
# _install_optional_MR.R — GitHub-only MR dependencies (D4)
# ============================================================
# Prerequisite: source("_setup.R") completed successfully.
#
# Installs:
#   - TwoSampleMR (MRCIEU)
#   - MRPRESSO    (MRCIEU)
#
# Requires network access to GitHub + CRAN (transitive deps).
# ============================================================

if (!requireNamespace("renv", quietly = TRUE)) {
  stop("Run source(\"_setup.R\") first.")
}

message("[install_optional_MR] Installing TwoSampleMR + MRPRESSO from GitHub ...")
renv::install(
  c(
    "MRCIEU/TwoSampleMR",
    "MRCIEU/MRPRESSO"
  ),
  prompt = FALSE
)

renv::snapshot(prompt = FALSE, type = "simple")

message("\n[install_optional_MR] Done. Update renv.lock committed to git when satisfied.")
message("  Test: targets::tar_make(mr_hic)\n")
