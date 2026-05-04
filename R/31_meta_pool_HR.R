# ============================================================
# 31_meta_pool_HR.R — D3 stage 2: random-effects meta on log(HR)
# ============================================================
# Inputs : cox_per_cohort  (list with $cox_summary, $logit_summary)
# Outputs: meta_pooled — list with:
#            $rma_hr    metafor::rma object on Cox log_HR (HIC + LMIC multi-wave)
#            $rma_or    metafor::rma object on logit log_OR (single-wave LMIC)
#            $tab       data.frame with pooled estimates + I^2 + tau^2 + LOO
#            $forest_path / $funnel_path: PNG file paths
# Author : Boru Jin et al. | Last updated: 2026-05
# ============================================================

#' Random-effects meta on per-cohort log_HR (Cox) and log_OR (logit)
#' @export
pool_HR_meta <- function(cox_per_cohort,
                         out_dir = file.path(here::here(), "results/figures"),
                         log_path = file.path(here::here(),
                                              "results/logs/pool_HR_meta.log")) {
  dir.create(out_dir,           showWarnings = FALSE, recursive = TRUE)
  dir.create(dirname(log_path), showWarnings = FALSE, recursive = TRUE)
  log_con <- file(log_path, open = "wt"); on.exit(close(log_con))
  .log <- function(...) {
    msg <- sprintf("[%s] %s", Sys.time(), paste0(..., collapse = ""))
    writeLines(msg, log_con); message(msg)
  }
  .log("pool_HR_meta() started")

  if (is.null(cox_per_cohort)) {
    warning("[pool_HR_meta] empty input"); return(invisible(NULL))
  }

  cox_df  <- cox_per_cohort$cox_summary
  logit_df <- cox_per_cohort$logit_summary

  out <- list()

  # ---- pool Cox HRs (incident dementia) ----
  if (!is.null(cox_df) && nrow(cox_df) >= 2) {
    .log("Pooling Cox log_HR across ", nrow(cox_df), " cohorts: ",
         paste(cox_df$cohort, collapse = ", "))
    rma_hr <- metafor::rma(yi = cox_df$log_HR,
                           sei = cox_df$se,
                           method = "REML",
                           slab = cox_df$cohort)
    pooled_hr <- exp(as.numeric(rma_hr$b))
    pooled_lo <- exp(rma_hr$ci.lb)
    pooled_hi <- exp(rma_hr$ci.ub)
    .log(sprintf("  pooled HR(edu +1 yr) = %.3f (95%% CI %.3f – %.3f)",
                 pooled_hr, pooled_lo, pooled_hi))
    .log(sprintf("  I^2 = %.1f%%; tau^2 = %.4f; Q = %.2f (df=%d, p=%.3g)",
                 rma_hr$I2, rma_hr$tau2, rma_hr$QE, rma_hr$k - 1, rma_hr$QEp))

    # Leave-one-out
    loo <- tryCatch(metafor::leave1out(rma_hr), error = function(e) NULL)
    if (!is.null(loo)) {
      .log("  LOO HR range: ",
           sprintf("%.3f – %.3f", min(exp(loo$estimate)), max(exp(loo$estimate))))
    }

    # Forest plot
    forest_path <- file.path(out_dir, "Fig_forest_HR_edu.png")
    grDevices::png(forest_path, width = 1600, height = 900, res = 200)
    metafor::forest(rma_hr,
                    atransf = exp,
                    xlab = "Hazard ratio (per +1 year education)",
                    refline = 0,
                    digits = 3,
                    header = c("Cohort", "HR [95% CI]"),
                    mlab = sprintf("RE pooled (I²=%.0f%%)", rma_hr$I2))
    grDevices::dev.off()
    .log("  forest plot: ", forest_path)

    # Funnel plot
    funnel_path <- file.path(out_dir, "Fig_funnel_HR_edu.png")
    grDevices::png(funnel_path, width = 1200, height = 900, res = 200)
    metafor::funnel(rma_hr, atransf = exp,
                    xlab = "log(HR) (per +1 year education)")
    grDevices::dev.off()
    .log("  funnel plot: ", funnel_path)

    out$rma_hr      <- rma_hr
    out$forest_path <- forest_path
    out$funnel_path <- funnel_path
  } else {
    .log("Cox: <2 cohorts — pooling skipped")
  }

  # ---- pool logistic ORs (prevalent dementia, LMIC single-wave) ----
  if (!is.null(logit_df) && nrow(logit_df) >= 2) {
    .log("\nPooling logistic log_OR across ", nrow(logit_df), " cohorts: ",
         paste(logit_df$cohort, collapse = ", "))
    rma_or <- metafor::rma(yi = logit_df$log_HR,
                           sei = logit_df$se,
                           method = "REML",
                           slab = logit_df$cohort)
    .log(sprintf("  pooled OR(edu +1 yr) = %.3f (95%% CI %.3f – %.3f)",
                 exp(as.numeric(rma_or$b)),
                 exp(rma_or$ci.lb), exp(rma_or$ci.ub)))
    .log(sprintf("  I^2 = %.1f%%; tau^2 = %.4f", rma_or$I2, rma_or$tau2))
    out$rma_or <- rma_or
  } else if (!is.null(logit_df) && nrow(logit_df) >= 1) {
    .log("Logistic: only 1 cohort — pooling skipped (will report individually)")
  }

  # ---- summary table ----
  rows <- list()
  if (!is.null(out$rma_hr)) {
    rows[[length(rows)+1]] <- data.frame(
      analysis = "Cox incident (HIC+LMIC multi-wave)",
      k        = out$rma_hr$k,
      pooled   = exp(as.numeric(out$rma_hr$b)),
      ci_lo    = exp(out$rma_hr$ci.lb),
      ci_hi    = exp(out$rma_hr$ci.ub),
      I2_pct   = out$rma_hr$I2,
      tau2     = out$rma_hr$tau2,
      Q_p      = out$rma_hr$QEp,
      stringsAsFactors = FALSE
    )
  }
  if (!is.null(out$rma_or)) {
    rows[[length(rows)+1]] <- data.frame(
      analysis = "Logistic prevalent (LMIC single-wave)",
      k        = out$rma_or$k,
      pooled   = exp(as.numeric(out$rma_or$b)),
      ci_lo    = exp(out$rma_or$ci.lb),
      ci_hi    = exp(out$rma_or$ci.ub),
      I2_pct   = out$rma_or$I2,
      tau2     = out$rma_or$tau2,
      Q_p      = out$rma_or$QEp,
      stringsAsFactors = FALSE
    )
  }
  if (length(rows)) {
    out$tab <- do.call(rbind, rows)
    csv_path <- file.path(here::here(), "results/tables/Table_meta_pooled.csv")
    dir.create(dirname(csv_path), showWarnings = FALSE, recursive = TRUE)
    utils::write.csv(out$tab, csv_path, row.names = FALSE, fileEncoding = "UTF-8")
    .log("\nwrote ", csv_path)
  }

  invisible(out)
}
