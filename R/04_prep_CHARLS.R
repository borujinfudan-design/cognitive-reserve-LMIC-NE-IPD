# ============================================================
# 04_prep_CHARLS.R — China Health and Retirement Longitudinal Study
# ============================================================
# Cohort  : CHARLS (NATIVE Chinese release; no g2aging Harmonized file)
# Waves   : 2011, 2013, 2015, 2018, 2020  (and 2014 Life History)
# Role    : LMIC LATAM-mirror (East Asia); CRITICAL for D1 China RDD
#           (1986 Compulsory Schooling Law on 1972-cohort) + D3 IPD-meta.
# Output  : data/derived/charls_long.rds (one row per person × wave)
# Status  : SKELETON (full implementation in W2 sprint)
# ============================================================
# Implementation plan (W2):
#   Each wave needs separate extractor due to non-stationary CHARLS
#   variable naming (column suffixes _w2, _w4 etc.):
#     W1 (2011) - HSF.dta  cog cols: dc001s1-s3 (serial 7), dc002 (penta),
#                  dc003-dc005 (orient yr/mon/day), dc006s1-s10 (imrc),
#                  dc026_1/_2 (dlrc summary)
#     W2 (2013) - HSF.dta  cog cols: dc006_1_s1-s10 (imrc), similar layout
#     W3 (2015) - HSF.dta  cog cols: dc006_wordlist_1-10 (imrc), dc-prefix
#     W4 (2018) - SEPARATE Cognition.dta  cog cols: dc013_w4_*_s* (imrc/dlrc)
#     W5 (2020) - HSF.dta  cog cols: dc011_s1-s5 (orient), dc012_s1-s13 (mem)
#
# Standard CHARLS cognition harmonisation (Lei et al. 2014;
# McCammon et al. 2020):
#   - episodic memory  = (imrc + dlrc) / 2     (0-10)
#   - mental status    = orient (date 5) + s7 (5) + pentagon (1)  (0-11)
#   - total cog        = episodic memory + mental status        (0-21)
#
# Dementia: NO official Langa-Weir analogue; use Hu et al. 2017 / Li
# et al. 2022 cutoffs after baseline calibration to a national prevalence
# benchmark (~6-8% in 65+).
#
# Province for D1 RDD = first 2 chars of communityID (CHARLS internal
# 2-digit code — needs lookup to GB-T 2260 provincial code in W2).
#
# Sex / edu / yob: invariants from W1 demographic_background.dta:
#   ID, rgender (1=M, 2=F), bd001 (edu level 1-10, mapped to years),
#   ba002_1 (year of birth), communityID
# ============================================================
# ============================================================
# Cohort: CHARLS native data (8 waves: 2011 baseline + Life History 2014
#         + main waves 2013/15/18/20 + 2024 + COVID)
# Role  : KEY cohort — supplies BOTH (a) IPD-meta evidence AND
#         (b) 1986 Compulsory Schooling Law fuzzy RDD on mid-life cognition
# Output: data/derived/charls_long.rds
#         data/derived/charls_rdd_sample.rds  (year-of-birth subset)
# NOTE  : Native CHARLS is more comprehensive than g2aging Harmonized CHARLS
#         — we self-harmonize. See Methods S2.4.
# ============================================================

# bd001 (edu level 1-10) → years of schooling (Lei et al. 2014)
.CHARLS_BD001_TO_YRS <- c(
  `1`  = 0,    # No formal education / illiterate
  `2`  = 3,    # Did not finish primary
  `3`  = 4,    # Sishu / private school
  `4`  = 6,    # Elementary (primary)
  `5`  = 9,    # Middle school (junior secondary)
  `6`  = 12,   # High school (senior secondary)
  `7`  = 12,   # Vocational
  `8`  = 15,   # 2-3 yr college
  `9`  = 16,   # Bachelor
  `10` = 19    # Master+
)
.CHARLS_BD001_TO_ISCED <- c(
  `1`  = 0L, `2` = 1L, `3` = 1L, `4` = 1L, `5` = 2L,
  `6`  = 3L, `7` = 3L, `8` = 5L, `9` = 6L, `10` = 7L
)

