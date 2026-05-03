# ============================================================
# 05_prep_LASI.R — Longitudinal Aging Study in India
# ============================================================
# Cohort: LASI (g2aging Harmonized LASI wave 1 + LASI-DAD HCAP)
# Role  : KEY cohort — supplies BOTH (a) IPD-meta evidence AND
#         (b) post-1947 state educational expansion DID
# Output: data/derived/lasi_long.rds
#         data/derived/lasi_did_sample.rds
# ============================================================

prep_LASI_fn <- function(
  raw_dir = file.path(here::here(), "data/raw/LASI"),
  out_dir = file.path(here::here(), "data/derived")
) {
  # TODO[W2]: implement
  # Note: LASI dementia imputation pending email follow-up (LASI-DAD team)
  invisible(NULL)
}
