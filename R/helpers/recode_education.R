# ============================================================
# helpers/recode_education.R
# ============================================================
# Cross-cohort harmonization to UNESCO ISCED-2011 (years of schooling)
# Country-specific lookup tables embedded; see Methods S3.1
# ============================================================

recode_education <- function(df, country = c("USA", "UK", "EU", "CN", "IN", "MX")) {
  country <- match.arg(country)
  # TODO[W1.3]: country-specific recode lookups
  #   USA: raedyrs (already years)
  #   UK : edqual / edyears (ELSA wave-specific)
  #   EU : isced2011 → years per country offset
  #   CN : ba009_w?  → 0/6/9/12/15/16/18 mapping per CHARLS code book
  #   IN : sa006_lasi → 0/5/8/10/12/14/15 mapping per LASI code book
  #   MX : edu_lvl_mhas → years
  df
}