#' Prepare CHARLS data into harmonized long format
#'
#' v0.1: 2011 baseline only.  W2 (2013), W3 (2015), W4 (2018), W5 (2020)
#' added in next sprint.
#' @export
prep_CHARLS_fn <- function(
  raw_dir  = file.path(here::here(), "data/raw/CHARLS"),
  out_dir  = file.path(here::here(), "data/derived"),
  log_path = file.path(here::here(), "results/logs/prep_CHARLS.log")
) {
  dir.create(out_dir,           showWarnings = FALSE, recursive = TRUE)
  dir.create(dirname(log_path), showWarnings = FALSE, recursive = TRUE)
  log_con <- file(log_path, open = "wt"); on.exit(close(log_con))
  .log <- function(...) {
    msg <- sprintf("[%s] %s", Sys.time(), paste0(..., collapse = ""))
    writeLines(msg, log_con); message(msg)
  }
  .log("prep_CHARLS_fn() started — v0.1: 2011 baseline only")

  # ---------- 1. paths ----------
  demo_path <- file.path(raw_dir, "2011Wave1/_unzipped/demographic_background.dta")
  hsf_path  <- file.path(raw_dir, "2011Wave1/_unzipped/health_status_and_functioning.dta")
  if (!file.exists(demo_path)) stop("[prep_CHARLS] missing ", demo_path)
  if (!file.exists(hsf_path))  stop("[prep_CHARLS] missing ", hsf_path)
  .log("demo: ", demo_path, " (", round(file.info(demo_path)$size/1e6,1), " MB)")
  .log("hsf : ", hsf_path,  " (", round(file.info(hsf_path)$size/1e6,1),  " MB)")

  # ---------- 2. demographics ----------
  demo <- haven::read_dta(
    demo_path,
    col_select = dplyr::any_of(c("ID", "householdID", "communityID",
                                 "rgender", "ba002_1", "bd001"))
  )
  .log("demo n=", nrow(demo), " cols=", ncol(demo))

  # ---------- 3. cognition (W1 HSF) ----------
  # Variable encoding (CHARLS 2011 Codebook §C):
  #   dc006s1-s10 : labelled — value 1-10 indicates which word from a 10-item
  #                  list the respondent recalled in slot X; 11 = "None";
  #                  NA = slot not used. Count of slots with value 1-10 =
  #                  number of words recalled (immediate, max 10).
  #   dc027s1-s10 : same encoding for delayed recall (max 10).
  #   dc003-dc005 : year / month / day-of-week orientation, 1=correct, 2=wrong.
  #   dc001s1-s3  : serial 7s correctness (3 subtractions in W1; W2+ has 5).
  #   dc002       : pentagon copy 1=correct, 2=wrong.
  #   dc026_1/_2  : process variables (timing) — DO NOT use as recall counts.
  cog_imrc    <- paste0("dc006s", 1:10)
  cog_dlrc    <- paste0("dc027s", 1:10)
  cog_orient  <- c("dc003", "dc004", "dc005")
  cog_serial7 <- c("dc001s1", "dc001s2", "dc001s3")
  cog_pent    <- c("dc002")

  cog_cols_wanted <- c("ID", cog_imrc, cog_dlrc, cog_orient, cog_serial7, cog_pent)
  hsf <- haven::read_dta(hsf_path, col_select = dplyr::any_of(cog_cols_wanted))
  .log("hsf  n=", nrow(hsf), " cols=", ncol(hsf))

  # Helper: count slots with value in [1, 10] (i.e., a valid word index)
  .count_valid_recall <- function(df, cols, valid = 1:10) {
    cols <- intersect(cols, names(df))
    if (length(cols) == 0) return(rep(NA_integer_, nrow(df)))
    M <- sapply(cols, function(x) {
      v <- suppressWarnings(as.integer(df[[x]]))
      as.integer(!is.na(v) & v %in% valid)
    })
    n_present <- rowSums(!is.na(sapply(cols, function(x) df[[x]])))
    out <- as.integer(rowSums(M, na.rm = TRUE))
    # If respondent has at least one slot with value 11 (=None) we still
    # consider the test administered. Otherwise (all slots NA) → NA.
    administered <- n_present > 0
    out[!administered] <- NA_integer_
    out
  }
  imrc_v <- .count_valid_recall(hsf, cog_imrc)
  dlrc_v <- .count_valid_recall(hsf, cog_dlrc)

  # Orientation: 1=correct, 2=wrong; count correct items (max 3 in W1)
  .count_correct_orient <- function(df, cols) {
    cols <- intersect(cols, names(df))
    if (length(cols) == 0) return(rep(NA_integer_, nrow(df)))
    M <- sapply(cols, function(x) {
      v <- suppressWarnings(as.integer(df[[x]]))
      as.integer(!is.na(v) & v == 1L)
    })
    n_present <- rowSums(!is.na(sapply(cols, function(x) df[[x]])))
    out <- as.integer(rowSums(M, na.rm = TRUE))
    out[n_present == 0] <- NA_integer_
    out
  }
  orient_v <- .count_correct_orient(hsf, cog_orient)

  # composite (compatible scale 0-23 ≈ ELSA/LASI 0-24):
  #   imrc (0-10) + dlrc (0-10) + orient (0-3)
  cog_raw <- imrc_v + dlrc_v + orient_v

  cog_df <- data.frame(ID = hsf$ID,
                       cog_raw = cog_raw,
                       imrc = imrc_v, dlrc = dlrc_v, orient = orient_v,
                       stringsAsFactors = FALSE)
  .log("cog_raw filled: ", sum(!is.na(cog_df$cog_raw)), " / ", nrow(cog_df),
       " (", round(100 * mean(!is.na(cog_df$cog_raw)), 1), "%)")

  # ---------- 4. merge ----------
  long <- merge(demo, cog_df, by = "ID", all.x = TRUE)
  long$wave  <- 1L
  long$iyear <- 2011L

  # birth year from ba002_1; age = 2011 - yob
  yob <- suppressWarnings(as.integer(long$ba002_1))
  yob[yob < 1900 | yob > 2010] <- NA_integer_
  long$yob <- yob
  long$age <- as.numeric(2011L - yob)

  # province (CHARLS internal 2-digit code in communityID)
  long$province <- substr(as.character(long$communityID), 1, 2)

  # ---------- 5. dementia ----------
  cog <- long$cog_raw
  # HRS-LW-scaled to 0-23 → 0-5 dem (≈22%), 6-9 CIND, 10-23 normal
  dem_b  <- ifelse(is.na(cog), NA_integer_,
            ifelse(cog >= 0 & cog <=  5, 1L,
            ifelse(cog >= 6 & cog <= 23, 0L, NA_integer_)))
  cind_b <- ifelse(is.na(cog), NA_integer_,
            ifelse(cog >= 6  & cog <=  9, 1L,
            ifelse(cog >= 0  & cog <= 23, 0L, NA_integer_)))
  long$dem_dx     <- dem_b
  long$cind_dx    <- cind_b
  long$dem_method <- ifelse(is.na(dem_b), NA_character_,
                            "charls_cutoffs_2024_provisional")

  # restrict to age >= 65 for dementia classification
  young <- !is.na(long$age) & long$age < 65
  long$dem_dx[young]     <- NA_integer_
  long$cind_dx[young]    <- NA_integer_
  long$dem_method[young] <- NA_character_
  .log("dem_dx classified: ", sum(!is.na(long$dem_dx)), " rows")

  # ---------- 6. education ----------
  bd001_chr <- as.character(long$bd001)
  edu_yrs   <- as.numeric(.CHARLS_BD001_TO_YRS[bd001_chr])
  edu_isced <- as.integer(.CHARLS_BD001_TO_ISCED[bd001_chr])
  isced_to_cat <- function(i) {
    if (is.na(i))          return(NA_character_)
    if (i == 0)            return("Less than primary")
    if (i == 1)            return("Primary")
    if (i == 2)            return("Lower secondary")
    if (i %in% c(3, 4))    return("Upper secondary")
    if (i >= 5)            return("Tertiary")
    NA_character_
  }
  edu_cat <- factor(vapply(edu_isced, isced_to_cat, character(1)),
                    levels = EDU_CAT_LEVELS)

  # ---------- 7. assemble canonical long ----------
  sex_vec <- factor(ifelse(long$rgender == 1L, "Male",
                    ifelse(long$rgender == 2L, "Female", NA_character_)),
                    levels = c("Male", "Female"))

  out <- data.frame(
    id          = paste0("CHARLS_", long$ID, "_w1"),
    cohort      = "CHARLS",
    country     = "CHN",
    wave        = 1L,
    iyear       = 2011L,
    age         = long$age,
    sex         = sex_vec,
    race        = factor(NA_character_, levels = c("White", "Non-white")),
    yob         = long$yob,
    region      = long$province,             # CHARLS internal 2-digit code
    rural       = NA_integer_,               # TODO: pull from community.dta in W2
    edu_yrs     = edu_yrs,
    edu_isced   = edu_isced,
    edu_cat     = edu_cat,
    cog_raw     = long$cog_raw,
    cog_z       = NA_real_,
    dem_dx      = long$dem_dx,
    cind_dx     = long$cind_dx,
    dem_method  = long$dem_method,
    apoe4       = NA_integer_,
    pgs_ad      = NA_real_,
    pgs_edu     = NA_real_,
    stringsAsFactors = FALSE
  )

  # within-wave z (single wave so trivial but consistent with template)
  idx <- !is.na(out$cog_raw)
  if (sum(idx) > 1) {
    mu <- mean(out$cog_raw[idx])
    sd <- stats::sd(out$cog_raw[idx])
    if (is.finite(sd) && sd > 0) out$cog_z[idx] <- (out$cog_raw[idx] - mu) / sd
  }

  # ---------- 8. validate + summarize + write ----------
  validate_schema(out, cohort_name = "CHARLS")

  .log("FINAL: ", nrow(out), " rows × ", ncol(out), " cols")
  .log("  unique persons: ", length(unique(long$ID)))
  if (any(!is.na(out$age))) {
    .log("  age (median, IQR): ",
         round(stats::median(out$age, na.rm = TRUE), 1), " (",
         paste(round(stats::quantile(out$age, c(.25,.75), na.rm = TRUE), 1),
               collapse = "-"), ")")
  }
  if (any(!is.na(out$dem_dx))) {
    n_dem <- sum(out$dem_dx == 1L, na.rm = TRUE)
    n_cls <- sum(!is.na(out$dem_dx))
    .log("  dementia (provisional cut, 65+): ", n_dem, " / ", n_cls,
         " (", round(100 * n_dem / n_cls, 2), "%)")
  }
  if (any(!is.na(out$edu_yrs))) {
    .log("  edu_yrs (mean ± SD): ",
         round(mean(out$edu_yrs, na.rm = TRUE), 2), " ± ",
         round(stats::sd(out$edu_yrs, na.rm = TRUE), 2))
  }
  if (any(!is.na(out$region))) {
    n_prov <- length(unique(out$region[!is.na(out$region)]))
    .log("  province codes: ", n_prov, " unique")
  }

  out_file <- file.path(out_dir, "charls_long.rds")
  saveRDS(out, out_file, compress = "xz")
  .log("wrote ", out_file, " (", round(file.info(out_file)$size/1e6,1), " MB)")

  invisible(out)
}
