# ============================================================
# 01_prep_HRS.R — Health and Retirement Study (USA, 1992-2022)
# ============================================================
# Cohort  : HRS
# Primary : RAND HRS Longitudinal File 2022 (randhrs1992_2022v1.dta)
# Augment : Langa-Weir 2022 cognitive classification (cogfinalimp_9522wide.dta)
# Role    : HIC reference cohort (D3 IPD harmonised analysis + future MR PGS)
# Output  : data/derived/hrs_long.rds  (one row per person × wave)
# Author  : Boru Jin et al. | Last updated: 2026-05
# Spec    : conforms to SCHEMA_VARS in helpers/schema_check.R
# ============================================================
# Notes on data choice:
#   The Gateway Harmonized HRS Version D distribution does NOT carry the
#   continuous education-years variable (raedyrs) nor the per-wave TICS
#   subscores (cogtot/imrc/dlrc/ser7/bwc20). Those are present in the
#   underlying RAND HRS Longitudinal File, which we therefore use as the
#   primary source. Langa-Weir 2022 is then joined to fill / override
#   cogtot27 with the official imputed total (1996-2022).
# ============================================================
#
# Variables consumed (RAND HRS naming):
#   Time-invariant:
#     hhidpn      person ID (numeric)
#     raedyrs     years of schooling (continuous, 0-17)
#     raeduc      RAND HRS 5-cat education (1..5)
#     ragender    sex (1=Male, 2=Female)
#     raracem     race (1=White, 2=Black, 3=Other)
#     rahispan    Hispanic ethnicity (0/1)
#     rabyear     year of birth
#     rabplace    state/region of birth
#     rapoe4      APOE-ε4 alleles (restricted; NA if not in this RAND release)
#
#   Wave-varying (w = 1..16 → 1992, 1994, 1996, 1998, ..., 2022):
#     r{w}iwendy  interview end year (4-digit)
#     r{w}agey_e  age at interview (years; "end of life" version)
#     r{w}cogtot  total cognition score (TICS-27)
#     r{w}imrc    immediate word recall (0-10)        \
#     r{w}dlrc    delayed word recall   (0-10)         |  fallback if
#     r{w}ser7    serial 7s             (0-5)          |  cogtot missing
#     r{w}bwc20   backwards counting    (0-2)         /
#
# rural: NOT in RAND HRS — set to NA (Gateway HRS h{w}rural can be joined
#        in a later W2 step if needed).
# ============================================================

.HRS_WAVES <- 2:16   # wave 1 (1992) used a different cognitive battery; skip

# Map RAND HRS wave -> Langa-Weir cogtot27_imp{YEAR}
.HRS_WAVE_YEAR <- c(
  `2`  = 1994L, `3`  = 1996L, `4`  = 1998L, `5`  = 2000L,
  `6`  = 2002L, `7`  = 2004L, `8`  = 2006L, `9`  = 2008L,
  `10` = 2010L, `11` = 2012L, `12` = 2014L, `13` = 2016L,
  `14` = 2018L, `15` = 2020L, `16` = 2022L
)

