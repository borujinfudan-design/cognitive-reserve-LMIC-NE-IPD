# ============================================================
# 01_prep_HRS.R — Health and Retirement Study (USA, 1992-2020)
# ============================================================
# Cohort  : HRS (g2aging Harmonized HRS, current release H_HRS_d.dta)
# Role    : HIC reference cohort (D3 IPD-meta + D4 MR PGS subset)
# Output  : data/derived/hrs_long.rds  (one row per person × wave)
# Author  : Boru Jin et al. | Last updated: 2026-05
# Spec    : conforms to SCHEMA_VARS in helpers/schema_check.R
# ============================================================
# Source variables (g2aging Harmonized HRS naming convention):
#
# Time-invariant (RA prefix):
#   hhidpn      person ID
#   raedyrs     years of schooling (continuous, 0-17)
#   raeduc      RAND HRS 5-cat education
#   ragender    sex (1=Male, 2=Female)
#   raracem     race (1=White, 2=Black, 3=Other)
#   rabyear     year of birth (4-digit)
#   rabplace    state of birth (restricted; coded if available)
#   rapoe4      APOE-ε4 allele count (0/1/2; restricted; NA if not loaded)
#   rpolyad     PGS for AD, Bellenguez (z-scored; restricted)
#   rpolyeduy   PGS for educational attainment, Lee (z-scored; restricted)
#
# Wave-varying (r{w} prefix; w = 1..15 for waves 1992..2020):
#   r{w}iwy     interview year (4-digit integer)
#   r{w}agey_e  age at interview (years, end of life version)
#   r{w}cogtot  total cognition score, TICS-27 (preferred for Langa-Weir)
#   r{w}imrc    immediate word recall (0-10)         } used only as fallback
#   r{w}dlrc    delayed word recall (0-10)           }   if r{w}cogtot
#   r{w}ser7    serial 7s subtraction (0-5)         }   missing
#   r{w}bwc20   backwards counting from 20 (0-2)    }
#   h{w}rural   household urbanicity (1=rural, 0=urban; household-level)
# ============================================================

# Wave 1 (1992) used a different cognitive battery; valid Langa-Weir
# data are available from wave 2 (1994) onward. Restrict iteration.
.HRS_WAVES <- 2:15

