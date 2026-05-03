# ============================================================
# helpers/schema_check.R
# ============================================================
# Defines the canonical long-format schema that all 6 cohorts MUST
# conform to before being passed to combine_5cohorts() / IPD-meta.
#
# Every prep_*_fn() must return a data.table with exactly these columns
# in exactly these types. Use validate_schema() at the end of every
# prep script to fail-fast on type / column drift.
# ============================================================

#' Canonical long-format schema for harmonized cohort data
#'
#' One row per (person × wave). Variables not collected by a given cohort
#' should be present as NA-of-correct-type, never missing as a column.
#'
#' @export
SCHEMA_VARS <- c(
  # ----- Identifiers -----
  "id",          # character — globally unique, prefixed by cohort (e.g. "HRS_1234567_01")
  "cohort",      # character — "HRS" / "ELSA" / "SHARE" / "CHARLS" / "LASI" / "MHAS"
  "country",     # character — ISO 3166 alpha-3 ("USA", "GBR", "CHN", "IND", "MEX", or one of EU codes)
  "wave",        # integer  — within-cohort wave number (1, 2, ...)
  "iyear",       # integer  — interview year (4-digit calendar year)
  # ----- Demographics -----
  "age",         # numeric  — age at interview, in years
  "sex",         # factor   — c("Male", "Female")
  "race",        # factor   — country-specific labels (collapsed where minorities <1%)
  "yob",         # integer  — year of birth (4-digit)
  "region",      # character — sub-national region (US state, UK region, CN province, etc.)
  "rural",       # integer  — 1 = rural / 0 = urban / NA = unknown
  # ----- Education (KEY EXPOSURE) -----
  "edu_yrs",     # numeric  — years of formal schooling (0-22 typical)
  "edu_isced",   # integer  — UNESCO ISCED-2011 level, 0-8
  "edu_cat",     # factor   — 5 categories (see below)
  # ----- Cognition -----
  "cog_raw",     # numeric  — cohort-native total cognition score
  "cog_z",       # numeric  — z-score within cohort × wave (mean 0, SD 1)
  # ----- Outcome (KEY) -----
  "dem_dx",      # integer  — 1 = probable dementia, 0 = no dementia, NA = unable to classify
  "cind_dx",     # integer  — 1 = CIND (cog impair, no dementia), 0 = not CIND, NA = NA
  "dem_method",  # character — algorithm used: "langa_weir_2020", "hu_2024", etc.
  # ----- Genetic (HIC subset only; NA in LMIC by design) -----
  "apoe4",       # integer  — number of APOE-ε4 alleles, 0 / 1 / 2; NA if not genotyped
  "pgs_ad",      # numeric  — z-scored polygenic score for AD (Bellenguez 2022)
  "pgs_edu"      # numeric  — z-scored polygenic score for educational attainment (Lee 2018)
)

#' Expected R type for each schema variable
#'
#' Used by validate_schema() to enforce type consistency.
SCHEMA_TYPES <- c(
  id          = "character",
  cohort      = "character",
  country     = "character",
  wave        = "integer",
  iyear       = "integer",
  age         = "numeric",
  sex         = "factor",
  race        = "factor",
  yob         = "integer",
  region      = "character",
  rural       = "integer",
  edu_yrs     = "numeric",
  edu_isced   = "integer",
  edu_cat     = "factor",
  cog_raw     = "numeric",
  cog_z       = "numeric",
  dem_dx      = "integer",
  cind_dx     = "integer",
  dem_method  = "character",
  apoe4       = "integer",
  pgs_ad      = "numeric",
  pgs_edu     = "numeric"
)

#' UNESCO ISCED-2011 5-category collapse used in edu_cat
#'
#' Mapping from edu_isced (0-8) to edu_cat:
#'   0 (early childhood)         → "Less than primary"
#'   1 (primary)                 → "Primary"
#'   2 (lower secondary)         → "Lower secondary"
#'   3-4 (upper sec / post-sec)  → "Upper secondary"
#'   5-8 (tertiary)              → "Tertiary"
EDU_CAT_LEVELS <- c(
  "Less than primary",
  "Primary",
  "Lower secondary",
  "Upper secondary",
  "Tertiary"
)