#' Prepare HRS data into harmonized long format
#'
#' @param raw_dir   directory containing the HRS data tree (typically
#'                  data/raw/HRS/, a symlink to 5. DATABASE/HRS)
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
  dir.create(out_dir,           showWarnings = FALSE, recursive = TRUE)
  dir.create(dirname(log_path), showWarnings = FALSE, recursive = TRUE)
  log_con <- file(log_path, open = "wt"); on.exit(close(log_con))
  .log <- function(...) {
    msg <- sprintf("[%s] %s", Sys.time(), paste0(..., collapse = ""))
    writeLines(msg, log_con); message(msg)
  }
  .log("prep_HRS_fn() started")

  # ---------- 1. locate RAND HRS Longitudinal File 2022 ----------
  rand_candidates <- c(
    file.path(raw_dir, "01_RAND_HRS_Longitudinal", "01_Longitudinal_File_2022",
              "randhrs1992_2022v1.dta"),
    file.path(raw_dir, "RAND_HRS_Longitudinal", "randhrs1992_2022v1.dta"),
    file.path(raw_dir, "randhrs1992_2022v1.dta")
  )
  rand_path <- Find(file.exists, rand_candidates)
  if (is.null(rand_path)) {
    stop(sprintf(
      "[prep_HRS] cannot find randhrs1992_2022v1.dta under %s. Tried:\n  - %s",
      raw_dir, paste(rand_candidates, collapse = "\n  - ")
    ))
  }
  .log("RAND HRS source: ", rand_path,
       " (", round(file.info(rand_path)$size / 1e6, 1), " MB)")

  # ---------- 2. read selected columns only ----------
  invariant <- c(
    "hhidpn",
    "raedyrs", "raeduc",
    "ragender", "raracem", "rahispan",
    "rabyear", "rabplace",
    "rapoe4"
  )
  wave_patterns <- list(
    iyear  = "r%diwendy",
    age    = "r%dagey_e",
    cogtot = "r%dcogtot",
    imrc   = "r%dimrc",
    dlrc   = "r%ddlrc",
    ser7   = "r%dser7",
    bwc20  = "r%dbwc20"
  )
  wave_vars <- unlist(lapply(wave_patterns, function(p) sprintf(p, .HRS_WAVES)))

  # haven::read_dta loads the whole .dta then we subset (no col_select for
  # .dta). RAND HRS 2022 is ~1.7 GB on disk; read takes ~1-2 min.
  rand_raw <- haven::read_dta(rand_path)
  cols_present <- intersect(c(invariant, wave_vars), names(rand_raw))
  cols_missing <- setdiff(c(invariant, wave_vars), names(rand_raw))
  if (length(cols_missing) > 0) {
    .log("INFO: ", length(cols_missing), " expected cols not in RAND HRS (set NA): ",
         paste(head(cols_missing, 8), collapse = ", "),
         if (length(cols_missing) > 8) " ..." else "")
  }
  rand_sub <- rand_raw[, cols_present, drop = FALSE]
  rm(rand_raw); gc()
  .log("subset retained ", ncol(rand_sub), " of ", length(c(invariant, wave_vars)),
       " expected columns; ", nrow(rand_sub), " persons")

  # ---------- 3. pivot wave-varying vars to long ----------
  inv_present <- intersect(invariant, cols_present)
  long_list <- vector("list", length(.HRS_WAVES))
  for (i in seq_along(.HRS_WAVES)) {
    w <- .HRS_WAVES[i]
    wave_cols <- vapply(wave_patterns, function(p) sprintf(p, w), character(1))
    keep      <- intersect(wave_cols, cols_present)
    if (length(keep) == 0) {
      .log("wave ", w, " — no wave columns present; skipping")
      next
    }
    sub <- rand_sub[, c(inv_present, keep), drop = FALSE]
    rename_map <- setNames(names(wave_patterns)[match(keep, wave_cols)], keep)
    names(sub)[match(keep, names(sub))] <- rename_map[keep]
    sub$wave <- as.integer(w)
    long_list[[i]] <- sub
  }
  long_list <- Filter(Negate(is.null), long_list)
  if (length(long_list) == 0) stop("[prep_HRS] no wave columns found at all")

  # rbind tolerant to differing columns (some waves may lack some vars)
  all_cols <- unique(unlist(lapply(long_list, names)))
  long_list <- lapply(long_list, function(d) {
    miss <- setdiff(all_cols, names(d))
    for (m in miss) d[[m]] <- NA
    d[, all_cols, drop = FALSE]
  })
  long <- do.call(rbind.data.frame, c(long_list, list(stringsAsFactors = FALSE)))
  .log("after pivot: ", nrow(long), " person-wave rows")

  # ---------- 4. drop rows with no interview indicator ----------
  has_iyear <- "iyear" %in% names(long) & !is.na(long$iyear)
  has_age   <- "age"   %in% names(long) & !is.na(long$age)
  long <- long[has_iyear | has_age, , drop = FALSE]
  .log("after dropping rows missing both iwendy and agey_e: ", nrow(long), " rows")

  # ---------- 5. join Langa-Weir 2022 (override cogtot when imputed) ----------
  lw_path <- file.path(raw_dir,
    "11_LangaWeir_Cognitive_Classification", "cogfinalimp_9522wide.dta")
  if (file.exists(lw_path)) {
    lw_wide <- haven::read_dta(lw_path)
    id_col  <- intersect(c("hhidpn", "HHIDPN"), names(lw_wide))[1]
    if (is.na(id_col)) {
      .log("WARN: Langa-Weir file has no hhidpn/HHIDPN column; skipping LW join")
    } else {
      # Build LW long: (hhidpn, wave, cog_lw)
      lw_rows <- list()
      for (w in names(.HRS_WAVE_YEAR)) {
        yr <- .HRS_WAVE_YEAR[[w]]
        col <- sprintf("cogtot27_imp%d", yr)
        if (col %in% names(lw_wide)) {
          v <- as.numeric(lw_wide[[col]])
          v[v < 0 | v > 27] <- NA_real_
          lw_rows[[w]] <- data.frame(
            hhidpn = lw_wide[[id_col]],
            wave   = as.integer(w),
            cog_lw = v,
            stringsAsFactors = FALSE
          )
        }
      }
      lw_long <- do.call(rbind.data.frame, lw_rows)
      lw_long <- lw_long[!is.na(lw_long$cog_lw), , drop = FALSE]
      .log("Langa-Weir long: ", nrow(lw_long),
           " (person × wave) imputed cogtot27 values")
      long <- merge(long, lw_long, by = c("hhidpn", "wave"), all.x = TRUE)
      # Prefer LW imputed total; fall back to RAND r{w}cogtot
      if (!"cogtot" %in% names(long)) long$cogtot <- NA_real_
      long$cog_raw <- ifelse(!is.na(long$cog_lw),
                             as.numeric(long$cog_lw),
                             as.numeric(long$cogtot))
      long$cog_lw <- NULL
      .log("cog_raw filled: ", sum(!is.na(long$cog_raw)), " / ",
           nrow(long), " rows (", round(100 * mean(!is.na(long$cog_raw)), 1), "%)")
    }
  } else {
    .log("INFO: Langa-Weir file not found at ", lw_path, " — using RAND cogtot only")
    long$cog_raw <- if ("cogtot" %in% names(long)) as.numeric(long$cogtot) else NA_real_
  }

  # ---------- 6. apply harmonization helpers ----------
  long <- recode_education(long, country = "USA")
  long <- derive_dementia(long, method = "langa_weir_2020")

  # ---------- 7. assemble canonical long-format ----------
  sex_levels <- c("Male", "Female")
  sex_vec <- factor(ifelse(long$ragender == 1L, "Male",
                    ifelse(long$ragender == 2L, "Female", NA_character_)),
                    levels = sex_levels)

  race_vec <- factor(c(`1` = "White", `2` = "Black", `3` = "Other")[
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
    rural       = NA_integer_,                            # not in RAND HRS
    edu_yrs     = as.numeric(long$edu_yrs),
    edu_isced   = as.integer(long$edu_isced),
    edu_cat     = long$edu_cat,
    cog_raw     = as.numeric(long$cog_raw),
    cog_z       = NA_real_,                                # filled below
    dem_dx      = as.integer(long$dem_dx),
    cind_dx     = as.integer(long$cind_dx),
    dem_method  = as.character(long$dem_method),
    apoe4       = if ("rapoe4" %in% names(long)) as.integer(long$rapoe4) else NA_integer_,
    pgs_ad      = NA_real_,                                # restricted; load separately
    pgs_edu     = NA_real_,
    stringsAsFactors = FALSE
  )

  # ---------- 8. compute within-wave z-score for cognition ----------
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

  # ---------- 9. validate against canonical schema ----------
  validate_schema(out, cohort_name = "HRS")

  # ---------- 10. summarize for log ----------
  .log("FINAL: ", nrow(out), " person-wave rows × ", ncol(out), " columns")
  .log("  unique person-waves: ", length(unique(out$id)))
  .log("  waves represented:   ", paste(sort(unique(out$wave)), collapse = ", "))
  if (any(!is.na(out$iyear))) {
    .log("  iyear range:         ", paste(range(out$iyear, na.rm = TRUE), collapse = " - "))
  }
  if (any(!is.na(out$dem_dx))) {
    n_dem <- sum(out$dem_dx == 1L, na.rm = TRUE)
    n_cls <- sum(!is.na(out$dem_dx))
    .log("  dementia (LW2020):   ", n_dem, " / ", n_cls,
         " (", round(100 * n_dem / n_cls, 2), "%)")
  }
  if (any(!is.na(out$edu_yrs))) {
    .log("  edu_yrs (mean ± SD): ",
         round(mean(out$edu_yrs, na.rm = TRUE), 2), " ± ",
         round(stats::sd(out$edu_yrs, na.rm = TRUE), 2))
  }

  # ---------- 11. write ----------
  out_file <- file.path(out_dir, "hrs_long.rds")
  saveRDS(out, out_file, compress = "xz")
  .log("wrote ", out_file, " (", round(file.info(out_file)$size / 1e6, 1), " MB)")

  invisible(out)
}
