# ============================================================
# 01_prep_HRS.R — Health and Retirement Study (USA, 1992-2020)
# ============================================================
# Cohort: HRS (g2aging Harmonized HRS, current wave: H_HRS_d.dta)
# Role  : HIC reference cohort (D3 IPD-meta + D4 MR PGS subset)
# Output: data/derived/hrs_long.rds
# Author: Boru Jin et al. | Last updated: 2026-05
# ============================================================

prep_HRS_fn <- function(
  raw_dir  = file.path(here::here(), "data/raw/HRS"),
  out_dir  = file.path(here::here(), "data/derived"),
  log_path = file.path(here::here(), "results/logs/prep_HRS.log")
) {

  # ---------- 0. setup ----------
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)
  log_con <- file(log_path, open = "wt"); on.exit(close(log_con))
  writeLines(sprintf("[%s] prep_HRS started", Sys.time()), log_con)

  # ---------- 1. read harmonized HRS ----------
  # TODO[W1.3]: confirm file name version (H_HRS_d.dta is wave 15, 2020)
  hrs_raw <- haven::read_dta(file.path(raw_dir, "H_HRS_d.dta"))
  writeLines(sprintf("  raw rows = %d, cols = %d",
                     nrow(hrs_raw), ncol(hrs_raw)), log_con)

  # ---------- 2. select & rename core variables ----------
  # TODO[W1.3]: full variable mapping per Methods section S2.1
  vars_keep <- c(
    id        = "hhidpn",
    wave      = "wave",
    iyear     = "r1iwbeg",
    age       = "ragey_e",
    sex       = "ragender",
    race      = "raracem",
    edu_yrs   = "raedyrs",
    edu_cat   = "raeduc",
    cog_tics  = "r1cogtot",
    dem_dx    = "r1demense",
    apoe4     = "rapoe4",
    pgs_ad    = "rpolyad",
    pgs_edu   = "rpolyeduy",
    state     = "rabplace",
    rural     = "h1rural"
  )
  # NOTE: r-prefixed wave-specific vars need pivoting; this is just a stub
  # See Methods S2.2 for full long-format derivation

  # ---------- 3. recode education (helpers/recode_education.R) ----------
  hrs_long <- hrs_raw |>
    recode_education(country = "USA")  # standardizes to UNESCO ISCED-2011

  # ---------- 4. derive dementia (helpers/derive_dementia.R) ----------
  hrs_long <- hrs_long |>
    derive_dementia(method = "langa_weir_2020")

  # ---------- 5. attach genetic instruments (HIC subset only) ----------
  # TODO[W3]: merge dbGaP PGS file once approved

  # ---------- 6. write ----------
  out_file <- file.path(out_dir, "hrs_long.rds")
  saveRDS(hrs_long, out_file, compress = "xz")
  writeLines(sprintf("[%s] wrote %s (%d rows, %d cols)",
                     Sys.time(), out_file, nrow(hrs_long), ncol(hrs_long)),
             log_con)

  invisible(hrs_long)
}
