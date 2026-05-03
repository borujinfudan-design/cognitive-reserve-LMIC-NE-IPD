# ============================================================
# helpers/derive_dementia.R
# ============================================================
# Harmonized dementia / cognitive-impairment outcome derivation
# Methods supported:
#  - "langa_weir_2020" : HRS standard algorithm (sensitivity ~0.85, spec ~0.90)
#  - "hurd_2013"        : alternative HRS (informant-corrected)
#  - "hu_2024"          : CHARLS-validated cut-points (per JAMA Netw Open 2024)
#  - "lasidad_2020"     : LASI-DAD imputation model
#  - "hcap_clinical"    : gold-standard adjudication (HRS-HCAP, ELSA-HCAP)
# ============================================================

derive_dementia <- function(df, method = c("langa_weir_2020",
                                            "hurd_2013",
                                            "hu_2024",
                                            "lasidad_2020",
                                            "hcap_clinical")) {
  method <- match.arg(method)
  # TODO[W2-3]: method-specific scoring + cutpoints
  df
}
