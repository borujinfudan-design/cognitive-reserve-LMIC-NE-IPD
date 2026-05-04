# ============================================================
# 06_prep_MHAS.R — Mexican Health and Aging Study (2001-2022)
# ============================================================
# Cohort  : MHAS
# Primary : Gateway Harmonized MHAS Version D (H_MHAS_d.dta) — 6 waves
# Aug.    : (a) Mex-Cog HCAP 2016 Version A.3 (H_MEX_COG_a3.dta) —
#               gold-standard dementia for ~2,000 subsample (joined W2)
#           (b) Multi-Country Mex-Cog factor scores (B.2)
# Role    : LMIC reference (Latin America); D3 IPD-meta + sister paper
# Output  : data/derived/mhas_long.rds (one row per person × wave)
# Author  : Boru Jin et al. | Last updated: 2026-05
# ============================================================
# Notes:
#   MHAS cognitive battery (Cross-Cultural Cognitive Examination, CCCE):
#     - immediate word recall  (r{w}imrc8,  0-8) — all waves
#     - delayed   word recall  (r{w}dlrc8,  0-8) — all waves
#     - orientation (imputed)  (r{w}orient_m, 0-4) — W2+ only
#     - verbal fluency         (r{w}verbf, count) — W3+ only
#   Composites used:
#     cog_full  = imrc8 + dlrc8 + orient_m  (max 20; W2+)
#     cog_words = imrc8 + dlrc8             (max 16; all waves)
#   We expose cog_words as cog_raw for cross-cohort comparability
#   (W1 lacks orient).  cog_full drives the dementia classifier when
#   available.
#
#   Dementia classification (no official LW-style indicator in MHAS-D):
#     If cog_full available — HRS-LW-scaled cutpoints on 0-20:
#       0-4  → dementia    (≈ 22% of range; matches HRS LW 0-6/27)
#       5-7  → CIND
#       8-20 → normal
#     Otherwise (W1 only) — HRS-LW-scaled on 0-16 words-only:
#       0-3  → dementia
#       4-5  → CIND
#       6-16 → normal
#   Restricted to age ≥ 65 (HCAP convention).
#
#   r{w}proxy = 1 (proxy interview): cind_dx flagged 1 (presumed CIND or
#   worse) ONLY when our cutpoint did not already classify dementia.
#   Mex-Cog HCAP gold-standard dementia (W2) supersedes when joined.
# ============================================================

.MHAS_WAVES <- 1:6  # 2001, 2003, 2012, 2015, 2018, 2021

