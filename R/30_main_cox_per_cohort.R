# ============================================================
# 30_main_cox_per_cohort.R — D3 stage 1: per-cohort survival modelling
# ============================================================
# Inputs : combined_5cohorts (long-format)
# Outputs: list with $cox (per-cohort coxph fits + tidy results) and
#          $logit (per-cohort prevalent-dementia logistic for single-wave)
# Author : Boru Jin et al. | Last updated: 2026-05
# ============================================================
# Strategy:
#
#   Multi-wave cohorts (HRS, ELSA, MHAS):
#     1. Restrict to age ≥ 65 person-waves with classifiable dem_dx.
#     2. Define baseline = first wave each person is dementia-free at age 65+.
#     3. Drop prevalent dementia at baseline (Cox is incident dementia).
#     4. Event time scale = AGE (left-truncation at age_baseline,
#        right-censoring at age_last_obs or age_first_dx).
#     5. Per cohort: coxph(Surv(age0, age_t, dem_event) ~ edu_yrs + sex
#                          + strata(yob_5yr) + cluster(pid)).
#     6. Tidy results → tibble of (cohort, term, log_HR, se, HR, ci, n).
#
#   Single-wave cohorts (CHARLS, LASI):
#     Logistic regression on prevalent dementia at age ≥ 65:
#       glm(dem_dx ~ edu_yrs + age + sex + region, family = binomial)
#     Reported separately; NOT pooled with Cox HRs.
#
#   This produces the per-cohort log_HR / se for `pool_HR_meta()`.
# ============================================================

