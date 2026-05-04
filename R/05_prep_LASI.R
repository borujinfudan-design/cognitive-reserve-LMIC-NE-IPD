# ============================================================
# 05_prep_LASI.R — Longitudinal Aging Study in India (2017-2021)
# ============================================================
# Cohort  : LASI (g2aging Harmonized LASI Version A.3) — Wave 1 only
# Aug.    : LASI-DAD dementia imputation file (PENDING — see folder
#           data/raw/LASI/05_Dementia_Imputation_PENDING_EMAIL/)
# Role    : LMIC reference (South Asia); core to D2 India DID + sister paper.
#           rabplace (state of birth, 1-37) drives DID treatment assignment.
# Output  : data/derived/lasi_long.rds (one row per person × wave)
# Author  : Boru Jin et al. | Last updated: 2026-05
# ============================================================
# Notes:
#   LASI cognitive battery (HRS-style):
#     - immediate word recall (r1imrc, 0-10)
#     - delayed   word recall (r1dlrc, 0-10)
#     - orientation           (r1orient, 0-4)
#     - verbal fluency        (r1verbf, count) — kept as side var
#   Composite: cog_raw = imrc + dlrc + orient (max 24; identical scale to ELSA)
#
#   Dementia (preliminary, until LASI-DAD imputation arrives):
#     ELSA-equivalent cutpoints on 0-24:
#       0-5  → dementia
#       6-9  → CIND
#       10-24 → normal
#     Restricted to age ≥ 65 (LASI sampled 45+).
#     dem_method = "lasi_cutoffs_2024_provisional"
#
#   r1proxy = 1 (proxy interview) — rare in LASI W1 (~1%) — promote
#   cind_dx 0→1 only when cutpoints did not classify dementia.
#
#   Single wave: longitudinal Cox not feasible from LASI alone — used as
#   prevalent-case cohort in IPD, and as DID treatment assignment via
#   rabplace × rabyear in main paper D2.
# ============================================================

.LASI_WAVES <- 1L  # only A.3 W1 currently released; A.4 ~2026

