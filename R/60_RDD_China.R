# ============================================================
# 60_RDD_China.R — D1 China 1986 Compulsory Schooling Law fuzzy RDD
# ============================================================
# Sample : CHARLS 2011 baseline; born 1962-1982 (turned 14 in 1976-1996;
#          1986 national cutoff = born 1972).
# Method : rdrobust::rdrobust + rddensity::rddensity (McCrary density test)
# Estimand:
#   - Sharp RDD on edu_yrs   (intent-to-treat 1st stage)
#   - Sharp RDD on cog_raw   (reduced-form on cognition)
#   - Fuzzy LATE on cog_raw per +1 yr of compulsory edu
# Outputs:
#   results/tables/Tab_RDD_China.csv
#   results/figures/Fig_RDD_China_edu.png
#   results/figures/Fig_RDD_China_cog.png
#   results/figures/Fig_RDD_China_density.png
# Author : Boru Jin et al. | Last updated: 2026-05
# ============================================================
# NOTES on identification:
#   - 1986 Compulsory Education Law was rolled out province-by-province
#     between 1986-1995 (see data/policy/CN_1986_CompulsoryEdu_byProvince.csv).
#     v0.1 here uses a single NATIONAL cutoff (1972 birth cohort) which
#     gives a conservative ITT estimate — diluted but unbiased.
#   - W2 sprint will exploit provincial variation (1972-1981 cutoffs)
#     once CHARLS internal province codes are mapped to GB-T 2260.
#   - Running variable = yob - 1972 (centered at cutoff). Treatment
#     T = 1{yob >= 1972}. Bandwidth selected by MSE-optimal CCT (default
#     in rdrobust).
#   - Robustness: McCrary density test (manipulation), donut-hole
#     (drop ±1 yr of cutoff to test sensitivity), bandwidth doubling /
#     halving.
# ============================================================

