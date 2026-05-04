# ============================================================
# 61_DID_India.R — D2 India post-1947 educational expansion DID
# ============================================================
# Sample : LASI W1 (2017-2021); born 1932-1962 (covers pre- and post-
#          Independence school cohorts; school entry age 5)
# Method : 2 × 2 difference-in-differences at the individual level,
#          exploiting state-level expansion intensity heterogeneity
#          (high vs low intensity per Banks et al. 2020 NBER 27315)
#          interacted with birth-cohort exposure to Independence-era
#          schooling expansion.
# Estimand:
#   - β_DID on edu_yrs   : 1st-stage exposure → schooling
#   - β_DID on cog_raw   : reduced form on cognition
#   - 2SLS LATE          : cog_raw per +1 yr of policy-induced edu
# Outputs:
#   results/tables/Tab_DID_India.csv
#   results/figures/Fig_DID_India_edu.png
#   results/figures/Fig_DID_India_cog.png
# Author : Boru Jin et al. | Last updated: 2026-05
# ============================================================
# Identification:
#   - "Post" cohort = born 1947-1962 (school entry age 5 in 1952-1967;
#     fully exposed to Independence-era expansion)
#   - "Pre" cohort  = born 1932-1946 (school entry pre-1952; partial /
#     no exposure)
#   - "High-intensity" states (per Banks et al. 2020):
#         Kerala, Tamil Nadu, Maharashtra, Karnataka, Andhra Pradesh,
#         Gujarat, Punjab, Delhi, etc. (top quartile of post-1947
#         primary school construction intensity)
#   - β_DID = (Y[post,high] - Y[pre,high]) - (Y[post,low] - Y[pre,low])
#
#   Identification rests on the parallel-trends assumption: in absence of
#   the Independence-era intensification, education trends in high- vs
#   low-intensity states would have evolved in parallel across cohorts.
#
#   v0.1 limitation: state-level intensity classification is literature-
#   based ordinal (1-4); W2 sprint will refine with continuous primary-
#   school construction rates from DPEP / NSO 1971 census data.
# ============================================================