#' Prepare MHAS data into harmonized long format
#' @export
prep_MHAS_fn <- function(
  raw_dir  = file.path(here::here(), "data/raw/MHAS"),
  out_dir  = file.path(here::here(), "data/derived"),
  log_path = file.path(here::here(), "results/logs/prep_MHAS.log")
) {

  dir.create(out_dir,           showWarnings = FALSE, recursive = TRUE)
  dir.create(dirname(log_path), showWarnings = FALSE, recursive = TRUE)
  log_con <- file(log_path, open = "wt"); on.exit(close(log_con))
  .log <- function(...) {
    msg <- sprintf("[%s] %s", Sys.time(), paste0(..., collapse = ""))
    writeLines(msg, log_con); message(msg)
  }
  .log("prep_MHAS_fn() started")

  # ---------- 1. locate Harmonized MHAS Version D ----------
  hm_candidates <- c(
    file.path(raw_dir, "01_CORE_MHAS/H_MHAS_d.dta"),
    file.path(raw_dir, "H_MHAS_d.dta"),
    file.path(raw_dir, "01_CORE_MHAS/H_MHAS_c2.dta"),  # legacy
    file.path(raw_dir, "H_MHAS_c2.dta")
  )
  hm_path <- Find(file.exists, hm_candidates)
  if (is.null(hm_path)) {
    stop(sprintf("[prep_MHAS] cannot find Harmonized MHAS under %s. Tried:\n  - %s",
                 raw_dir, paste(hm_candidates, collapse = "\n  - ")))
  }
  .log("MHAS source: ", hm_path,
       " (", round(file.info(hm_path)$size / 1e6, 1), " MB)")

  # ---------- 2. read & subset (huge file: 6,500+ cols) ----------
  invariant <- c(
    "unhhidnp",
    "ragender",
    "raedyrs", "raeducl",
    "rabyear"
  )
  wave_patterns <- list(
    iyear   = "r%diwy",
    age     = "r%dagey",
    iwstat  = "r%diwstat",
    proxy   = "r%dproxy",
    imrc8   = "r%dimrc8",
    dlrc8   = "r%ddlrc8",
    orient  = "r%dorient_m",
    verbf   = "r%dverbf",
    rural   = "h%drural"
  )
  wave_vars <- unlist(lapply(wave_patterns, function(p) sprintf(p, .MHAS_WAVES)))

  # Stream in only the columns we need (huge file)
  cols_wanted <- c(invariant, wave_vars)
  hm_raw <- haven::read_dta(hm_path, col_select = dplyr::any_of(cols_wanted))
  cols_present <- names(hm_raw)
  cols_missing <- setdiff(cols_wanted, cols_present)
  if (length(cols_missing) > 0) {
    .log("INFO: ", length(cols_missing), " expected cols not in Harmonized MHAS: ",
         paste(head(cols_missing, 10), collapse = ", "),
         if (length(cols_missing) > 10) " ..." else "")
  }
  .log("subset retained ", ncol(hm_raw), " of ", length(cols_wanted),
       " expected columns; ", nrow(hm_raw), " persons")

  # ---------- 3. pivot to long ----------
  inv_present <- intersect(invariant, cols_present)
  long_list <- vector("list", length(.MHAS_WAVES))
  for (i in seq_along(.MHAS_WAVES)) {
    w <- .MHAS_WAVES[i]
    wave_cols <- vapply(wave_patterns, function(p) sprintf(p, w), character(1))
    keep      <- intersect(wave_cols, cols_present)
    if (length(keep) == 0) next
    sub <- hm_raw[, c(inv_present, keep), drop = FALSE]
    rename_map <- setNames(names(wave_patterns)[match(keep, wave_cols)], keep)
    names(sub)[match(keep, names(sub))] <- rename_map[keep]
    sub$wave <- as.integer(w)
    long_list[[i]] <- sub
  }
  long_list <- Filter(Negate(is.null), long_list)
  if (length(long_list) == 0) stop("[prep_MHAS] no wave columns found")

  all_cols <- unique(unlist(lapply(long_list, names)))
  long_list <- lapply(long_list, function(d) {
    miss <- setdiff(all_cols, names(d))
    for (m in miss) d[[m]] <- NA
    d[, all_cols, drop = FALSE]
  })
  long <- do.call(rbind.data.frame, c(long_list, list(stringsAsFactors = FALSE)))
  .log("after pivot: ", nrow(long), " person-wave rows")

  has_iyear <- "iyear" %in% names(long) & !is.na(long$iyear)
  has_age   <- "age"   %in% names(long) & !is.na(long$age)
  long <- long[has_iyear | has_age, , drop = FALSE]
  .log("after dropping rows missing both iwy and agey: ", nrow(long), " rows")

  # Keep only respondents (iwstat = 1 = interviewed); Harmonized MHAS uses
  # 0/4/5/9 for non-respondent / deceased / no contact.
  if ("iwstat" %in% names(long)) {
    keep <- !is.na(long$iwstat) & long$iwstat == 1L
    .log("iwstat==1 (interviewed) kept: ", sum(keep), " / ", nrow(long))
    long <- long[keep, , drop = FALSE]
  }

  # ---------- 4. cognition composites ----------
  .clip <- function(x, lo, hi) {
    x <- suppressWarnings(as.numeric(x))
    x[x < lo | x > hi] <- NA_real_
    x
  }
  imrc_v   <- if ("imrc8"  %in% names(long)) .clip(long$imrc8,  0, 8) else NA_real_
  dlrc_v   <- if ("dlrc8"  %in% names(long)) .clip(long$dlrc8,  0, 8) else NA_real_
  orient_v <- if ("orient" %in% names(long)) .clip(long$orient, 0, 4) else NA_real_

  cog_words <- imrc_v + dlrc_v                # 0-16, all waves
  cog_full  <- imrc_v + dlrc_v + orient_v     # 0-20, W2+
  long$cog_raw  <- cog_words
  long$cog_full <- cog_full
  .log("cog_words filled: ", sum(!is.na(cog_words)), " / ", nrow(long),
       " (", round(100 * mean(!is.na(cog_words)), 1), "%)")
  .log("cog_full  filled: ", sum(!is.na(cog_full)),  " / ", nrow(long),
       " (", round(100 * mean(!is.na(cog_full)),  1), "%)")

  # ---------- 5. dementia / CIND ----------
  # Primary: 0-20 full scale (W2+); fallback: 0-16 words-only (W1)
  dem_full   <- ifelse(is.na(cog_full), NA_integer_,
                ifelse(cog_full >= 0 & cog_full <=  4, 1L,
                ifelse(cog_full >= 5 & cog_full <= 20, 0L, NA_integer_)))
  cind_full  <- ifelse(is.na(cog_full), NA_integer_,
                ifelse(cog_full >= 5 & cog_full <=  7, 1L,
                ifelse(cog_full >= 0 & cog_full <= 20, 0L, NA_integer_)))
  dem_words  <- ifelse(is.na(cog_words), NA_integer_,
                ifelse(cog_words >= 0 & cog_words <=  3, 1L,
                ifelse(cog_words >= 4 & cog_words <= 16, 0L, NA_integer_)))
  cind_words <- ifelse(is.na(cog_words), NA_integer_,
                ifelse(cog_words >= 4 & cog_words <=  5, 1L,
                ifelse(cog_words >= 0 & cog_words <= 16, 0L, NA_integer_)))

  long$dem_dx     <- ifelse(!is.na(dem_full),  dem_full,  dem_words)
  long$cind_dx    <- ifelse(!is.na(cind_full), cind_full, cind_words)
  long$dem_method <- ifelse(!is.na(dem_full), "mhas_full_cut",
                     ifelse(!is.na(dem_words), "mhas_words_cut", NA_character_))

  # Proxy interviews: presumed cognitively impaired (≥CIND), but only
  # promote cind_dx where we did not already classify dementia.
  proxy_v <- if ("proxy" %in% names(long)) suppressWarnings(as.integer(long$proxy))
             else rep(NA_integer_, nrow(long))
  use_proxy <- !is.na(proxy_v) & proxy_v == 1L &
               !is.na(long$dem_dx) & long$dem_dx == 0L
  long$cind_dx[use_proxy] <- 1L

  # Restrict to age ≥ 65 (HCAP / cross-cohort convention)
  if ("age" %in% names(long)) {
    young <- !is.na(long$age) & long$age < 65
    long$dem_dx[young]     <- NA_integer_
    long$cind_dx[young]    <- NA_integer_
    long$dem_method[young] <- NA_character_
  }
  .log("dem_dx classified: ", sum(!is.na(long$dem_dx)), " rows; ",
       "cind_dx flagged from proxy on ", sum(use_proxy), " additional rows")

  # ---------- 6. education ----------
  long <- recode_education(long, country = "MX")

  # ---------- 7. assemble canonical long ----------
  sex_levels <- c("Male", "Female")
  sex_vec <- factor(ifelse(long$ragender == 1L, "Male",
                    ifelse(long$ragender == 2L, "Female", NA_character_)),
                    levels = sex_levels)

  rural_vec <- if ("rural" %in% names(long)) {
    suppressWarnings(as.integer(long$rural))
  } else NA_integer_

  out <- data.frame(
    id          = paste0("MHAS_", long$unhhidnp, "_w", long$wave),
    cohort      = "MHAS",
    country     = "MEX",
    wave        = as.integer(long$wave),
    iyear       = as.integer(long$iyear),
    age         = as.numeric(long$age),
    sex         = sex_vec,
    race        = factor(NA_character_, levels = c("White", "Non-white")),
    yob         = as.integer(long$rabyear),
    region      = NA_character_,            # MHAS-D carries no rabstate
    rural       = rural_vec,
    edu_yrs     = as.numeric(long$edu_yrs),
    edu_isced   = as.integer(long$edu_isced),
    edu_cat     = long$edu_cat,
    cog_raw     = as.numeric(long$cog_raw), # 0-16 words composite
    cog_z       = NA_real_,
    dem_dx      = as.integer(long$dem_dx),
    cind_dx     = as.integer(long$cind_dx),
    dem_method  = as.character(long$dem_method),
    apoe4       = NA_integer_,              # Mex-Cog DBS planned
    pgs_ad      = NA_real_,
    pgs_edu     = NA_real_,
    stringsAsFactors = FALSE
  )

  # within-wave z-score on words composite
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

  # ---------- 8. validate + summarize + write ----------
  validate_schema(out, cohort_name = "MHAS")

  .log("FINAL: ", nrow(out), " person-wave rows × ", ncol(out), " cols")
  .log("  unique persons: ", length(unique(long$unhhidnp)))
  .log("  waves represented: ", paste(sort(unique(out$wave)), collapse = ", "))
  if (any(!is.na(out$iyear))) {
    .log("  iyear range: ", paste(range(out$iyear, na.rm = TRUE), collapse = " - "))
  }
  if (any(!is.na(out$dem_dx))) {
    n_dem <- sum(out$dem_dx == 1L, na.rm = TRUE)
    n_cls <- sum(!is.na(out$dem_dx))
    .log("  dementia (composite): ", n_dem, " / ", n_cls,
         " (", round(100 * n_dem / n_cls, 2), "%)")
  }
  if (any(!is.na(out$edu_yrs))) {
    .log("  edu_yrs (mean ± SD): ",
         round(mean(out$edu_yrs, na.rm = TRUE), 2), " ± ",
         round(stats::sd(out$edu_yrs, na.rm = TRUE), 2))
  }

  out_file <- file.path(out_dir, "mhas_long.rds")
  saveRDS(out, out_file, compress = "xz")
  .log("wrote ", out_file, " (", round(file.info(out_file)$size / 1e6, 1), " MB)")

  invisible(out)
}
