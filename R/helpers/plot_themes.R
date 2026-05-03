# ============================================================
# helpers/plot_themes.R
# ============================================================
# ggplot2 themes for manuscript figures (Lancet Healthy Longev style)
# ============================================================

theme_manuscript <- function(base_size = 8) {
  ggplot2::theme_classic(base_size = base_size, base_family = "Helvetica") +
    ggplot2::theme(
      panel.grid       = ggplot2::element_blank(),
      axis.text        = ggplot2::element_text(color = "black"),
      axis.title       = ggplot2::element_text(face = "bold"),
      legend.position  = "bottom",
      legend.title     = ggplot2::element_blank(),
      strip.background = ggplot2::element_rect(fill = "grey95", color = NA),
      strip.text       = ggplot2::element_text(face = "bold")
    )
}

# Lancet Healthy Longevity color palette (CMYK-safe, colorblind-friendly)
pal_cohort <- c(
  HRS    = "#1F77B4",
  ELSA   = "#FF7F0E",
  SHARE  = "#2CA02C",
  CHARLS = "#D62728",
  LASI   = "#9467BD",
  MHAS   = "#8C564B"
)

pal_design <- c(
  D1_RDD  = "#0072B2",
  D2_DID  = "#E69F00",
  D3_IPD  = "#009E73",
  D4_MR   = "#CC79A7"
)
