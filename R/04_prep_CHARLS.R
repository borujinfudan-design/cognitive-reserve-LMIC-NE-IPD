# ============================================================
# 04_prep_CHARLS.R — China Health and Retirement Longitudinal Study
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

prep_CHARLS_fn <- function(
  raw_dir = file.path(here::here(), "data/raw/CHARLS"),
  out_dir = file.path(here::here(), "data/derived")
) {

  # ---------- 1. read all waves ----------
  # TODO[W2]: implement wave-by-wave merge from these subdirs:
  #   01_2011_baseline/  (Demographic_Background.dta, Cognition.dta, ...)
  #   02_2013_wave2/
  #   03_2014_LifeHistory/  (← CRITICAL for retrospective edu year + birth year)
  #   04_2015_wave3/
  #   05_2018_wave4/
  #   06_2020_wave5/
  #   07_COVID/
  #   08_2024_wave6/

  # ---------- 2. derive year of education + year of birth ----------
  # TODO[W2]: priority source = Life History 2014 self-report
  #           fallback        = baseline edu_attain → typical years

  # ---------- 3. derive cognition score (TICS + word recall) ----------
  # TODO[W2]: harmonize across waves to single z-score per HCAP-China standard

  # ---------- 4. derive dementia (proxy: Hu et al. 2024 algorithm) ----------
  # NOTE: CHARLS has NO clinical dementia adjudication; we use Hu et al. JAMA
  #       Network Open 2024 cognitive impairment algorithm (sens/spec from HCAP)

  # ---------- 5. RDD-specific: birth year ± 5 around 1972 (turned 14 in 1986) ----------
  # TODO[W3]: filter to RDD analytical sample for D1

  invisible(NULL)
}
