# ============================================================
# 10_combine_5cohorts.R — harmonize 5 prepared cohorts into single panel
# ============================================================
# Inputs : prep_HRS, prep_ELSA, prep_CHARLS, prep_LASI, prep_MHAS  (rds)
#          (SHARE deferred until approval — see _targets.R)
# Output : data/derived/combined_5cohorts.rds
# ============================================================

combine_5cohorts_fn <- function(hrs, elsa, charls, lasi, mhas) {
  cohorts <- list(HRS = hrs, ELSA = elsa, CHARLS = charls,
                  LASI = lasi, MHAS = mhas)
  cohorts <- cohorts[!sapply(cohorts, is.null)]

  if (length(cohorts) == 0) {
    warning("[combine_5cohorts] no cohorts have prepared data yet")
    return(NULL)
  }
  # TODO[W3]: rbindlist with consistent variable schema (defined in
  #            R/helpers/schema_check.R, to be added when first cohort is ready)
  invisible(NULL)
}
