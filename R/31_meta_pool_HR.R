# ============================================================
# 31_meta_pool_HR.R — D3 stage 2: random-effects meta on log(HR)
# ============================================================
# Inputs : cox_per_cohort (per-country yi, vi)
# Outputs: meta_pooled (rma object), forest plot, funnel plot
# ============================================================

pool_HR_meta <- function(cox_per_cohort) {
  # TODO[W3]: metafor::rma(yi = log_HR, vi = se^2, method = "REML")
  #            + influence diagnostics + leave-one-out
  invisible(NULL)
}
