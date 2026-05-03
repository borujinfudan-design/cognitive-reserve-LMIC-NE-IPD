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

#' @keywords internal
recode_education_UK <- function(df) {
  stop("[recode_education_UK] not implemented yet (W2)")
}

#' @keywords internal
recode_education_EU <- function(df) {
  stop("[recode_education_EU] not implemented yet (W2)")
}

#' @keywords internal
recode_education_CN <- function(df) {
  stop("[recode_education_CN] not implemented yet (W2)")
}

#' @keywords internal
recode_education_IN <- function(df) {
  stop("[recode_education_IN] not implemented yet (W2)")
}

#' @keywords internal
recode_education_MX <- function(df) {
  stop("[recode_education_MX] not implemented yet (W2)")
}
