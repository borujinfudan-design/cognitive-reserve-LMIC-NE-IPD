# ============================================================
# 30_main_cox_per_cohort.R — D3 stage 1: per-cohort Cox PH
# ============================================================
# Inputs : combined_5cohorts (long-format with t_in, t_out, dem_dx, edu_yrs)
# Outputs: cox_per_cohort (list of coxph fits + tidy results)
# ============================================================

run_cox_per_cohort <- function(combined) {
  # TODO[W3]: per-country survival::coxph(Surv(t_in, t_out, event) ~
  #             edu_yrs + age0 + sex + apoe4 + cluster(id))
  invisible(NULL)
}
