# ============================================================
# 20_table1_descriptives.R — Manuscript Table 1 (cross-cohort)
# ============================================================
# Inputs : combined_5cohorts (rds)
# Output : results/tables/Table1_descriptives.csv  (canonical)
#          results/tables/Table1_descriptives.docx (manuscript-ready)
# Author : Boru Jin et al. | Last updated: 2026-05
# ============================================================
# Strategy:
#   - One column per cohort + an ALL column.
#   - Restrict to baseline-per-person (first wave each person appears in)
#     for "N persons", "Age", "Sex", "Education" (these are time-invariant
#     or near time-invariant from baseline).
#   - Person-wave totals reported separately for cognitive / dementia rows.
#   - Output CSV is canonical (machine-readable); flextable docx is
#     manuscript-ready (only built if `flextable` available).
# ============================================================

#' Build manuscript Table 1
#'
#' @param combined  output of combine_5cohorts_fn() (canonical schema)
#' @param out_dir   directory for CSV + DOCX outputs
#' @return invisible list with $tbl (data.frame) and file paths
#' @export
build_table1 <- function(combined,
                         out_dir = file.path(here::here(), "results/tables"),
                         log_path = file.path(here::here(),
                                              "results/logs/build_table1.log")) {
  dir.create(out_dir,           showWarnings = FALSE, recursive = TRUE)
  dir.create(dirname(log_path), showWarnings = FALSE, recursive = TRUE)
  log_con <- file(log_path, open = "wt"); on.exit(close(log_con))
  .log <- function(...) {
    msg <- sprintf("[%s] %s", Sys.time(), paste0(..., collapse = ""))
    writeLines(msg, log_con); message(msg)
  }
  .log("build_table1() started")

  if (is.null(combined) || nrow(combined) == 0) {
    warning("[build_table1] empty input; skipping")
    return(invisible(NULL))
  }

  cohorts <- sort(unique(combined$cohort))
  .log("cohorts: ", paste(cohorts, collapse = ", "))

  # ---- baseline-per-person frame ----
  pid <- sub("_w[0-9]+$", "", combined$id)   # strip _wN suffix
  combined$pid <- pid
  ord <- order(combined$pid, combined$wave, na.last = TRUE)
  combined <- combined[ord, , drop = FALSE]
  baseline <- combined[!duplicated(combined$pid), , drop = FALSE]
  .log("baseline-per-person frame: ", nrow(baseline), " unique persons")

  # ---- helpers ----
  fmt_n_pct <- function(n, d) {
    if (d == 0 || is.na(d)) return("—")
    sprintf("%s (%.1f%%)", format(n, big.mark = ","), 100 * n / d)
  }
  fmt_mean_sd <- function(x) {
    x <- x[!is.na(x)]
    if (!length(x)) return("—")
    sprintf("%.2f (%.2f)", mean(x), stats::sd(x))
  }
  fmt_med_iqr <- function(x) {
    x <- x[!is.na(x)]
    if (!length(x)) return("—")
    q <- stats::quantile(x, c(0.5, 0.25, 0.75))
    sprintf("%.0f (%.0f-%.0f)", q[1], q[2], q[3])
  }
  fmt_range <- function(x) {
    x <- x[!is.na(x)]
    if (!length(x)) return("—")
    sprintf("%d-%d", as.integer(min(x)), as.integer(max(x)))
  }

  # ---- compute per-cohort columns ----
  build_col <- function(d_pw, d_bl) {
    # d_pw = person-wave subset; d_bl = baseline-per-person subset
    n_persons <- nrow(d_bl)
    n_waves   <- nrow(d_pw)
    list(
      `N persons`            = format(n_persons, big.mark = ","),
      `Person-waves`         = format(n_waves, big.mark = ","),
      `Country`              = paste(unique(d_bl$country), collapse = ", "),
      `Wave coverage`        = paste(sort(unique(d_pw$wave)), collapse = ", "),
      `Calendar year range`  = fmt_range(d_pw$iyear),
      `Age at baseline (median, IQR)` = fmt_med_iqr(d_bl$age),
      `Female (n, %)`        = fmt_n_pct(sum(d_bl$sex == "Female", na.rm = TRUE),
                                         sum(!is.na(d_bl$sex))),
      `Rural at baseline (n, %)` = fmt_n_pct(sum(d_bl$rural == 1L, na.rm = TRUE),
                                             sum(!is.na(d_bl$rural))),
      `Years of education (mean, SD)` = fmt_mean_sd(d_bl$edu_yrs),
      `  Less than primary (n, %)` =
        fmt_n_pct(sum(d_bl$edu_cat == "Less than primary", na.rm = TRUE),
                  sum(!is.na(d_bl$edu_cat))),
      `  Primary (n, %)` =
        fmt_n_pct(sum(d_bl$edu_cat == "Primary", na.rm = TRUE),
                  sum(!is.na(d_bl$edu_cat))),
      `  Lower secondary (n, %)` =
        fmt_n_pct(sum(d_bl$edu_cat == "Lower secondary", na.rm = TRUE),
                  sum(!is.na(d_bl$edu_cat))),
      `  Upper secondary (n, %)` =
        fmt_n_pct(sum(d_bl$edu_cat == "Upper secondary", na.rm = TRUE),
                  sum(!is.na(d_bl$edu_cat))),
      `  Tertiary (n, %)` =
        fmt_n_pct(sum(d_bl$edu_cat == "Tertiary", na.rm = TRUE),
                  sum(!is.na(d_bl$edu_cat))),
      `Cognition raw at baseline (mean, SD)` = fmt_mean_sd(d_bl$cog_raw),
      `Dementia prevalence person-waves (n, %)` =
        fmt_n_pct(sum(d_pw$dem_dx == 1L, na.rm = TRUE),
                  sum(!is.na(d_pw$dem_dx))),
      `CIND prevalence person-waves (n, %)` =
        fmt_n_pct(sum(d_pw$cind_dx == 1L, na.rm = TRUE),
                  sum(!is.na(d_pw$cind_dx))),
      `APOE-ε4 carriers (n, %)` =
        fmt_n_pct(sum(d_bl$apoe4 >= 1L, na.rm = TRUE),
                  sum(!is.na(d_bl$apoe4)))
    )
  }

  cols <- list()
  for (c in cohorts) {
    d_pw <- combined[combined$cohort == c, , drop = FALSE]
    d_bl <- baseline[baseline$cohort == c, , drop = FALSE]
    cols[[c]] <- build_col(d_pw, d_bl)
  }
  cols[["ALL"]] <- build_col(combined, baseline)

  # row labels = names of first column
  row_labels <- names(cols[[1]])
  tbl <- data.frame(
    Variable = row_labels,
    stringsAsFactors = FALSE
  )
  for (c in c(cohorts, "ALL")) {
    tbl[[c]] <- vapply(row_labels, function(r) cols[[c]][[r]], character(1))
  }

  # ---- write CSV ----
  csv_path <- file.path(out_dir, "Table1_descriptives.csv")
  utils::write.csv(tbl, csv_path, row.names = FALSE, fileEncoding = "UTF-8")
  .log("wrote ", csv_path)

  # ---- pretty print to log ----
  .log("\n=== Table 1: cross-cohort descriptive statistics ===")
  col_widths <- pmax(nchar(c("Variable", row_labels)),
                     vapply(c("Variable", row_labels), nchar, integer(1)))
  print_row <- function(vals, sep = "  ") {
    .log(paste(vals, collapse = sep))
  }
  hdr <- c(format("Variable", width = 42),
           vapply(c(cohorts, "ALL"), format, character(1), width = 18))
  .log(paste(hdr, collapse = " "))
  .log(paste(rep("-", sum(nchar(hdr)) + length(hdr)), collapse = ""))
  for (i in seq_len(nrow(tbl))) {
    row_vals <- c(format(tbl$Variable[i], width = 42),
                  vapply(c(cohorts, "ALL"),
                         function(c) format(tbl[[c]][i], width = 18),
                         character(1)))
    .log(paste(row_vals, collapse = " "))
  }

  # ---- write DOCX (optional) ----
  docx_path <- file.path(out_dir, "Table1_descriptives.docx")
  if (requireNamespace("flextable", quietly = TRUE) &&
      requireNamespace("officer",   quietly = TRUE)) {
    ft <- flextable::flextable(tbl)
    ft <- flextable::autofit(ft)
    ft <- flextable::set_caption(ft,
            caption = paste0("Table 1. Baseline characteristics of ",
                             length(cohorts), " contributing cohorts. ",
                             "Counts are person-level at first observation; ",
                             "dementia / CIND prevalence are person-wave."))
    doc <- officer::read_docx()
    doc <- flextable::body_add_flextable(doc, ft)
    print(doc, target = docx_path)
    .log("wrote ", docx_path)
  } else {
    .log("flextable / officer not available — CSV only")
  }

  invisible(list(tbl = tbl,
                 csv = csv_path,
                 docx = if (file.exists(docx_path)) docx_path else NA_character_))
}