#' Validate a prepared cohort against the canonical schema
#'
#' Fails loudly (stop()) if any column missing, extra columns present,
#' types wrong, or factor levels diverge from EDU_CAT_LEVELS.
#'
#' @param df  data.frame / data.table to validate
#' @param cohort_name  e.g. "HRS"; used only in error messages
#' @return invisibly returns df if valid; else stop()
#' @export
validate_schema <- function(df, cohort_name = "<unknown>") {
  if (!inherits(df, "data.frame")) {
    stop(sprintf("[validate_schema:%s] not a data.frame", cohort_name))
  }
  cols <- names(df)

  # Missing columns
  missing_cols <- setdiff(SCHEMA_VARS, cols)
  if (length(missing_cols) > 0) {
    stop(sprintf("[validate_schema:%s] missing columns: %s",
                 cohort_name, paste(missing_cols, collapse = ", ")))
  }

  # Extra columns (warn, don't fail — useful for cohort-specific extras)
  extra_cols <- setdiff(cols, SCHEMA_VARS)
  if (length(extra_cols) > 0) {
    warning(sprintf("[validate_schema:%s] extra columns (kept): %s",
                    cohort_name, paste(extra_cols, collapse = ", ")))
  }

  # Type checks
  for (v in SCHEMA_VARS) {
    expected <- SCHEMA_TYPES[[v]]
    actual   <- class(df[[v]])[1]
    type_ok <- switch(
      expected,
      "character" = is.character(df[[v]]),
      "integer"   = is.integer(df[[v]]) || all(is.na(df[[v]])),
      "numeric"   = is.numeric(df[[v]]) || all(is.na(df[[v]])),
      "factor"    = is.factor(df[[v]])  || all(is.na(df[[v]])),
      FALSE
    )
    if (!type_ok) {
      stop(sprintf("[validate_schema:%s] column '%s' should be %s, got %s",
                   cohort_name, v, expected, actual))
    }
  }

  # edu_cat levels (only check if non-NA values exist)
  if (any(!is.na(df$edu_cat))) {
    actual_levels <- levels(df$edu_cat)
    if (!setequal(actual_levels, EDU_CAT_LEVELS)) {
      stop(sprintf(
        "[validate_schema:%s] edu_cat factor levels diverge from canonical.\n  expected: %s\n  actual:   %s",
        cohort_name, paste(EDU_CAT_LEVELS, collapse = " | "),
        paste(actual_levels,  collapse = " | ")))
    }
  }

  # Sex levels
  if (any(!is.na(df$sex))) {
    if (!setequal(levels(df$sex), c("Male", "Female"))) {
      stop(sprintf("[validate_schema:%s] sex factor must be c('Male','Female'), got: %s",
                   cohort_name, paste(levels(df$sex), collapse = ", ")))
    }
  }

  message(sprintf("[validate_schema:%s] OK — %d rows × %d cols",
                  cohort_name, nrow(df), ncol(df)))
  invisible(df)
}

#' Initialize an empty long-format tibble matching the canonical schema
#'
#' Useful for placeholders when a cohort is not yet available.
#' @export
empty_schema_df <- function(cohort_name = NA_character_) {
  data.frame(
    id          = character(0),
    cohort      = character(0),
    country     = character(0),
    wave        = integer(0),
    iyear       = integer(0),
    age         = numeric(0),
    sex         = factor(character(0), levels = c("Male", "Female")),
    race        = factor(character(0)),
    yob         = integer(0),
    region      = character(0),
    rural       = integer(0),
    edu_yrs     = numeric(0),
    edu_isced   = integer(0),
    edu_cat     = factor(character(0), levels = EDU_CAT_LEVELS),
    cog_raw     = numeric(0),
    cog_z       = numeric(0),
    dem_dx      = integer(0),
    cind_dx     = integer(0),
    dem_method  = character(0),
    apoe4       = integer(0),
    pgs_ad      = numeric(0),
    pgs_edu     = numeric(0),
    stringsAsFactors = FALSE
  )
}
