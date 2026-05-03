# ============================================================
# 03_prep_SHARE.R — Survey of Health, Ageing and Retirement in Europe
# ============================================================
# Cohort: SHARE (g2aging Harmonized SHARE, awaiting approval)
# Role  : HIC reference (Western/Southern/Northern Europe)
# Output: data/derived/share_long.rds
# Status: PLACEHOLDER — SHARE Research Data Center approval pending
# ============================================================

prep_SHARE_fn <- function(
  raw_dir = file.path(here::here(), "data/raw/SHARE"),
  out_dir = file.path(here::here(), "data/derived")
) {
  if (!dir.exists(raw_dir) ||
      length(list.files(raw_dir, pattern = "\\.(dta|sav)$")) == 0) {
    message("[prep_SHARE] data not yet available — returning NULL placeholder")
    return(NULL)
  }
  # TODO[once approved]: implement
  invisible(NULL)
}
