# ============================================================
# 02_prep_ELSA.R — English Longitudinal Study of Ageing (1998-2021)
# ============================================================
# Cohort  : ELSA
# Primary : Gateway Harmonized ELSA Version H (gh_elsa_h.dta)
# Aug.    : ELSA HCAP Multi-Country (h_elsa_hcap_a2.dta) — cognitive
#           gold-standard subsample (wave 9 = 2018, ~1,100 respondents)
# Role    : HIC reference cohort (D3 IPD harmonised analysis)
# Output  : data/derived/elsa_long.rds (one row per person × wave)
# Author  : Boru Jin et al. | Last updated: 2026-05
# ============================================================
# Notes:
#   ELSA cognitive battery differs from HRS:
#     - immediate word recall (imrc, 0-10)
#     - delayed word recall  (dlrc, 0-10)
#     - orientation         (orient, 0-4)  — sum of mo/dy/yr/dw
#     - verbal fluency      (verbf,  count) — animal naming
#     - NO serial 7s, NO backwards counting from 20
#   Composite score used here: imrc + dlrc + orient (max 24).
#   Verbal fluency is kept as continuous correlate but excluded from
#   total to keep cross-cohort harmonisation tight.
#
#   Dementia: Harmonized ELSA does not provide an official LW-style
#   classification. We:
#     (a) pull r{w}cogimp (the g2aging derived "cognitively impaired"
#         indicator) where available; treat it as presumptive dementia.
#     (b) Where (a) is missing, apply LW-style cutoffs to our 0-24 total
#         (calibrated to HRS prevalence; see Banks et al. 2018; Steel et
#         al. 2024): 0-7 dementia, 8-11 CIND, 12-24 normal.
#     (c) HCAP gold-standard classification can be joined as W2.
#   dem_method tags which path was used.
# ============================================================

.ELSA_WAVES <- 1:10  # 1998-2021 by 2-year intervals (some gaps)

