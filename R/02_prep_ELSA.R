# ============================================================
# 02_prep_ELSA.R — English Longitudinal Study of Ageing
# ============================================================
# Cohort: ELSA (g2aging Harmonized ELSA, file: gh_elsa_h.dta, wave 1-9)
#         + ELSA-HCAP 2018 (h_elsa_hcap_a2.dta, n=1,273)
# Role  : HIC comparator; calibrates dementia algorithm vs. HCAP gold std
# Output: data/derived/elsa_long.rds
# ============================================================

prep_ELSA_fn <- function(
  raw_dir  = file.path(here::here(), "data/raw/ELSA"),
  out_dir  = file.path(here::here(), "data/derived"),
  log_path = file.path(here::here(), "results/logs/prep_ELSA.log")
) {
  # TODO[W1]: end-to-end implementation
  # File 1: gh_elsa_h.dta  (21,679 × 13,687, 426 MB) — long longitudinal
  # File 2: h_elsa_hcap_a2.dta (1,273 × 514, 1 MB) — 2018 HCAP subsample
  invisible(NULL)
}