#' Prepare LASI Wave 1 into harmonized long format
#' @export
prep_LASI_fn <- function(
  raw_dir  = file.path(here::here(), "data/raw/LASI"),
  out_dir  = file.path(here::here(), "data/derived"),
  log_path = file.path(here::here(), "results/logs/prep_LASI.log")
) {

  dir.create(out_dir,           showWarnings = FALSE, recursive = TRUE)
  dir.create(dirname(log_path), showWarnings = FALSE, recursive = TRUE)
  log_con <- file(log_path, open = "wt"); on.exit(close(log_con))
  .log <- function(...) {
    msg <- sprintf("[%s] %s", Sys.time(), paste0(..., collapse = ""))
    writeLines(msg, log_con); message(msg)
  }
  .log("prep_LASI_fn() started")

  # ---------- 1. locate Harmonized LASI A.3 ----------
  hl_candidates <- c(
    file.path(raw_dir, "01_Harmonized_LASI_A3_主用_2017-2021/H_LASI_a3.dta"),
    file.path(raw_dir, "01_Harmonized_LASI_A3/H_LASI_a3.dta"),
    file.path(raw_dir, "H_LASI_a3.dta"),
    file.path(raw_dir, "02_Harmonized_LASI_A2_备用_2017-2019/H_LASI_a2.dta")  # fallback
  )
  hl_path <- Find(file.exists, hl_candidates)
  if (is.null(hl_path)) {
    stop(sprintf("[prep_LASI] cannot find Harmonized LASI under %s. Tried:\n  - %s",
                 raw_dir, paste(hl_candidates, collapse = "\n  - ")))
  }
  .log("LASI source: ", hl_path,
       " (", round(file.info(hl_path)$size / 1e6, 1), " MB)")

  # ---------- 2. read & subset ----------
  invariant <- c(
    "prim_key", "hhid", "pn",
    "ragender",
    "raedyrs", "raeducl",
    "rabyear", "rabplace"
  )
  wave_patterns <- list(
    iyear   = "r%diwy",
    age     = "r%dagey",
    iwstat  = "r%diwstat",
    proxy   = "r%dproxy",
    imrc    = "r%dimrc",
    dlrc    = "r%ddlrc",
    orient  = "r%dorient",
    verbf   = "r%dverbf",
    rural   = "hh%drural",
    state   = "hh%dstate"
  )
  wave_vars <- unlist(lapply(wave_patterns, function(p) sprintf(p, .LASI_WAVES)))
  cols_wanted <- c(invariant, wave_vars)

  hl_raw <- haven::read_dta(hl_path, col_select = dplyr::any_of(cols_wanted))
  cols_present <- names(hl_raw)
  cols_missing <- setdiff(cols_wanted, cols_present)
  if (length(cols_missing) > 0) {
    .log("INFO: ", length(cols_missing), " expected cols not in Harmonized LASI: ",
         paste(head(cols_missing, 8), collapse = ", "))
  }
  .log("subset retained ", ncol(hl_raw), " of ", length(cols_wanted),
       " expected columns; ", nrow(hl_raw), " persons")

  # ---------- 3. pivot to long (single wave, but use generic structure) ----------
  inv_present <- intersect(invariant, cols_present)
  long_list <- vector("list", length(.LASI_WAVES))
  for (i in seq_along(.LASI_WAVES)) {
    w <- .LASI_WAVES[i]
    wave_cols <- vapply(wave_patterns, function(p) sprintf(p, w), character(1))
    keep      <- intersect(wave_cols, cols_present)
    if (length(keep) == 0) next
    sub <- hl_raw[, c(inv_present, keep), drop = FALSE]
    rename_map <- setNames(names(wave_patterns)[match(keep, wave_cols)], keep)
    names(sub)[match(keep, names(sub))] <- rename_map[keep]
    sub$wave <- as.integer(w)
    long_list[[i]] <- sub
  }
  long <- do.call(rbind.data.frame, c(Filter(Negate(is.null), long_list),
                                      list(stringsAsFactors = FALSE)))
  .log("after pivot: ", nrow(long), " person-wave rows")

  has_iyear <- "iyear" %in% names(long) & !is.na(long$iyear)
  has_age   <- "age"   %in% names(long) & !is.na(long$age)
  long <- long[has_iyear | has_age, , drop = FALSE]
  .log("after dropping rows missing both iwy and agey: ", nrow(long), " rows")

  if ("iwstat" %in% names(long)) {
    keep <- !is.na(long$iwstat) & long$iwstat == 1L
    .log("iwstat==1 (interviewed) kept: ", sum(keep), " / ", nrow(long))
    long <- long[keep, , drop = FALSE]
  }

  # ---------- 4. cognition composite ----------
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

  # ---------- 5. dementia / CIND (provisional cutpoints) ----------
  cog <- long$cog_raw
  dem_b  <- ifelse(is.na(cog), NA_integer_,
            ifelse(cog >= 0 & cog <=  5, 1L,
            ifelse(cog >= 6 & cog <= 24, 0L, NA_integer_)))
  cind_b <- ifelse(is.na(cog), NA_integer_,
            ifelse(cog >= 6  & cog <=  9, 1L,
            ifelse(cog >= 0  & cog <= 24, 0L, NA_integer_)))

  long$dem_dx     <- dem_b
  long$cind_dx    <- cind_b
  long$dem_method <- ifelse(is.na(dem_b), NA_character_,
                            "lasi_cutoffs_2024_provisional")

  proxy_v <- if ("proxy" %in% names(long)) suppressWarnings(as.integer(long$proxy))
             else rep(NA_integer_, nrow(long))
  use_proxy <- !is.na(proxy_v) & proxy_v == 1L &
               !is.na(long$dem_dx) & long$dem_dx == 0L
  long$cind_dx[use_proxy] <- 1L

  if ("age" %in% names(long)) {
    young <- !is.na(long$age) & long$age < 65
    long$dem_dx[young]     <- NA_integer_
    long$cind_dx[young]    <- NA_integer_
    long$dem_method[young] <- NA_character_
  }
  .log("dem_dx classified: ", sum(!is.na(long$dem_dx)), " rows; ",
       "cind_dx flagged from proxy on ", sum(use_proxy), " additional rows")

  # ---------- 6. education ----------
  long <- recode_education(long, country = "IN")

  # ---------- 7. assemble canonical long ----------
  sex_levels <- c("Male", "Female")
  sex_vec <- factor(ifelse(long$ragender == 1L, "Male",
                    ifelse(long$ragender == 2L, "Female", NA_character_)),
                    levels = sex_levels)

  rural_vec <- if ("rural" %in% names(long)) suppressWarnings(as.integer(long$rural))
               else NA_integer_

  # region: prefer state of birth (rabplace) for D2 DID; fall back to current
  region_vec <- if ("rabplace" %in% names(long))
                  as.character(long$rabplace)
                else if ("state" %in% names(long))
                  as.character(long$state)
                else NA_character_

  # build a stable id from prim_key (preferred) else hhid+pn
  if ("prim_key" %in% names(long)) {
    base_id <- as.character(long$prim_key)
  } else {
    base_id <- paste0(long$hhid, "_", long$pn)
  }

  out <- data.frame(
    id          = paste0("LASI_", base_id, "_w", long$wave),
    cohort      = "LASI",
    country     = "IND",
    wave        = as.integer(long$wave),
    iyear       = as.integer(long$iyear),
    age         = as.numeric(long$age),
    sex         = sex_vec,
    race        = factor(NA_character_, levels = c("White", "Non-white")),
    yob         = as.integer(long$rabyear),
    region      = region_vec,                   # state of birth (1-37)
    rural       = rural_vec,
    edu_yrs     = as.numeric(long$edu_yrs),
    edu_isced   = as.integer(long$edu_isced),
    edu_cat     = long$edu_cat,
    cog_raw     = as.numeric(long$cog_raw),
    cog_z       = NA_real_,
    dem_dx      = as.integer(long$dem_dx),
    cind_dx     = as.integer(long$cind_dx),
    dem_method  = as.character(long$dem_method),
    apoe4       = NA_integer_,
    pgs_ad      = NA_real_,
    pgs_edu     = NA_real_,
    stringsAsFactors = FALSE
  )

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
  validate_schema(out, cohort_name = "LASI")

  .log("FINAL: ", nrow(out), " person-wave rows × ", ncol(out), " cols")
  .log("  unique persons: ", length(unique(base_id)))
  .log("  waves represented: ", paste(sort(unique(out$wave)), collapse = ", "))
  if (any(!is.na(out$iyear))) {
    .log("  iyear range: ", paste(range(out$iyear, na.rm = TRUE), collapse = " - "))
  }
  if (any(!is.na(out$age))) {
    .log("  age (median, IQR): ",
         round(stats::median(out$age, na.rm = TRUE), 1), " (",
         paste(round(stats::quantile(out$age, c(.25,.75), na.rm = TRUE), 1),
               collapse = "-"), ")")
  }
  if (any(!is.na(out$dem_dx))) {
    n_dem <- sum(out$dem_dx == 1L, na.rm = TRUE)
    n_cls <- sum(!is.na(out$dem_dx))
    .log("  dementia (provisional cut): ", n_dem, " / ", n_cls,
         " (", round(100 * n_dem / n_cls, 2), "%) — ",
         "REPLACE WITH LASI-DAD IMPUTATION WHEN AVAILABLE")
  }
  if (any(!is.na(out$edu_yrs))) {
    .log("  edu_yrs (mean ± SD): ",
         round(mean(out$edu_yrs, na.rm = TRUE), 2), " ± ",
         round(stats::sd(out$edu_yrs, na.rm = TRUE), 2))
  }
  if (any(!is.na(out$rural))) {
    .log("  rural fraction: ",
         round(100 * mean(out$rural, na.rm = TRUE), 1), "%")
  }
  if (any(!is.na(out$region))) {
    n_states <- length(unique(out$region[!is.na(out$region)]))
    .log("  rabplace (state of birth): ", n_states, " unique values")
  }

  out_file <- file.path(out_dir, "lasi_long.rds")
  saveRDS(out, out_file, compress = "xz")
  .log("wrote ", out_file, " (", round(file.info(out_file)$size / 1e6, 1), " MB)")

  invisible(out)
}