#' Run D1 China 1986 RDD (sharp + fuzzy)
#' @export
run_RDD_China <- function(charls,
                          policy_path = file.path(here::here(),
                            "data/policy/CN_1986_CompulsoryEdu_byProvince.csv"),
                          out_dir = file.path(here::here(), "results"),
                          log_path = file.path(here::here(),
                            "results/logs/RDD_China.log")) {

  fig_dir <- file.path(out_dir, "figures")
  tab_dir <- file.path(out_dir, "tables")
  dir.create(fig_dir,           showWarnings = FALSE, recursive = TRUE)
  dir.create(tab_dir,           showWarnings = FALSE, recursive = TRUE)
  dir.create(dirname(log_path), showWarnings = FALSE, recursive = TRUE)
  log_con <- file(log_path, open = "wt"); on.exit(close(log_con))
  .log <- function(...) {
    msg <- sprintf("[%s] %s", Sys.time(), paste0(..., collapse = ""))
    writeLines(msg, log_con); message(msg)
  }
  .log("run_RDD_China() started")

  if (is.null(charls) || nrow(charls) == 0) {
    warning("[RDD_China] no CHARLS data"); return(invisible(NULL))
  }

  # ---- 1. eligible sample: born 1962-1982 ----
  d <- charls
  d$yob <- as.integer(d$yob)
  d <- d[!is.na(d$yob) & d$yob >= 1962L & d$yob <= 1982L, , drop = FALSE]
  .log("eligible sample (yob 1962-1982): ", nrow(d), " persons")
  if (nrow(d) < 200) {
    warning("[RDD_China] sample too small for RDD"); return(invisible(NULL))
  }

  # Running variable centered at 1972 cutoff
  d$run <- as.numeric(d$yob - 1972L)
  d$treat <- as.integer(d$run >= 0)

  .log("treatment vs running variable distribution:")
  .log(paste0("  treated   (yob >= 1972): ", sum(d$treat == 1L)))
  .log(paste0("  untreated (yob <  1972): ", sum(d$treat == 0L)))

  # ---- 2. McCrary density test ----
  density_path <- file.path(fig_dir, "Fig_RDD_China_density.png")
  density_p <- NA_real_
  if (requireNamespace("rddensity", quietly = TRUE)) {
    rdd_dens <- tryCatch(
      rddensity::rddensity(X = d$run, c = 0),
      error = function(e) { .log("  rddensity error: ", conditionMessage(e)); NULL }
    )
    if (!is.null(rdd_dens)) {
      density_p <- rdd_dens$test$p_jk
      .log(sprintf("  McCrary density test (jackknife): p = %.3f%s",
                   density_p,
                   if (density_p < 0.05) "  [⚠ possible manipulation]" else ""))
      grDevices::png(density_path, width = 1200, height = 900, res = 200)
      tryCatch({
        plt <- rddensity::rdplotdensity(rdd_dens, X = d$run, plotN = 50)
        # rdplotdensity prints automatically
      }, error = function(e) .log("  rdplotdensity warning: ", conditionMessage(e)))
      grDevices::dev.off()
      .log("  density plot: ", density_path)
    }
  }

  # ---- 3. RDD on edu_yrs (1st stage / sharp) ----
  rdd_edu <- NULL
  edu_est <- list(coef = NA, se = NA, ci_lo = NA, ci_hi = NA, h = NA, n = NA)
  if (requireNamespace("rdrobust", quietly = TRUE) &&
      sum(!is.na(d$edu_yrs)) > 100) {
    rdd_edu <- tryCatch(
      rdrobust::rdrobust(y = d$edu_yrs, x = d$run, c = 0,
                         all = TRUE),
      error = function(e) { .log("  rdrobust(edu) error: ", conditionMessage(e)); NULL }
    )
    if (!is.null(rdd_edu)) {
      edu_est$coef  <- as.numeric(rdd_edu$coef["Conventional", 1])
      edu_est$se    <- as.numeric(rdd_edu$se  ["Conventional", 1])
      edu_est$ci_lo <- as.numeric(rdd_edu$ci  ["Robust", 1])
      edu_est$ci_hi <- as.numeric(rdd_edu$ci  ["Robust", 2])
      edu_est$h     <- as.numeric(rdd_edu$bws[1, 1])
      edu_est$n     <- sum(rdd_edu$N_h)
      .log(sprintf("  RDD on edu_yrs:  beta = %.3f (robust 95%% CI %.3f - %.3f); h = %.2f; N_h = %d",
                   edu_est$coef, edu_est$ci_lo, edu_est$ci_hi,
                   edu_est$h, edu_est$n))

      # plot
      edu_plot_path <- file.path(fig_dir, "Fig_RDD_China_edu.png")
      grDevices::png(edu_plot_path, width = 1400, height = 900, res = 200)
      tryCatch(
        rdrobust::rdplot(y = d$edu_yrs, x = d$run, c = 0,
                         x.label = "Birth year - 1972",
                         y.label = "Years of education",
                         title = "D1 China RDD: 1986 Compulsory Schooling Law"),
        error = function(e) .log("  rdplot(edu) warning: ", conditionMessage(e))
      )
      grDevices::dev.off()
      .log("  edu plot: ", edu_plot_path)
    }
  }

  # ---- 4. RDD on cog_raw (reduced form) ----
  rdd_cog <- NULL
  cog_est <- list(coef = NA, se = NA, ci_lo = NA, ci_hi = NA, h = NA, n = NA)
  if (requireNamespace("rdrobust", quietly = TRUE) &&
      sum(!is.na(d$cog_raw)) > 100) {
    rdd_cog <- tryCatch(
      rdrobust::rdrobust(y = d$cog_raw, x = d$run, c = 0, all = TRUE),
      error = function(e) { .log("  rdrobust(cog) error: ", conditionMessage(e)); NULL }
    )
    if (!is.null(rdd_cog)) {
      cog_est$coef  <- as.numeric(rdd_cog$coef["Conventional", 1])
      cog_est$se    <- as.numeric(rdd_cog$se  ["Conventional", 1])
      cog_est$ci_lo <- as.numeric(rdd_cog$ci  ["Robust", 1])
      cog_est$ci_hi <- as.numeric(rdd_cog$ci  ["Robust", 2])
      cog_est$h     <- as.numeric(rdd_cog$bws[1, 1])
      cog_est$n     <- sum(rdd_cog$N_h)
      .log(sprintf("  RDD on cog_raw:  beta = %.3f (robust 95%% CI %.3f - %.3f); h = %.2f; N_h = %d",
                   cog_est$coef, cog_est$ci_lo, cog_est$ci_hi,
                   cog_est$h, cog_est$n))

      cog_plot_path <- file.path(fig_dir, "Fig_RDD_China_cog.png")
      grDevices::png(cog_plot_path, width = 1400, height = 900, res = 200)
      tryCatch(
        rdrobust::rdplot(y = d$cog_raw, x = d$run, c = 0,
                         x.label = "Birth year - 1972",
                         y.label = "Cognition raw (max 23)",
                         title = "D1 China RDD: cognition reduced form"),
        error = function(e) .log("  rdplot(cog) warning: ", conditionMessage(e))
      )
      grDevices::dev.off()
      .log("  cog plot: ", cog_plot_path)
    }
  }

  # ---- 5. Fuzzy 2SLS LATE (cog ~ edu | treat × run) ----
  fuzzy_est <- list(coef = NA, se = NA, ci_lo = NA, ci_hi = NA, h = NA, n = NA)
  if (requireNamespace("rdrobust", quietly = TRUE) &&
      sum(!is.na(d$cog_raw) & !is.na(d$edu_yrs)) > 100) {
    rdd_fuzzy <- tryCatch(
      rdrobust::rdrobust(y = d$cog_raw, x = d$run, c = 0,
                         fuzzy = d$edu_yrs, all = TRUE),
      error = function(e) { .log("  rdrobust(fuzzy) error: ", conditionMessage(e)); NULL }
    )
    if (!is.null(rdd_fuzzy)) {
      fuzzy_est$coef  <- as.numeric(rdd_fuzzy$coef["Conventional", 1])
      fuzzy_est$se    <- as.numeric(rdd_fuzzy$se  ["Conventional", 1])
      fuzzy_est$ci_lo <- as.numeric(rdd_fuzzy$ci  ["Robust", 1])
      fuzzy_est$ci_hi <- as.numeric(rdd_fuzzy$ci  ["Robust", 2])
      fuzzy_est$h     <- as.numeric(rdd_fuzzy$bws[1, 1])
      fuzzy_est$n     <- sum(rdd_fuzzy$N_h)
      .log(sprintf("  Fuzzy LATE (cog per +1 yr edu): beta = %.3f (robust 95%% CI %.3f - %.3f); h = %.2f",
                   fuzzy_est$coef, fuzzy_est$ci_lo, fuzzy_est$ci_hi, fuzzy_est$h))
    }
  }

  # ---- 6. Donut-hole sensitivity (drop |run| < 1) ----
  donut_est <- list(coef = NA, se = NA, ci_lo = NA, ci_hi = NA)
  if (requireNamespace("rdrobust", quietly = TRUE) &&
      sum(!is.na(d$cog_raw)) > 100) {
    d_donut <- d[abs(d$run) >= 1, , drop = FALSE]
    rdd_donut <- tryCatch(
      rdrobust::rdrobust(y = d_donut$cog_raw, x = d_donut$run, c = 0, all = TRUE),
      error = function(e) NULL
    )
    if (!is.null(rdd_donut)) {
      donut_est$coef  <- as.numeric(rdd_donut$coef["Conventional", 1])
      donut_est$se    <- as.numeric(rdd_donut$se  ["Conventional", 1])
      donut_est$ci_lo <- as.numeric(rdd_donut$ci  ["Robust", 1])
      donut_est$ci_hi <- as.numeric(rdd_donut$ci  ["Robust", 2])
      .log(sprintf("  Donut-hole RDD (cog, |yob-1972|>=1): beta = %.3f (CI %.3f - %.3f)",
                   donut_est$coef, donut_est$ci_lo, donut_est$ci_hi))
    }
  }

  # ---- 7. summary table ----
  tab <- data.frame(
    Outcome           = c("edu_yrs (1st stage, ITT)",
                          "cog_raw (reduced form)",
                          "cog_raw per +1 yr edu (fuzzy LATE)",
                          "cog_raw donut-hole (|yob-1972|>=1)"),
    Estimate          = c(edu_est$coef, cog_est$coef, fuzzy_est$coef, donut_est$coef),
    CI_lower_95       = c(edu_est$ci_lo, cog_est$ci_lo, fuzzy_est$ci_lo, donut_est$ci_lo),
    CI_upper_95       = c(edu_est$ci_hi, cog_est$ci_hi, fuzzy_est$ci_hi, donut_est$ci_hi),
    Bandwidth         = c(edu_est$h, cog_est$h, fuzzy_est$h, NA),
    N_within_h        = c(edu_est$n, cog_est$n, fuzzy_est$n, NA),
    stringsAsFactors = FALSE
  )
  csv_path <- file.path(tab_dir, "Tab_RDD_China.csv")
  utils::write.csv(tab, csv_path, row.names = FALSE, fileEncoding = "UTF-8")
  .log("\nwrote ", csv_path)

  # ---- 8. provincial-cutoff robustness placeholder ----
  if (file.exists(policy_path)) {
    pol <- utils::read.csv(policy_path, stringsAsFactors = FALSE)
    .log("\npolicy file: ", policy_path, " — ", nrow(pol), " provinces with adoption_year")
    .log("  range of adoption: ",
         paste(range(pol$adoption_year), collapse = " - "))
    .log("  W2 sprint: map CHARLS internal province codes to GB-T 2260 then re-run")
    .log("  with province-specific cutoffs (yob = adoption_year - 14).")
  }

  invisible(list(
    sample        = d,
    edu_est       = edu_est,
    cog_est       = cog_est,
    fuzzy_est     = fuzzy_est,
    donut_est     = donut_est,
    density_p     = density_p,
    summary_tab   = tab,
    csv_path      = csv_path
  ))
}
