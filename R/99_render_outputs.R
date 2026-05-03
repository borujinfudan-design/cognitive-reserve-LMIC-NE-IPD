# ============================================================
# 99_render_outputs.R — wire all results into manuscript artifacts
# ============================================================
# Renders Quarto manuscript + assembles supplementary appendix
# Output: manuscript/main.docx, manuscript/supplement.docx
# ============================================================

render_all_outputs <- function(table1, meta_pooled, rdd_china, did_india,
                               mr_hic, fig5_triangulation, sensitivity_panel) {
  # TODO[W5]: quarto::quarto_render() + officer::body_add_ for tables
  invisible(NULL)
}
