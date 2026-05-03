# `data/policy/` — Natural-experiment policy tables (committed to git)

These tables encode the policy variation that drives the natural-experiment
designs in the manuscript. They are committed to the repository (no
participant-level information).

## Files

### `CN_1986_CompulsoryEdu_byProvince.csv`
- 31 mainland provinces, year of full implementation of the 1986 Compulsory
  Education Law
- Used by `R/60_RDD_China.R` for D1 fuzzy RDD on mid-life cognition
- National mean adoption: 1986 (cutoff cohort = born 1972)
- Province-level lag is used in robustness analyses

### `IN_EduExpansion_byState_v2.csv`
- 30 Indian states/UTs, intensity of post-1947 educational expansion
- Used by `R/61_DID_India.R` for D2 staggered DID
- **v1 = placeholder.** v2 (with intensity index) will be populated by
  end of W1.4 (2026-05-09) following web research per the execution manual

## Sources & citations
- China table: Wang et al. 2018 (Lancet Public Health); Mo & Shi 2017 (cross-checked)
- India table (planned): Banerjee et al. 2010 (AER); ASER reports; UDISE