#' Prepare ELSA data into harmonized long format
#' @export
prep_ELSA_fn <- function(
  raw_dir  = file.path(here::here(), "data/raw/ELSA"),
  out_dir  = file.path(here::here(), "data/derived"),
  log_path = file.path(here::here(), "results/logs/prep_ELSA.log")
) {

  dir.create(out_dir,           showWarnings = FALSE, recursive = TRUE)
  dir.create(dirname(log_path), showWarnings = FALSE, recursive = TRUE)
  log_con <- file(log_path, open = "wt"); on.exit(close(log_con))
  .log <- function(...) {
    msg <- sprintf("[%s] %s", Sys.time(), paste0(..., collapse = ""))
    writeLines(msg, log_con); message(msg)
  }
  .log("prep_ELSA_fn() started")

  # ---------- 1. locate Harmonized ELSA Version H ----------
  gh_candidates <- c(
    file.path(raw_dir, "05_UKDS_Original/UKDA-5050-stata/stata/stata13_se/gh_elsa_h.dta"),
    file.path(raw_dir, "01_Gateway_Harmonized_ELSA/gh_elsa_h.dta"),
    file.path(raw_dir, "gh_elsa_h.dta")
  )
  gh_path <- Find(file.exists, gh_candidates)
  if (is.null(gh_path)) {
    stop(sprintf("[prep_ELSA] cannot find gh_elsa_h.dta under %s. Tried:\n  - %s",
                 raw_dir, paste(gh_candidates, collapse = "\n  - ")))
  }
  .log("ELSA source: ", gh_path,
       " (", round(file.info(gh_path)$size / 1e6, 1), " MB)")

  invariant <- c(
    "idauniq",
    "raeducl",      # 3-cat ISCED
    "ragender", "raracem",
    "rabyear", "rabplace"
  )
  wave_patterns <- list(
    iyear  = "r%diwy",
    age    = "r%dagey",
    imrc   = "r%dimrc",
    dlrc   = "r%ddlrc",
    orient = "r%dorient",
    verbf  = "r%dverbf",
    cogimp = "r%dcogimp"
  )
  wave_vars <- unlist(lapply(wave_patterns, function(p) sprintf(p, .ELSA_WAVES)))

  gh_raw <- haven::read_dta(gh_path)
  cols_present <- intersect(c(invariant, wave_vars), names(gh_raw))
  cols_missing <- setdiff(c(invariant, wave_vars), names(gh_raw))
  if (length(cols_missing) > 0) {
    .log("INFO: ", length(cols_missing), " expected cols not in Harmonized ELSA: ",
         paste(head(cols_missing, 8), collapse = ", "),
         if (length(cols_missing) > 8) " ..." else "")
  }
  gh_sub <- gh_raw[, cols_present, drop = FALSE]
  rm(gh_raw); gc()
  .log("subset retained ", ncol(gh_sub), " of ", length(c(invariant, wave_vars)),
       " expected columns; ", nrow(gh_sub), " persons")

  # ---------- 2. pivot to long ----------
  inv_present <- intersect(invariant, cols_present)
  long_list <- vector("list", length(.ELSA_WAVES))
  for (i in seq_along(.ELSA_WAVES)) {
    w <- .ELSA_WAVES[i]
    wave_cols <- vapply(wave_patterns, function(p) sprintf(p, w), character(1))
    keep      <- intersect(wave_cols, cols_present)
    if (length(keep) == 0) next
    sub <- gh_sub[, c(inv_present, keep), drop = FALSE]
    rename_map <- setNames(names(wave_patterns)[match(keep, wave_cols)], keep)
    names(sub)[match(keep, names(sub))] <- rename_map[keep]
    sub$wave <- as.integer(w)
    long_list[[i]] <- sub
  }
  long_list <- Filter(Negate(is.null), long_list)
  if (length(long_list) == 0) stop("[prep_ELSA] no wave columns found at all")

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

  # ---------- 3. cognition composite (imrc + dlrc + orient, max 24) ----------
  .clip <- function(x, lo, hi) {
    x <- suppressWarnings(as.numeric(x))
    x[x < lo | x > hi] <- NA_real_
    x
  }
  imrc_v   <- if ("imrc"   %in% names(long)) .clip(long$imrc,   0, 10) else NA_real_
  dlrc_v   <- if ("dlrc"   %in% names(long)) .clip(long$dlrc,   0, 10) else NA_real_
  orient_v <- if ("orient" %in% names(long)) .clip(long$orient, 0,  4) else NA_real_

  long$cog_raw <- imrc_v + dlrc_v + orient_v   # max 24
  .log("cog_raw filled: ", sum(!is.na(long$cog_raw)), " / ", nrow(long),
       " (", round(100 * mean(!is.na(long$cog_raw)), 1), "%)")

  # ---------- 4. dementia / CIND ----------
  # Path A: g2aging cogimp where available (binary cognitive impairment)
  cogimp_v <- if ("cogimp" %in% names(long)) suppressWarnings(as.integer(long$cogimp))
              else rep(NA_integer_, nrow(long))

  # Path B: ELSA-calibrated cutpoints on 0-24 composite
  #   0-7   → dementia
  #   8-11  → CIND
  #   12-24 → normal
  cog <- long$cog_raw
  dem_b  <- ifelse(is.na(cog), NA_integer_,
            ifelse(cog >= 0 & cog <=  7, 1L,
            ifelse(cog >= 8 & cog <= 24, 0L, NA_integer_)))
  cind_b <- ifelse(is.na(cog), NA_integer_,
            ifelse(cog >= 8  & cog <= 11, 1L,
            ifelse(cog >= 0  & cog <= 24, 0L, NA_integer_)))

  # Combine: prefer cogimp (=1 → dementia) when present and =1; else cutoffs.
  # cogimp = 0 not assumed to imply normal (it may also flag CIND-only),
  # so for cogimp = 0 we fall back to cutpoints.
  long$dem_dx     <- dem_b
  long$cind_dx    <- cind_b
  long$dem_method <- ifelse(is.na(dem_b), NA_character_, "elsa_cutoffs_2024")
  use_imp <- !is.na(cogimp_v) & cogimp_v == 1L
  long$dem_dx[use_imp]     <- 1L
  long$cind_dx[use_imp]    <- 0L
  long$dem_method[use_imp] <- "elsa_g2a_cogimp"

  # Restrict classification to age 60+ (ELSA convention; HCAP screens 65+)
  if ("age" %in% names(long)) {
    young <- !is.na(long$age) & long$age < 60
    long$dem_dx[young]     <- NA_integer_
    long$cind_dx[young]    <- NA_integer_
    long$dem_method[young] <- NA_character_
  }
  .log("dem_dx classified: ", sum(!is.na(long$dem_dx)), " rows; ",
       "cogimp override applied to ", sum(use_imp), " rows")

  # ---------- 5. education ----------
  long <- recode_education(long, country = "UK")

  # ---------- 6. assemble canonical long ----------
  sex_levels <- c("Male", "Female")
  sex_vec <- factor(ifelse(long$ragender == 1L, "Male",
                    ifelse(long$ragender == 2L, "Female", NA_character_)),
                    levels = sex_levels)
  # ELSA raracem is binary 1=White/0=Non-white in some releases; map both
  race_vec <- factor(c(`1` = "White", `0` = "Non-white", `2` = "Non-white",
                       `3` = "Non-white")[as.character(long$raracem)],
                     levels = c("White", "Non-white"))

  out <- data.frame(
    id          = paste0("ELSA_", long$idauniq, "_w", long$wave),
    cohort      = "ELSA",
    country     = "GBR",
    wave        = as.integer(long$wave),
    iyear       = as.integer(long$iyear),
    age         = as.numeric(long$age),
    sex         = sex_vec,
    race        = race_vec,
    yob         = as.integer(long$rabyear),
    region      = if ("rabplace" %in% names(long)) as.character(long$rabplace) else NA_character_,
    rural       = NA_integer_,                          # Harmonized ELSA carries no h{w}rural
    edu_yrs     = as.numeric(long$edu_yrs),
    edu_isced   = as.integer(long$edu_isced),
    edu_cat     = long$edu_cat,
    cog_raw     = as.numeric(long$cog_raw),
    cog_z       = NA_real_,
    dem_dx      = as.integer(long$dem_dx),
    cind_dx     = as.integer(long$cind_dx),
    dem_method  = as.character(long$dem_method),
    apoe4       = NA_integer_,                          # restricted; PGS file separate
    pgs_ad      = NA_real_,
    pgs_edu     = NA_real_,
    stringsAsFactors = FALSE
  )

  # within-wave z-score
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

  # ---------- 7. validate + summarize + write ----------
  validate_schema(out, cohort_name = "ELSA")

  .log("FINAL: ", nrow(out), " person-wave rows × ", ncol(out), " cols")
  .log("  unique persons: ", length(unique(long$idauniq)))
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

  out_file <- file.path(out_dir, "elsa_long.rds")
  saveRDS(out, out_file, compress = "xz")
  .log("wrote ", out_file, " (", round(file.info(out_file)$size / 1e6, 1), " MB)")

  invisible(out)
}
