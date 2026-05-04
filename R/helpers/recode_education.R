# ============================================================
# helpers/recode_education.R
# ============================================================
# Cross-cohort harmonization to UNESCO ISCED-2011 (years of schooling)
#
# Currently implemented:
#   USA  — Harmonized HRS (raedyrs + raeduc)
#   UK   — TODO (Harmonized ELSA)
#   EU   — TODO (Harmonized SHARE)
#   CN   — TODO (CHARLS native, ba009 + edu_attain)
#   IN   — TODO (Harmonized LASI)
#   MX   — TODO (Harmonized MHAS)
#
# Returns the input data with three new / overwritten columns:
#   - edu_yrs   numeric  — continuous years of schooling
#   - edu_isced integer  — UNESCO ISCED-2011 level (0-8)
#   - edu_cat   factor   — 5-level collapse (see EDU_CAT_LEVELS)
# ============================================================

#' Harmonize education variables to UNESCO ISCED-2011
#'
#' @param df       data.frame with cohort-native education columns
#' @param country  one of: "USA","UK","EU","CN","IN","MX"
#' @return same df with edu_yrs, edu_isced, edu_cat appended/overwritten
#' @export
recode_education <- function(df,
                             country = c("USA", "UK", "EU", "CN", "IN", "MX")) {
  country <- match.arg(country)
  switch(country,
    USA = recode_education_USA(df),
    UK  = recode_education_UK(df),
    EU  = recode_education_EU(df),
    CN  = recode_education_CN(df),
    IN  = recode_education_IN(df),
    MX  = recode_education_MX(df)
  )
}

# ============================================================
# USA — Harmonized HRS (g2aging)
# ============================================================
#
# Source: Harmonized HRS Codebook (current release H_HRS_d.dta).
# Two relevant variables are time-invariant ("ra" prefix):
#
#   raedyrs  — years of schooling, continuous (0-17)
#              Range: 0 = none, 17 = post-graduate.
#              Highly recommended primary measure.
#
#   raeduc   — RAND HRS 5-category education
#              1 = Less than high school
#              2 = GED
#              3 = High school graduate
#              4 = Some college
#              5 = College and above
#
# Strategy:
#   - Use raedyrs as the continuous measure (preferred).
#   - Map raeduc → UNESCO ISCED-2011 level.
#   - Cross-check: if raedyrs missing but raeduc present, impute raedyrs
#     from category midpoint.
# ------------------------------------------------------------

# RAND HRS 5-category → ISCED-2011 mapping
# Mapping rationale:
#   Cat 1 (less than high school)         → ISCED 2 (lower secondary; <12 yrs)
#   Cat 2 (GED)                           → ISCED 3 (upper secondary; equiv HS)
#   Cat 3 (high school graduate)          → ISCED 3 (upper secondary)
#   Cat 4 (some college, no degree)       → ISCED 4 (post-secondary non-tertiary)
#   Cat 5 (college and above)             → ISCED 6+ (tertiary)
.HRS_RAEDUC_TO_ISCED <- c(
  "1" = 2L,
  "2" = 3L,
  "3" = 3L,
  "4" = 4L,
  "5" = 6L
)

# Years-from-category fallback for missing raedyrs
.HRS_RAEDUC_TO_YRS <- c(
  "1" = 9,    # midpoint of <12 years
  "2" = 12,   # GED ~= 12 yrs equivalent
  "3" = 12,   # HS grad
  "4" = 14,   # 2 yrs of college
  "5" = 16    # 4-yr degree (under-estimates post-grads)
)