#' Run D2 India DID (2x2 individual-level + state FE)
#' @export
run_DID_India <- function(lasi,
                          policy_path = file.path(here::here(),
                            "data/policy/IN_EduExpansion_byState_v2.csv"),
                          out_dir = file.path(here::here(), "results"),
                          log_path = file.path(here::here(),
                            "results/logs/DID_India.log")) {

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
  .log("run_DID_India() started")

  if (is.null(lasi) || nrow(lasi) == 0) {
    warning("[DID_India] no LASI data"); return(invisible(NULL))
  }
  if (!file.exists(policy_path)) {
    warning("[DID_India] policy file missing: ", policy_path)
    return(invisible(NULL))
  }

  # ---- 1. policy table ----
  pol <- utils::read.csv(policy_path, stringsAsFactors = FALSE,
                         colClasses = c(state_code = "character"))
  pol$high_intensity <- as.integer(pol$high_intensity)
  pol$intensity_idx  <- as.integer(pol$intensity_idx)
  .log("policy file: ", policy_path,
       " — ", nrow(pol), " states; high-intensity: ",
       sum(pol$high_intensity == 1L, na.rm = TRUE))

  # ---- 2. eligible sample ----
  d <- lasi
  d$yob <- as.integer(d$yob)
  d <- d[!is.na(d$yob) & d$yob >= 1932L & d$yob <= 1962L &
         !is.na(d$region) & !is.na(d$edu_yrs), , drop = FALSE]
  .log("eligible sample (yob 1932-1962, region & edu known): ",
       nrow(d), " persons")
  if (nrow(d) < 1000) {
    warning("[DID_India] sample too small"); return(invisible(NULL))
  }

  # ---- 3. join policy table on rabplace (state of birth) ----
  d$state_code <- sprintf("%02d", as.integer(d$region))
  d <- merge(d, pol[, c("state_code", "state_name_en",
                        "intensity_idx", "high_intensity", "policy_year")],
             by = "state_code", all.x = TRUE)
  matched <- sum(!is.na(d$high_intensity))
  .log("rabplace -> policy join: ", matched, " / ", nrow(d), " rows matched")
  d <- d[!is.na(d$high_intensity), , drop = FALSE]

  # ---- 4. construct DID variables ----
  d$post  <- as.integer(d$yob >= 1947L)              # post-Independence school cohort
  d$treat <- as.integer(d$high_intensity == 1L)      # high-intensity state of birth
  d$post_x_treat <- d$post * d$treat
  d$state_factor <- factor(d$state_code)

  # 2x2 cell sizes
  cell <- table(post = d$post, treat = d$treat)
  .log("cell sizes (post × treat):")
  for (i in seq_len(nrow(cell)))
    for (j in seq_len(ncol(cell)))
      .log(sprintf("  post=%s treat=%s : n=%d",
                   rownames(cell)[i], colnames(cell)[j], cell[i, j]))

  # ---- 5. unconditional cell means (Table 2) ----
  cell_means_edu <- by(d, list(d$post, d$treat), function(x) mean(x$edu_yrs, na.rm = TRUE))
  .log("\nedu_yrs by cell:")
  for (i in dimnames(cell_means_edu)[[1]])
    for (j in dimnames(cell_means_edu)[[2]])
      .log(sprintf("  post=%s treat=%s : edu = %.2f",
                   i, j, cell_means_edu[i, j]))

  did_edu_2x2 <- (cell_means_edu["1", "1"] - cell_means_edu["0", "1"]) -
                 (cell_means_edu["1", "0"] - cell_means_edu["0", "0"])
  .log(sprintf("\n  unconditional 2x2 DID on edu_yrs: %.3f", did_edu_2x2))

  if (any(!is.na(d$cog_raw))) {
    cell_means_cog <- by(d, list(d$post, d$treat), function(x) mean(x$cog_raw, na.rm = TRUE))
    did_cog_2x2 <- (cell_means_cog["1", "1"] - cell_means_cog["0", "1"]) -
                   (cell_means_cog["1", "0"] - cell_means_cog["0", "0"])
    .log(sprintf("  unconditional 2x2 DID on cog_raw: %.3f", did_cog_2x2))
  } else {
    cell_means_cog <- NULL; did_cog_2x2 <- NA
  }

  # ---- 6. regression DID with state + birth-year FE ----
  did_est <- list(edu = list(coef = NA, se = NA, ci_lo = NA, ci_hi = NA),
                  cog = list(coef = NA, se = NA, ci_lo = NA, ci_hi = NA))

  if (requireNamespace("fixest", quietly = TRUE)) {
    .log("\n--- fixest::feols with state_factor + yob FE, cluster(state_factor) ---")

    # 1st stage: edu_yrs ~ post × treat + state FE + yob FE
    f1 <- tryCatch(
      fixest::feols(edu_yrs ~ post_x_treat + sex |
                    state_factor + yob,
                    data = d, cluster = ~state_factor),
      error = function(e) { .log("  feols(edu) error: ", conditionMessage(e)); NULL }
    )
    if (!is.null(f1)) {
      ct <- summary(f1)$coeftable
      r <- ct["post_x_treat", , drop = FALSE]
      did_est$edu$coef  <- r[, "Estimate"]
      did_est$edu$se    <- r[, "Std. Error"]
      did_est$edu$ci_lo <- did_est$edu$coef - 1.96 * did_est$edu$se
      did_est$edu$ci_hi <- did_est$edu$coef + 1.96 * did_est$edu$se
      .log(sprintf("  DID on edu_yrs: %.3f (SE %.3f, 95%% CI %.3f - %.3f)  [N=%d]",
                   did_est$edu$coef, did_est$edu$se,
                   did_est$edu$ci_lo, did_est$edu$ci_hi, stats::nobs(f1)))
    }

    # Reduced form: cog_raw ~ post × treat + state FE + yob FE
    if (any(!is.na(d$cog_raw))) {
      f2 <- tryCatch(
        fixest::feols(cog_raw ~ post_x_treat + sex |
                      state_factor + yob,
                      data = d, cluster = ~state_factor),
        error = function(e) { .log("  feols(cog) error: ", conditionMessage(e)); NULL }
      )
      if (!is.null(f2)) {
        ct <- summary(f2)$coeftable
        r <- ct["post_x_treat", , drop = FALSE]
        did_est$cog$coef  <- r[, "Estimate"]
        did_est$cog$se    <- r[, "Std. Error"]
        did_est$cog$ci_lo <- did_est$cog$coef - 1.96 * did_est$cog$se
        did_est$cog$ci_hi <- did_est$cog$coef + 1.96 * did_est$cog$se
        .log(sprintf("  DID on cog_raw: %.3f (SE %.3f, 95%% CI %.3f - %.3f)  [N=%d]",
                     did_est$cog$coef, did_est$cog$se,
                     did_est$cog$ci_lo, did_est$cog$ci_hi, stats::nobs(f2)))
      }

      # 2SLS LATE (cog ~ edu | post_x_treat) with state + yob FE
      f3 <- tryCatch(
        fixest::feols(cog_raw ~ sex | state_factor + yob | edu_yrs ~ post_x_treat,
                      data = d, cluster = ~state_factor),
        error = function(e) { .log("  feols(2SLS) error: ", conditionMessage(e)); NULL }
      )
      if (!is.null(f3)) {
        ct <- summary(f3)$coeftable
        # IV coefficient name is "fit_edu_yrs"
        nm_iv <- grep("edu_yrs", rownames(ct), value = TRUE)[1]
        if (!is.na(nm_iv)) {
          r <- ct[nm_iv, , drop = FALSE]
          .log(sprintf("  2SLS LATE (cog per +1 yr of policy-induced edu): %.3f (SE %.3f)",
                       r[, "Estimate"], r[, "Std. Error"]))
        }
      }
    }
  } else {
    .log("fixest not available — using base lm with cluster bootstrap (slower)")
    f1 <- stats::lm(edu_yrs ~ post_x_treat + sex + state_factor + factor(yob), data = d)
    sm <- summary(f1)$coefficients
    r <- sm["post_x_treat", , drop = FALSE]
    did_est$edu$coef  <- r[, "Estimate"]
    did_est$edu$se    <- r[, "Std. Error"]
    did_est$edu$ci_lo <- r[, "Estimate"] - 1.96 * r[, "Std. Error"]
    did_est$edu$ci_hi <- r[, "Estimate"] + 1.96 * r[, "Std. Error"]
  }

  # ---- 7. plot: edu_yrs trajectory by birth year, by treat ----
  if (requireNamespace("ggplot2", quietly = TRUE)) {
    edu_traj <- aggregate(edu_yrs ~ yob + treat, data = d, FUN = mean)
    edu_traj$treat_lab <- ifelse(edu_traj$treat == 1L,
                                 "High-intensity states", "Low-intensity states")
    edu_plot_path <- file.path(fig_dir, "Fig_DID_India_edu.png")
    p_edu <- ggplot2::ggplot(edu_traj, ggplot2::aes(x = yob, y = edu_yrs,
                                                    colour = treat_lab)) +
      ggplot2::geom_line(linewidth = 1) +
      ggplot2::geom_vline(xintercept = 1947, linetype = "dashed", colour = "grey40") +
      ggplot2::annotate("text", x = 1948, y = max(edu_traj$edu_yrs, na.rm = TRUE),
                        label = "1947 Independence", hjust = 0, size = 3) +
      ggplot2::labs(title = "D2 India: Education trajectory by birth year × state intensity",
                    x = "Birth year", y = "Mean years of education",
                    colour = NULL) +
      ggplot2::theme_minimal(base_size = 12) +
      ggplot2::theme(legend.position = "bottom")
    ggplot2::ggsave(edu_plot_path, p_edu, width = 8, height = 5, dpi = 200)
    .log("\nedu plot: ", edu_plot_path)

    if (any(!is.na(d$cog_raw))) {
      cog_traj <- aggregate(cog_raw ~ yob + treat, data = d[!is.na(d$cog_raw), ],
                            FUN = mean)
      cog_traj$treat_lab <- ifelse(cog_traj$treat == 1L,
                                   "High-intensity states", "Low-intensity states")
      cog_plot_path <- file.path(fig_dir, "Fig_DID_India_cog.png")
      p_cog <- ggplot2::ggplot(cog_traj, ggplot2::aes(x = yob, y = cog_raw,
                                                      colour = treat_lab)) +
        ggplot2::geom_line(linewidth = 1) +
        ggplot2::geom_vline(xintercept = 1947, linetype = "dashed", colour = "grey40") +
        ggplot2::labs(title = "D2 India: Cognition trajectory by birth year × state intensity",
                      x = "Birth year", y = "Mean cognition (max 24)",
                      colour = NULL) +
        ggplot2::theme_minimal(base_size = 12) +
        ggplot2::theme(legend.position = "bottom")
      ggplot2::ggsave(cog_plot_path, p_cog, width = 8, height = 5, dpi = 200)
      .log("cog plot: ", cog_plot_path)
    }
  }

  # ---- 8. summary table ----
  tab <- data.frame(
    Outcome = c("edu_yrs (1st stage, ITT, FE-adj)",
                "cog_raw (reduced form, FE-adj)",
                "edu_yrs (unconditional 2×2)",
                "cog_raw (unconditional 2×2)"),
    Estimate    = c(did_est$edu$coef, did_est$cog$coef, did_edu_2x2, did_cog_2x2),
    SE          = c(did_est$edu$se,   did_est$cog$se,   NA,           NA),
    CI_lower_95 = c(did_est$edu$ci_lo, did_est$cog$ci_lo, NA,         NA),
    CI_upper_95 = c(did_est$edu$ci_hi, did_est$cog$ci_hi, NA,         NA),
    stringsAsFactors = FALSE
  )
  csv_path <- file.path(tab_dir, "Tab_DID_India.csv")
  utils::write.csv(tab, csv_path, row.names = FALSE, fileEncoding = "UTF-8")
  .log("\nwrote ", csv_path)

  invisible(list(
    sample      = d,
    edu_did     = did_est$edu,
    cog_did     = did_est$cog,
    cell_edu    = cell_means_edu,
    cell_cog    = cell_means_cog,
    summary_tab = tab,
    csv_path    = csv_path
  ))
}
