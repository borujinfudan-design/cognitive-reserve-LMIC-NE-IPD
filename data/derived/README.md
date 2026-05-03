# `data/derived/` — Harmonized .rds outputs

> **NOT committed to git.** Regenerable from `data/raw/` via `targets::tar_make()`.

Files produced here:
- `hrs_long.rds`           (from R/01_prep_HRS.R)
- `elsa_long.rds`          (from R/02_prep_ELSA.R)
- `share_long.rds`         (from R/03_prep_SHARE.R; pending)
- `charls_long.rds`        (from R/04_prep_CHARLS.R)
- `charls_rdd_sample.rds`  (subset for D1 RDD)
- `lasi_long.rds`          (from R/05_prep_LASI.R)
- `lasi_did_sample.rds`    (subset for D2 DID)
- `mhas_long.rds`          (from R/06_prep_MHAS.R)
- `combined_5cohorts.rds`  (from R/10_combine_5cohorts.R)