#' Recode HRS education to harmonized schema
#' @keywords internal
recode_education_USA <- function(df) {

  # Defensive: confirm expected source columns
  needed <- c("raedyrs", "raeduc")
  miss <- setdiff(needed, names(df))
  if (length(miss) > 0) {
    stop(sprintf("[recode_education_USA] missing source columns: %s",
                 paste(miss, collapse = ", ")))
  }

  raeduc_chr  <- as.character(df$raeduc)
  raedyrs_num <- suppressWarnings(as.numeric(df$raedyrs))

  # Out-of-range to NA (raedyrs encodes some invalid as 99)
  raedyrs_num[raedyrs_num < 0 | raedyrs_num > 22] <- NA_real_

  # Step 1: edu_yrs — prefer raedyrs, fall back to category midpoint
  edu_yrs <- raedyrs_num
  fallback_idx <- is.na(edu_yrs) & raeduc_chr %in% names(.HRS_RAEDUC_TO_YRS)
  edu_yrs[fallback_idx] <- .HRS_RAEDUC_TO_YRS[raeduc_chr[fallback_idx]]

  # Step 2: edu_isced — derive from raeduc category (most reliable)
  edu_isced <- as.integer(.HRS_RAEDUC_TO_ISCED[raeduc_chr])

  # If raeduc missing but raedyrs available, impute ISCED from years
  # (continuous → category mapping per UNESCO guidance for US system)
  isced_from_yrs <- function(y) {
    if (is.na(y))                  return(NA_integer_)
    if (y <  6)                    return(1L)   # primary
    if (y <  9)                    return(2L)   # lower secondary
    if (y < 12)                    return(2L)   # still lower sec (US dropouts)
    if (y == 12)                   return(3L)   # HS grad / GED
    if (y < 16)                    return(4L)   # some college
    if (y >= 16)                   return(6L)   # bachelor or above
    return(NA_integer_)
  }
  isced_imputed <- vapply(edu_yrs, isced_from_yrs, integer(1))
  edu_isced[is.na(edu_isced)] <- isced_imputed[is.na(edu_isced)]

  # Step 3: edu_cat — 5-level collapse from ISCED
  isced_to_cat <- function(i) {
    if (is.na(i))           return(NA_character_)
    if (i == 0)             return("Less than primary")
    if (i == 1)             return("Primary")
    if (i == 2)             return("Lower secondary")
    if (i %in% c(3, 4))     return("Upper secondary")
    if (i >= 5)             return("Tertiary")
    return(NA_character_)
  }
  edu_cat <- factor(
    vapply(edu_isced, isced_to_cat, character(1)),
    levels = EDU_CAT_LEVELS
  )

  df$edu_yrs   <- edu_yrs
  df$edu_isced <- edu_isced
  df$edu_cat   <- edu_cat

  df
}

# ============================================================
# Placeholder country recodes (TODO in W2)
# ============================================================

# ============================================================
# UK — Harmonized ELSA (g2aging Version H)
# ============================================================
#
# Source: Harmonized ELSA Codebook, Version H.
#
# Available variable:
#   raeducl  — UNESCO ISCED-2011 collapsed level (1-3)
#              1 = Less than upper secondary  (UK no qualifications / O-level)
#              2 = Upper secondary / vocational (A-level / NVQ 2-3)
#              3 = Tertiary (degree / NVQ 4-5)
#
# Note: Harmonized ELSA Version H does NOT carry continuous years of
# schooling (raedyrs). HCAP file h_elsa_hcap_a2.dta does carry raedyrs_e
# but only for the ~1,100 HCAP subsample. We therefore impute years from
# raeducl using UK-system midpoints commonly used in life-course
# epidemiology (Banks et al. 2018; Steptoe et al. 2013):
#
#   raeducl 1 → 9 yrs   (left school at 14-16; no formal qualification)
#   raeducl 2 → 12 yrs  (A-level / NVQ 3 typical age 18 leaver)
#   raeducl 3 → 16 yrs  (university degree typical 21-leaver, +3 sixth form)
# ------------------------------------------------------------

.ELSA_RAEDUCL_TO_ISCED <- c(`1` = 2L, `2` = 3L, `3` = 6L)
.ELSA_RAEDUCL_TO_YRS   <- c(`1` = 9,  `2` = 12, `3` = 16)