#' Prepare HRS data into harmonized long format
#'
#' @param raw_dir   directory containing H_HRS_d.dta (typically a symlink
#'                  under data/raw/HRS/)
#' @param out_dir   directory to write hrs_long.rds
#' @param log_path  path to write a small text log
#' @return          a data.frame conforming to SCHEMA_VARS (also saved as RDS)
#' @export
prep_HRS_fn <- function(
  raw_dir  = file.path(here::here(), "data/raw/HRS"),
  out_dir  = file.path(here::here(), "data/derived"),
  log_path = file.path(here::here(), "results/logs/prep_HRS.log")
) {

  # ---------- 0. setup ----------
  dir.create(out_dir,            showWarnings = FALSE, recursive = TRUE)
  dir.create(dirname(log_path),  showWarnings = FALSE, recursive = TRUE)
  log_con <- file(log_path, open = "wt"); on.exit(close(log_con))
  .log <- function(...) {
    msg <- sprintf("[%s] %s", Sys.time(), paste0(..., collapse = ""))
    writeLines(msg, log_con); message(msg)
  }
  .log("prep_HRS_fn() started")

  # ---------- 1. locate file ----------
  # Search common subfolder layouts of the HRS data tree
  candidates <- c(
    file.path(raw_dir, "H_HRS_d.dta"),
    file.path(raw_dir, "02_Gateway_Harmonized_HRS", "H_HRS_d.dta"),
    file.path(raw_dir, "Gateway_Harmonized_HRS", "H_HRS_d.dta")
  )
  hrs_path <- Find(file.exists, candidates)
  if (is.null(hrs_path)) {
    stop(sprintf(
      "[prep_HRS] cannot find H_HRS_d.dta under %s. Tried:\n  - %s",
      raw_dir, paste(candidates, collapse = "\n  - ")
    ))
  }
  .log("reading ", hrs_path, " (", round(file.info(hrs_path)$size / 1e6, 1), " MB)")

  # ---------- 2. read selected columns only (HRS file is huge) ----------
  invariant <- c("hhidpn",
                 "raedyrs", "raeduc",
                 "ragender", "raracem",
                 "rabyear", "rabplace",
                 "rapoe4", "rpolyad", "rpolyeduy")
  wave_patterns <- list(
    iyear  = "r%diwy",
    age    = "r%dagey_e",
    cogtot = "r%dcogtot",
    imrc   = "r%dimrc",
    dlrc   = "r%ddlrc",
    ser7   = "r%dser7",
    bwc20  = "r%dbwc20",
    rural  = "h%drural"
  )
  wave_vars <- unlist(lapply(wave_patterns, function(p) sprintf(p, .HRS_WAVES)))

  # haven::read_dta loads everything; we then subset. (haven doesn't
  # support col_select for .dta directly, so this is the cleanest path.)
  hrs_raw <- haven::read_dta(hrs_path)
  cols_present <- intersect(c(invariant, wave_vars), names(hrs_raw))
  cols_missing <- setdiff(c(invariant, wave_vars), names(hrs_raw))
  if (length(cols_missing) > 0) {
    .log("WARN: ", length(cols_missing),
         " expected columns absent — first 5: ",
         paste(head(cols_missing, 5), collapse = ", "))
  }
  hrs_sub <- hrs_raw[, cols_present, drop = FALSE]
  rm(hrs_raw); gc()
  .log("subset retained ", ncol(hrs_sub), " of ", length(c(invariant, wave_vars)),
       " expected columns; ", nrow(hrs_sub), " rows")

  # ---------- 3. pivot wave-varying vars to long ----------
  # Build a long data.frame by stacking each (var × wave) column.
  inv_present  <- intersect(invariant, cols_present)
  long_list <- vector("list", length(.HRS_WAVES))
  for (i in seq_along(.HRS_WAVES)) {
    w <- .HRS_WAVES[i]
    wave_cols <- vapply(wave_patterns, function(p) sprintf(p, w), character(1))
    keep      <- intersect(wave_cols, cols_present)
    if (length(keep) == 0) {
      .log("wave ", w, " — no columns present; skipping")
      next
    }
    sub <- hrs_sub[, c(inv_present, keep), drop = FALSE]
    # Rename wave-specific columns to schema-friendly names
    rename_map <- setNames(names(wave_patterns)[match(keep, wave_cols)], keep)
    names(sub)[match(keep, names(sub))] <- rename_map[keep]
    sub$wave <- as.integer(w)
    long_list[[i]] <- sub
  }
  long_list <- Filter(Negate(is.null), long_list)
  if (length(long_list) == 0) stop("[prep_HRS] no wave columns found at all")
  long <- do.call(rbind.data.frame, c(long_list, list(stringsAsFactors = FALSE)))
  .log("after pivot: ", nrow(long), " person-wave rows")

  # ---------- 4. drop rows with no interview indicator ----------
  has_iyear <- "iyear" %in% names(long) & !is.na(long$iyear)
  has_age   <- "age"   %in% names(long) & !is.na(long$age)
  keep_row  <- has_iyear | has_age
  long <- long[keep_row, , drop = FALSE]
  .log("after dropping rows missing both iyear and age: ", nrow(long), " rows")

  # ---------- 5. apply harmonization helpers ----------
  long <- recode_education(long, country = "USA")
  long <- derive_dementia(long, method = "langa_weir_2020")

  # ---------- 6. assemble canonical long-format ----------
  sex_levels <- c("Male", "Female")
  sex_vec    <- factor(ifelse(long$ragender == 1L, "Male",
                       ifelse(long$ragender == 2L, "Female", NA_character_)),
                       levels = sex_levels)

  race_vec   <- factor(c(`1` = "White", `2` = "Black", `3` = "Other")[
                         as.character(long$raracem)],
                       levels = c("White", "Black", "Other"))

  out <- data.frame(
    id          = paste0("HRS_", long$hhidpn, "_w", long$wave),
    cohort      = "HRS",
    country     = "USA",
    wave        = as.integer(long$wave),
    iyear       = as.integer(long$iyear),
    age         = as.numeric(long$age),
    sex         = sex_vec,
    race        = race_vec,
    yob         = as.integer(long$rabyear),
    region      = if ("rabplace" %in% names(long)) as.character(long$rabplace) else NA_character_,
    rural       = if ("rural"    %in% names(long)) as.integer(long$rural)      else NA_integer_,
    edu_yrs     = as.numeric(long$edu_yrs),
    edu_isced   = as.integer(long$edu_isced),
    edu_cat     = long$edu_cat,
    cog_raw     = as.numeric(long$cog_raw),
    cog_z       = NA_real_,    # filled below
    dem_dx      = as.integer(long$dem_dx),
    cind_dx     = as.integer(long$cind_dx),
    dem_method  = as.character(long$dem_method),
    apoe4       = if ("rapoe4"    %in% names(long)) as.integer(long$rapoe4)    else NA_integer_,
    pgs_ad      = if ("rpolyad"   %in% names(long)) as.numeric(long$rpolyad)   else NA_real_,
    pgs_edu     = if ("rpolyeduy" %in% names(long)) as.numeric(long$rpolyeduy) else NA_real_,
    stringsAsFactors = FALSE
  )

  # ---------- 7. compute within-wave z-score for cognition ----------
  for (w in unique(out$wave)) {
    idx <- out$wave == w & !is.na(out$cog_raw)
    if (sum(idx) > 1) {
      mu <- mean(out$cog_raw[idx], na.rm = TRUE)
      sd <- stats::sd(out$cog_raw[idx], na.rm = TRUE)
      if (is.finite(sd) && sd > 0) {
        out$cog_z[idx] <- (out$cog_raw[idx] - mu) / sd
      }
    }
  }

  # ---------- 8. validate against canonical schema ----------
  validate_schema(out, cohort_name = "HRS")

  # ---------- 9. summarize for log ----------
  .log("FINAL: ", nrow(out), " person-wave rows × ", ncol(out), " columns")
  n_persons <- length(unique(out$id))   # NB: id includes wave; for unique persons see hhidpn
  .log("  unique person-waves: ", n_persons)
  .log("  waves represented:   ", paste(sort(unique(out$wave)), collapse = ", "))
  .log("  iyear range:         ", paste(range(out$iyear, na.rm = TRUE), collapse = " - "))
  if (any(!is.na(out$dem_dx))) {
    n_dem  <- sum(out$dem_dx == 1L, na.rm = TRUE)
    n_cls  <- sum(!is.na(out$dem_dx))
    .log("  dementia (LW2020):   ", n_dem, " / ", n_cls,
         " (", round(100 * n_dem / n_cls, 2), "%)")
  }

  # ---------- 10. write ----------
  out_file <- file.path(out_dir, "hrs_long.rds")
  saveRDS(out, out_file, compress = "xz")
  .log("wrote ", out_file, " (", round(file.info(out_file)$size / 1e6, 1), " MB)")

  invisible(out)
}
