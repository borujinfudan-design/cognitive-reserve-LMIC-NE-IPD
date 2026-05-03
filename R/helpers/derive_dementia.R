# ============================================================
# helpers/derive_dementia.R
# ============================================================
# Harmonized dementia / cognitive-impairment outcome derivation
#
# Implemented method (langa_weir_2020):
#   Reference: Langa-Weir Classification of Cognitive Function
#              (HRS researcher-contributed dataset, 1995-2020)
#              https://hrsdata.isr.umich.edu/data-products/langa-weir-classification-cognitive-function-1995-2020
#
#   The 27-point cognition scale (self-respondents, age 65+):
#     - Immediate word recall      (0-10)
#     - Delayed word recall        (0-10)
#     - Serial 7s subtraction      (0-5)
#     - Backwards counting from 20 (0-2)
#     ──────────────────────────────────
#     TOTAL                        (0-27)
#
#   Cutpoints (self-respondents):
#     0-6   → Probable dementia
#     7-11  → CIND (cognitively impaired, not demented)
#     12-27 → Normal cognition
#
#   Proxy respondents (separate scale; not implemented in v1 — gives
#   NA. Will be added in W2 once we confirm proxy variable names in
#   g2aging Harmonized HRS d.)
# ============================================================

#' Derive dementia / CIND outcome from cohort cognition variables
#'
#' @param df       data.frame with cohort-native cognition columns
#' @param method   one of: "langa_weir_2020", "hurd_2013", "hu_2024",
#'                 "lasidad_2020", "hcap_clinical"
#' @return same df with three new columns:
#'           dem_dx     1 = probable dementia, 0 = no dementia, NA otherwise
#'           cind_dx    1 = CIND, 0 = not CIND, NA otherwise
#'           dem_method character — algorithm used
#' @export
derive_dementia <- function(df,
                            method = c("langa_weir_2020",
                                       "hurd_2013",
                                       "hu_2024",
                                       "lasidad_2020",
                                       "hcap_clinical")) {
  method <- match.arg(method)
  switch(method,
    langa_weir_2020 = derive_dementia_LW2020(df),
    hurd_2013       = stop("[derive_dementia] hurd_2013 not implemented (W2)"),
    hu_2024         = stop("[derive_dementia] hu_2024 not implemented (W2 — for CHARLS)"),
    lasidad_2020    = stop("[derive_dementia] lasidad_2020 not implemented (W2 — for LASI)"),
    hcap_clinical   = stop("[derive_dementia] hcap_clinical not implemented (W3)")
  )
}

# ============================================================
# Langa-Weir 2020 implementation (HRS / ELSA TICS-27)
# ============================================================

#' Score the 27-point Langa-Weir cognition scale
#'
#' Builds the total cognition score from its 4 component scores. Components
#' may be present as a single pre-computed total (`cog_raw`) or as separate
#' subscores (`imrc`, `dlrc`, `ser7`, `bwc20`). If neither is available,
#' returns NA.
#'
#' @param df data.frame; expects either `cog_raw` (preferred) OR all 4 of
#'           `imrc`, `dlrc`, `ser7`, `bwc20`.
#' @return numeric vector of TICS-27 totals (0-27), NA where uncomputable
#' @keywords internal
.score_LW27 <- function(df) {

  # Path 1: pre-computed total (g2aging variable r{w}cogtot)
  if ("cog_raw" %in% names(df) && any(!is.na(df$cog_raw))) {
    s <- as.numeric(df$cog_raw)
    s[s < 0 | s > 27] <- NA_real_
    return(s)
  }

  # Path 2: build from components
  comps <- c("imrc", "dlrc", "ser7", "bwc20")
  missing_comps <- setdiff(comps, names(df))
  if (length(missing_comps) == 0) {
    imrc  <- pmax(0, pmin(10, suppressWarnings(as.numeric(df$imrc))))
    dlrc  <- pmax(0, pmin(10, suppressWarnings(as.numeric(df$dlrc))))
    ser7  <- pmax(0, pmin(5,  suppressWarnings(as.numeric(df$ser7))))
    bwc20 <- pmax(0, pmin(2,  suppressWarnings(as.numeric(df$bwc20))))
    return(imrc + dlrc + ser7 + bwc20)
  }

  warning("[.score_LW27] neither cog_raw nor (imrc,dlrc,ser7,bwc20) available — returning NA")
  rep(NA_real_, nrow(df))
}

#' Apply Langa-Weir 2020 cutpoints
#'
#' @param tot numeric — TICS-27 total (0-27)
#' @return list with `dem_dx` (1/0/NA) and `cind_dx` (1/0/NA)
#' @keywords internal
.classify_LW2020 <- function(tot) {
  dem_dx  <- ifelse(is.na(tot), NA_integer_,
              ifelse(tot >= 0  & tot <=  6, 1L,
              ifelse(tot >= 7  & tot <= 27, 0L, NA_integer_)))
  cind_dx <- ifelse(is.na(tot), NA_integer_,
              ifelse(tot >= 7  & tot <= 11, 1L,
              ifelse(tot >= 0  & tot <= 27, 0L, NA_integer_)))
  list(dem_dx = dem_dx, cind_dx = cind_dx)
}

#' @keywords internal
derive_dementia_LW2020 <- function(df) {
  tot <- .score_LW27(df)
  cls <- .classify_LW2020(tot)

  # Note: HRS gold standard restricts to age 65+. Younger respondents
  # are not classified by Langa-Weir (mark as NA).
  if ("age" %in% names(df)) {
    young <- !is.na(df$age) & df$age < 65
    cls$dem_dx[young]  <- NA_integer_
    cls$cind_dx[young] <- NA_integer_
  }

  df$cog_raw    <- tot                                   # ensure cog_raw is set
  df$dem_dx     <- as.integer(cls$dem_dx)
  df$cind_dx    <- as.integer(cls$cind_dx)
  df$dem_method <- "langa_weir_2020"

  df
}