#' @keywords internal
recode_education_UK <- function(df) {

  if (!"raeducl" %in% names(df)) {
    stop("[recode_education_UK] expected column raeducl not found")
  }
  raeducl_chr <- as.character(df$raeducl)

  edu_yrs   <- as.numeric(.ELSA_RAEDUCL_TO_YRS[raeducl_chr])
  edu_isced <- as.integer(.ELSA_RAEDUCL_TO_ISCED[raeducl_chr])

  # If HCAP subsample contributed raedyrs_e, prefer it
  if ("raedyrs_e" %in% names(df)) {
    raedyrs_e <- suppressWarnings(as.numeric(df$raedyrs_e))
    raedyrs_e[raedyrs_e < 0 | raedyrs_e > 22] <- NA_real_
    edu_yrs[!is.na(raedyrs_e)] <- raedyrs_e[!is.na(raedyrs_e)]
  }

  isced_to_cat <- function(i) {
    if (is.na(i))       return(NA_character_)
    if (i <= 1)         return("Primary")
    if (i == 2)         return("Lower secondary")
    if (i %in% c(3, 4)) return("Upper secondary")
    if (i >= 5)         return("Tertiary")
    NA_character_
  }
  edu_cat <- factor(vapply(edu_isced, isced_to_cat, character(1)),
                    levels = EDU_CAT_LEVELS)

  df$edu_yrs   <- edu_yrs
  df$edu_isced <- edu_isced
  df$edu_cat   <- edu_cat
  df
}

#' @keywords internal
recode_education_EU <- function(df) {
  stop("[recode_education_EU] not implemented yet (W2)")
}

#' @keywords internal
recode_education_CN <- function(df) {
  stop("[recode_education_CN] not implemented yet (W2)")
}

# ============================================================
# IN — Harmonized LASI (g2aging Version A.3)
# ============================================================
#
# Source: Harmonized LASI Codebook, Version A.3 (2017-2021).
#
# Available variables:
#   raedyrs  — continuous years of schooling (0-26)
#              Range covers Indian system extensions to Master/PhD.
#   raeducl  — 3-cat ISCED collapsed
#              1 = Less than upper secondary
#              2 = Upper secondary / vocational
#              3 = Tertiary
#
# Indian system anchors (NSO 75th round; Banks et al. 2020):
#   raeducl 1 → 4 yrs   (median primary attainment in pre-1990 cohort;
#                        large fraction of LASI sample = 0 yrs / illiterate)
#   raeducl 2 → 11 yrs  (X → XII, upper secondary completed)
#   raeducl 3 → 15 yrs  (Bachelor: typical 3-yr undergraduate)
# ------------------------------------------------------------

.LASI_RAEDUCL_TO_ISCED <- c(`1` = 2L, `2` = 3L, `3` = 6L)
.LASI_RAEDUCL_TO_YRS   <- c(`1` = 4,  `2` = 11, `3` = 15)

#' @keywords internal
recode_education_IN <- function(df) {

  if (!"raeducl" %in% names(df) && !"raedyrs" %in% names(df)) {
    stop("[recode_education_IN] need at least one of raedyrs / raeducl")
  }

  raedyrs_num <- if ("raedyrs" %in% names(df))
                   suppressWarnings(as.numeric(df$raedyrs))
                 else rep(NA_real_, nrow(df))
  raedyrs_num[raedyrs_num < 0 | raedyrs_num > 26] <- NA_real_

  raeducl_chr <- if ("raeducl" %in% names(df)) as.character(df$raeducl)
                 else rep(NA_character_, nrow(df))

  edu_yrs <- raedyrs_num
  fb <- is.na(edu_yrs) & raeducl_chr %in% names(.LASI_RAEDUCL_TO_YRS)
  edu_yrs[fb] <- .LASI_RAEDUCL_TO_YRS[raeducl_chr[fb]]

  edu_isced <- as.integer(.LASI_RAEDUCL_TO_ISCED[raeducl_chr])

  isced_from_yrs <- function(y) {
    if (is.na(y))   return(NA_integer_)
    if (y == 0)     return(0L)   # never attended (very common in LASI)
    if (y <  5)     return(1L)   # primary partial
    if (y <  8)     return(2L)   # primary completed
    if (y < 11)     return(2L)   # upper primary
    if (y < 13)     return(3L)   # secondary / higher secondary
    if (y < 15)     return(4L)   # diploma / vocational
    if (y >= 15)    return(6L)   # tertiary (UG +)
    NA_integer_
  }
  imp <- vapply(edu_yrs, isced_from_yrs, integer(1))
  edu_isced[is.na(edu_isced)] <- imp[is.na(edu_isced)]

  isced_to_cat <- function(i) {
    if (is.na(i))           return(NA_character_)
    if (i == 0)             return("Less than primary")
    if (i == 1)             return("Primary")
    if (i == 2)             return("Lower secondary")
    if (i %in% c(3, 4))     return("Upper secondary")
    if (i >= 5)             return("Tertiary")
    NA_character_
  }
  edu_cat <- factor(vapply(edu_isced, isced_to_cat, character(1)),
                    levels = EDU_CAT_LEVELS)

  df$edu_yrs   <- edu_yrs
  df$edu_isced <- edu_isced
  df$edu_cat   <- edu_cat
  df
}