#' Run per-cohort survival models for incident dementia
#' @export
run_cox_per_cohort <- function(combined,
                               log_path = file.path(here::here(),
                                                    "results/logs/cox_per_cohort.log")) {

  dir.create(dirname(log_path), showWarnings = FALSE, recursive = TRUE)
  log_con <- file(log_path, open = "wt"); on.exit(close(log_con))
  .log <- function(...) {
    msg <- sprintf("[%s] %s", Sys.time(), paste0(..., collapse = ""))
    writeLines(msg, log_con); message(msg)
  }
  .log("run_cox_per_cohort() started")

  if (is.null(combined) || nrow(combined) == 0) {
    warning("[run_cox_per_cohort] empty input; skipping")
    return(invisible(NULL))
  }

  combined$pid <- sub("_w[0-9]+$", "", combined$id)
  cohorts <- sort(unique(combined$cohort))
  .log("cohorts: ", paste(cohorts, collapse = ", "))

  cox_results   <- list()
  logit_results <- list()
  cox_tidy      <- list()
  logit_tidy    <- list()

  for (c in cohorts) {
    d <- combined[combined$cohort == c & !is.na(combined$age) &
                  combined$age >= 65 & !is.na(combined$dem_dx) &
                  !is.na(combined$edu_yrs), , drop = FALSE]
    if (nrow(d) < 100) {
      .log("[", c, "] fewer than 100 eligible rows; skip")
      next
    }
    n_persons <- length(unique(d$pid))
    n_waves   <- length(unique(d$wave))
    .log("[", c, "] eligible (age>=65, dem_dx & edu_yrs known): ",
         nrow(d), " rows, ", n_persons, " persons, ", n_waves, " waves")

    if (n_waves >= 2) {
      # ---- multi-wave cohort: incident-dementia Cox ----
      d <- d[order(d$pid, d$wave), , drop = FALSE]

      # Drop persons who are demented at first eligible wave (prevalent)
      first_wave <- !duplicated(d$pid)
      prevalent_pids <- d$pid[first_wave & d$dem_dx == 1L]
      d_inc <- d[!d$pid %in% prevalent_pids, , drop = FALSE]
      .log("  prevalent dementia at baseline excluded: ",
           length(prevalent_pids), " persons; incident-eligible: ",
           length(unique(d_inc$pid)))

      # Build (start, stop, event) intervals on AGE scale
      d_inc <- d_inc[order(d_inc$pid, d_inc$wave), , drop = FALSE]

      # For each person: ordered ages, ordered dem_dx
      surv_df <- do.call(rbind, lapply(split(d_inc, d_inc$pid), function(s) {
        if (nrow(s) < 2) return(NULL)  # need at least 2 obs for time interval
        ages <- s$age
        dems <- s$dem_dx
        # construct (start, stop, event)
        starts <- ages[-length(ages)]
        stops  <- ages[-1]
        events <- as.integer(dems[-1] == 1L)
        # Once first event occurs, truncate later intervals
        first_event <- which(events == 1L)[1]
        if (!is.na(first_event)) {
          starts <- starts[1:first_event]
          stops  <- stops[1:first_event]
          events <- events[1:first_event]
        }
        # Drop intervals with non-positive duration
        keep <- !is.na(starts) & !is.na(stops) & stops > starts
        if (!any(keep)) return(NULL)
        data.frame(
          pid     = s$pid[1],
          cohort  = s$cohort[1],
          start   = starts[keep],
          stop    = stops[keep],
          event   = events[keep],
          edu_yrs = s$edu_yrs[1],
          sex     = s$sex[1],
          yob5    = if (!is.na(s$yob[1])) 5L * (s$yob[1] %/% 5L) else NA_integer_,
          stringsAsFactors = FALSE
        )
      }))

      if (is.null(surv_df) || nrow(surv_df) == 0) {
        .log("  no valid (start,stop) intervals; skip")
        next
      }
      n_events <- sum(surv_df$event == 1L)
      n_persons_in <- length(unique(surv_df$pid))
      .log("  Cox sample: ", nrow(surv_df), " intervals, ",
           n_persons_in, " persons, ", n_events, " events")

      if (n_events < 10) {
        .log("  fewer than 10 events; skip")
        next
      }

      # Stratify by 5-yr birth cohort if there is variation; else drop strata
      strata_term <- if (length(unique(na.omit(surv_df$yob5))) >= 2)
                       "+ strata(yob5)" else ""
      formula_str <- paste0(
        "survival::Surv(start, stop, event) ~ edu_yrs + sex ", strata_term
      )
      fit <- tryCatch(
        survival::coxph(stats::as.formula(formula_str),
                        data = surv_df,
                        cluster = pid,
                        ties = "efron"),
        error = function(e) {
          .log("  coxph error: ", conditionMessage(e))
          NULL
        }
      )
      if (is.null(fit)) next

      coefs <- summary(fit)$coefficients
      edu_row <- coefs["edu_yrs", , drop = FALSE]
      log_hr <- as.numeric(edu_row[, "coef"])
      se     <- as.numeric(edu_row[, "robust se"])
      hr     <- exp(log_hr)
      lo     <- exp(log_hr - 1.96 * se)
      hi     <- exp(log_hr + 1.96 * se)
      .log(sprintf("  HR(edu_yrs +1 yr) = %.3f (95%% CI %.3f – %.3f); n=%d events=%d",
                   hr, lo, hi, n_persons_in, n_events))

      cox_results[[c]] <- fit
      cox_tidy[[c]] <- data.frame(
        cohort   = c,
        country  = surv_df$cohort[1],   # placeholder, will rewrite below
        n_persons= n_persons_in,
        n_events = n_events,
        term     = "edu_yrs",
        log_HR   = log_hr,
        se       = se,
        HR       = hr,
        HR_lo    = lo,
        HR_hi    = hi,
        model    = "coxph",
        stringsAsFactors = FALSE
      )
    } else {
      # ---- single-wave cohort: prevalent-dementia logistic ----
      .log("  single-wave: fit logistic prevalent dementia")
      fit <- tryCatch(
        stats::glm(dem_dx ~ edu_yrs + age + sex,
                   data = d, family = stats::binomial("logit")),
        error = function(e) {
          .log("  glm error: ", conditionMessage(e))
          NULL
        }
      )
      if (is.null(fit)) next
      sm <- summary(fit)$coefficients
      edu_row <- sm["edu_yrs", , drop = FALSE]
      log_or <- as.numeric(edu_row[, "Estimate"])
      se     <- as.numeric(edu_row[, "Std. Error"])
      or     <- exp(log_or)
      lo     <- exp(log_or - 1.96 * se)
      hi     <- exp(log_or + 1.96 * se)
      .log(sprintf("  OR(edu_yrs +1 yr, prevalent) = %.3f (95%% CI %.3f – %.3f); n=%d events=%d",
                   or, lo, hi, nrow(d), sum(d$dem_dx == 1L)))

      logit_results[[c]] <- fit
      logit_tidy[[c]] <- data.frame(
        cohort   = c,
        country  = unique(d$country)[1],
        n_persons= nrow(d),
        n_events = sum(d$dem_dx == 1L),
        term     = "edu_yrs",
        log_HR   = log_or,         # log_OR (kept in same column for portability)
        se       = se,
        HR       = or,             # OR
        HR_lo    = lo,
        HR_hi    = hi,
        model    = "logit_prevalent",
        stringsAsFactors = FALSE
      )
    }
  }

  # rewrite country column from data
  cohort_country <- c(HRS = "USA", ELSA = "GBR", MHAS = "MEX",
                     LASI = "IND", CHARLS = "CHN", SHARE = "EU")
  for (c in names(cox_tidy))   cox_tidy[[c]]$country   <- cohort_country[c]
  for (c in names(logit_tidy)) logit_tidy[[c]]$country <- cohort_country[c]

  cox_summary <- if (length(cox_tidy)) do.call(rbind, cox_tidy)
                 else data.frame()
  logit_summary <- if (length(logit_tidy)) do.call(rbind, logit_tidy)
                   else data.frame()
  rownames(cox_summary) <- NULL
  rownames(logit_summary) <- NULL

  .log("\n=== Cox per-cohort summary ===")
  if (nrow(cox_summary)) {
    for (i in seq_len(nrow(cox_summary))) {
      r <- cox_summary[i, ]
      .log(sprintf("  %-7s n=%d events=%d  HR(edu+1)=%.3f (%.3f-%.3f)",
                   r$cohort, r$n_persons, r$n_events,
                   r$HR, r$HR_lo, r$HR_hi))
    }
  } else .log("  (none)")

  .log("\n=== Logistic per-cohort summary (single-wave) ===")
  if (nrow(logit_summary)) {
    for (i in seq_len(nrow(logit_summary))) {
      r <- logit_summary[i, ]
      .log(sprintf("  %-7s n=%d events=%d  OR(edu+1)=%.3f (%.3f-%.3f)",
                   r$cohort, r$n_persons, r$n_events,
                   r$HR, r$HR_lo, r$HR_hi))
    }
  } else .log("  (none)")

  invisible(list(
    cox_fits      = cox_results,
    cox_summary   = cox_summary,
    logit_fits    = logit_results,
    logit_summary = logit_summary
  ))
}
