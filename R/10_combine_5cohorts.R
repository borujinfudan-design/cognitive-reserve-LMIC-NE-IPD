# ============================================================
# 10_combine_5cohorts.R — harmonize prepared cohorts into single panel
# ============================================================
# Inputs : prep_HRS, prep_ELSA, prep_CHARLS, prep_LASI, prep_MHAS  (rds)
#          (SHARE deferred until approval — see _targets.R)
# Output : data/derived/combined_5cohorts.rds
# Author : Boru Jin et al. | Last updated: 2026-05
# ============================================================
# Strategy:
#   - Drop any NULL inputs (cohorts not yet prepared).
#   - Coerce factor columns (sex, race, edu_cat) to character before rbind
#     to avoid factor level coercion issues, then re-factorize at the end
#     with canonical levels.
#   - Force schema-typed columns to identical R types across cohorts
#     before rbind (e.g. region must be character; some cohorts may have
#     stored it as integer).
#   - Validate the combined frame against canonical schema before return.
# ============================================================

#' Combine prepared cohort frames into a single canonical panel
#' @export
combine_5cohorts_fn <- function(hrs = NULL, elsa = NULL, charls = NULL,
                                lasi = NULL, mhas = NULL,
                                share = NULL,
                                out_path = file.path(here::here(),
                                                     "data/derived/combined_5cohorts.rds"),
                                log_path = file.path(here::here(),
                                                     "results/logs/combine_5cohorts.log")) {

  dir.create(dirname(out_path), showWarnings = FALSE, recursive = TRUE)
  dir.create(dirname(log_path), showWarnings = FALSE, recursive = TRUE)
  log_con <- file(log_path, open = "wt"); on.exit(close(log_con))
  .log <- function(...) {
    msg <- sprintf("[%s] %s", Sys.time(), paste0(..., collapse = ""))
    writeLines(msg, log_con); message(msg)
  }
  .log("combine_5cohorts_fn() started")

  cohorts <- list(HRS = hrs, ELSA = elsa, CHARLS = charls,
                  LASI = lasi, MHAS = mhas, SHARE = share)
  cohorts <- cohorts[!sapply(cohorts, is.null)]
  if (length(cohorts) == 0) {
    warning("[combine_5cohorts] no cohorts have prepared data yet")
    return(empty_schema_df())
  }
  .log("cohorts available: ", paste(names(cohorts), collapse = ", "))

  # ---- coerce each frame to canonical column set + types ----
  norm_one <- function(d, name) {
    if (!inherits(d, "data.frame")) {
      stop(sprintf("[combine_5cohorts:%s] not a data.frame", name))
    }
    # Add any missing canonical columns as NA-of-correct-type
    miss <- setdiff(SCHEMA_VARS, names(d))
    for (m in miss) {
      typ <- SCHEMA_TYPES[[m]]
      d[[m]] <- switch(typ,
        character = NA_character_,
        integer   = NA_integer_,
        numeric   = NA_real_,
        factor    = factor(NA, levels = if (m == "sex") c("Male", "Female")
                                         else if (m == "edu_cat") EDU_CAT_LEVELS
                                         else if (m == "race")    c("White", "Non-white")
                                         else NULL),
        NA
      )
    }
    # Force types to canonical
    for (v in SCHEMA_VARS) {
      typ <- SCHEMA_TYPES[[v]]
      cur <- d[[v]]
      d[[v]] <- switch(typ,
        character = as.character(cur),
        integer   = suppressWarnings(as.integer(cur)),
        numeric   = suppressWarnings(as.numeric(cur)),
        factor    = {
          target_levels <- if (v == "sex") c("Male", "Female")
                           else if (v == "edu_cat") EDU_CAT_LEVELS
                           else if (v == "race")    c("White", "Non-white")
                           else levels(cur)
          factor(as.character(cur), levels = target_levels)
        },
        cur
      )
    }
    # Keep only canonical columns, in canonical order
    d <- d[, SCHEMA_VARS, drop = FALSE]
    .log("  ", name, ": ", nrow(d), " rows × ", ncol(d), " cols")
    d
  }
  normalized <- Map(norm_one, cohorts, names(cohorts))

  # ---- rbind ----
  combined <- do.call(rbind.data.frame, c(normalized,
                                          list(stringsAsFactors = FALSE)))
  .log("combined: ", nrow(combined), " rows × ", ncol(combined), " cols")

  # ---- validate ----
  validate_schema(combined, cohort_name = "COMBINED")

  # ---- summary ----
  .log("\n--- per-cohort row counts ---")
  print_tbl <- function(t) {
    for (nm in names(t)) .log(sprintf("  %-7s %s", nm, format(t[nm], big.mark=",")))
  }
  print_tbl(table(combined$cohort))
  .log("\n--- per-country unique persons (approx by id prefix) ---")
  ids_per_cohort <- tapply(combined$id, combined$cohort,
                           function(x) length(unique(sub("_w[0-9]+$", "", x))))
  for (nm in names(ids_per_cohort)) .log(sprintf("  %-7s %s", nm, format(ids_per_cohort[nm], big.mark=",")))

  .log("\n--- dem_dx coverage by cohort (65+ only) ---")
  dem_tbl <- by(combined, combined$cohort, function(d) {
    n_class <- sum(!is.na(d$dem_dx))
    n_dem   <- sum(d$dem_dx == 1L, na.rm = TRUE)
    sprintf("classified=%d  dem=%d (%.2f%%)",
            n_class, n_dem,
            ifelse(n_class > 0, 100 * n_dem / n_class, NA))
  })
  for (nm in names(dem_tbl)) .log(sprintf("  %-7s %s", nm, dem_tbl[[nm]]))

  .log("\n--- edu_yrs by cohort ---")
  edu_tbl <- by(combined, combined$cohort, function(d) {
    sprintf("n=%d  mean=%.2f  sd=%.2f",
            sum(!is.na(d$edu_yrs)),
            mean(d$edu_yrs, na.rm = TRUE),
            stats::sd(d$edu_yrs, na.rm = TRUE))
  })
  for (nm in names(edu_tbl)) .log(sprintf("  %-7s %s", nm, edu_tbl[[nm]]))

  saveRDS(combined, out_path, compress = "xz")
  .log("\nwrote ", out_path, " (", round(file.info(out_path)$size/1e6, 2), " MB)")

  invisible(combined)
}
