# ============================================================
# 60_RDD_China.R — D1: 1986 Compulsory Schooling Law fuzzy RDD
# ============================================================
# Sample : CHARLS Life History 2014 + main wave cognition; born 1962-1982
#          (turned age 14 in 1976-1996; 1986 cutoff = born 1972)
# Method : rdrobust::rdrobust + rddensity::rddensity (McCrary)
# Estimand: LATE on edu years AND on z-cognition at threshold
# Outputs: results/tables/Tab2_RDD_China.csv, results/figures/Fig2_RDD.pdf
# ============================================================

run_RDD_China <- function(charls) {
  # TODO[W4]: full RDD with bandwidth selection, kink check, donut hole sens
  invisible(NULL)
}
