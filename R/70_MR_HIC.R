# ============================================================
# 70_MR_HIC.R — D4: 2-sample Mendelian randomization (HIC subset)
# ============================================================
# Exposure GWAS: Lee et al. 2018 (educational attainment, N ~ 1.1M, EUR)
# Outcome  GWAS: Bellenguez et al. 2022 (Alzheimer's disease, N ~ 788k, EUR)
# Method   : IVW + MR-Egger + weighted median + MR-PRESSO + radial MR
# Outputs  : results/tables/Tab4_MR.csv, results/figures/Fig4_MR.pdf
# Note     : Restricted to HIC (HRS + ELSA + SHARE) per population overlap
# ============================================================

run_MR_HIC <- function() {
  # TODO[W3-4]: TwoSampleMR pipeline using IEU OpenGWAS IDs
  #             ieu-a-1239 (Lee 2018) + ebi-a-GCST90027158 (Bellenguez 2022)
  invisible(NULL)
}