# ============================================================
# MX — Harmonized MHAS (g2aging Version D)
# ============================================================
#
# Source: Harmonized MHAS Codebook, Version D (2001-2022).
#
# Available variables:
#   raedyrs  — continuous years of schooling (0-23)
#   raeducl  — 3-cat ISCED collapsed
#              1 = Less than upper secondary
#              2 = Upper secondary / vocational
#              3 = Tertiary
#
# Mexican system anchors (Wong, Michaels-Obregón, Palloni 2017;
# INEGI 2010 educational attainment):
#   raeducl 1 → 6 yrs   (primaria completed / not; modal level for cohorts
#                        born pre-1960 in rural Mexico)
#   raeducl 2 → 11 yrs  (secundaria + parcial bachillerato)
#   raeducl 3 → 16 yrs  (licenciatura / tertiary)
# raedyrs (continuous) is preferred when valid.
# ------------------------------------------------------------

.MHAS_RAEDUCL_TO_ISCED <- c(`1` = 2L, `2` = 3L, `3` = 6L)
.MHAS_RAEDUCL_TO_YRS   <- c(`1` = 6,  `2` = 11, `3` = 16)

#' @keywords internal
recode_education_MX <- function(df) {

  if (!"raeducl" %in% names(df) && !"raedyrs" %in% names(df)) {
    stop("[recode_education_MX] need at least one of raedyrs / raeducl")
  }

  raedyrs_num <- if ("raedyrs" %in% names(df))
                   suppressWarnings(as.numeric(df$raedyrs))
                 else rep(NA_real_, nrow(df))
  raedyrs_num[raedyrs_num < 0 | raedyrs_num > 23] <- NA_real_

  raeducl_chr <- if ("raeducl" %in% names(df)) as.character(df$raeducl)
                 else rep(NA_character_, nrow(df))

  edu_yrs <- raedyrs_num
  fb <- is.na(edu_yrs) & raeducl_chr %in% names(.MHAS_RAEDUCL_TO_YRS)
  edu_yrs[fb] <- .MHAS_RAEDUCL_TO_YRS[raeducl_chr[fb]]

  edu_isced <- as.integer(.MHAS_RAEDUCL_TO_ISCED[raeducl_chr])

  # If raeducl missing but raedyrs present, derive ISCED from years
  isced_from_yrs <- function(y) {
    if (is.na(y))   return(NA_integer_)
    if (y <  3)     return(0L)   # less than primary
    if (y <  6)     return(1L)   # primary partial
    if (y <  9)     return(2L)   # primary completed / lower secondary
    if (y < 12)     return(3L)   # upper secondary
    if (y < 16)     return(4L)   # post-secondary non-tertiary
    if (y >= 16)    return(6L)   # tertiary
    NA_integer_
  }
  imp <- vapply(edu_yrs, isced_from_yrs, integer(1))
  edu_isced[is.na(edu_isced)] <- imp[is.na(edu_isced)]

  isced_to_cat <- function(i) {
    if (is.na(i))           return(NA_character_)
    if (i == 0)             return("Less than primary")
    if (i == 1)             return("Primary")
    if (i == 2)             return("Lower secondary")
    if (i %in% c(3, 4))     return("Upper secondary")
    if (i >= 5)             return("Tertiary")
    NA_character_
  }
  edu_cat <- factor(vapply(edu_isced, isced_to_cat, character(1)),
                    levels = EDU_CAT_LEVELS)

  df$edu_yrs   <- edu_yrs
  df$edu_isced <- edu_isced
  df$edu_cat   <- edu_cat
  df
}
