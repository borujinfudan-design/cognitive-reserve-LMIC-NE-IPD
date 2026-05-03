# cognitive-reserve-LMIC-NE-IPD

> **Education and brain health across the life course in low- and middle-income countries: A natural-experiment causal inference study with cross-cohort triangulation**

[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD%203--Clause-green)](LICENSE)
[![R](https://img.shields.io/badge/R-%E2%89%A54.5-276DC3?logo=r)](https://www.r-project.org/)
[![Pre-registered: OSF](https://img.shields.io/badge/Pre--registered-OSF-yellow)](https://osf.io/)
[![Type: Original Article](https://img.shields.io/badge/Type-Original%20Article-success)](https://www.elsevier.com/researcher/author/policies-and-guidelines/research-elements)

An **original causal inference study** integrating four independent quasi-experimental and genetic-instrument designs to test whether education causally protects late-life brain health in low- and middle-income countries (LMICs).

This is **NOT** a systematic review of published literature. The four designs all use original individual-level data and original statistical estimation:

1. **D1** — China 1986 Compulsory Schooling Law **fuzzy RDD** on mid-life cognition (CHARLS) — *primary causal design*
2. **D2** — India post-1947 state-level educational expansion **DID** on late-life dementia prevalence (LASI) — *primary causal design*
3. **D3** — **Cross-cohort harmonised individual-participant analysis** on dementia incidence (HRS, ELSA, SHARE, CHARLS, LASI, MHAS; N ≈ 239,500 / N ≈ 164,500) — *confirmatory triangulation arm*
4. **D4** — **Two-sample Mendelian randomization** in European-ancestry subsample (Lee 2018 → Bellenguez 2022) — *genetic-instrument triangulation arm*

**Inferential framework**: The 4 estimands (LATE / ATT / log-HR / log-OR) are **not formally pooled**. Convergence in direction and magnitude across the four designs — each with distinct confounding and selection structures — constitutes the inferential signal per Lawlor et al. 2016 (IJE) Bradford Hill triangulation framework.

---

## Quick start (for collaborators / reviewers)

```bash
# 1. Clone
git clone https://github.com/borujinfudan-design/cognitive-reserve-LMIC-NE-IPD.git
cd cognitive-reserve-LMIC-NE-IPD

# 2. Install R packages (uses renv lock file)
Rscript -e 'install.packages("renv"); renv::restore()'

# 3. Run full pipeline (uses targets package)
Rscript -e 'targets::tar_make()'

# 4. Outputs land in results/{tables,figures,logs}
```

> ⚠️ **Individual-level data are NOT in this repository.** They are obtained under standard Data Use Agreements from the respective cohort authorities (HRS, ELSA, SHARE, CHARLS, LASI, MHAS) and stored locally outside this repo. See `data/raw/README.md` for paths.

---

## Project structure

```
cognitive-reserve-LMIC-NE-IPD/
├── R/                              # all analysis scripts
│   ├── 01_prep_HRS.R               # cohort prep
│   ├── 02_prep_ELSA.R
│   ├── 03_prep_SHARE.R             # placeholder, awaits SHARE approval
│   ├── 04_prep_CHARLS.R            # custom harmonization (largest single script)
│   ├── 05_prep_LASI.R
│   ├── 06_prep_MHAS.R
│   ├── 10_combine_5cohorts.R
│   ├── 20_table1_descriptives.R
│   ├── 30_main_cox_per_cohort.R    # D3 stage 1
│   ├── 31_meta_pool_HR.R           # D3 stage 2
│   ├── 60_RDD_China.R              # D1
│   ├── 61_DID_India.R              # D2
│   ├── 70_MR_HIC.R                 # D4
│   ├── 80_triangulation_fig5.R     # main inference figure
│   ├── 90_sensitivity_panel.R
│   └── helpers/
│       ├── recode_education.R
│       ├── derive_dementia.R
│       └── plot_themes.R
├── _targets.R                      # pipeline definition (targets package)
├── _setup.R                        # one-shot setup (renv::restore + dirs)
├── data/
│   ├── raw/                        # symlinks to local datasets (NOT committed)
│   ├── derived/                    # harmonized .rds outputs (NOT committed)
│   └── policy/                     # natural-experiment policy tables (committed)
│       ├── CN_1986_CompulsoryEdu_byProvince.csv
│       └── IN_EduExpansion_byState_v2.csv
├── results/
│   ├── tables/
│   ├── figures/
│   └── logs/
├── manuscript/                     # Quarto sources for Methods/Results
├── docs/
│   ├── PRISMA-IPD-checklist.md
│   ├── STROBE-MR-checklist.md
│   └── reviewer_response_template.md
├── renv.lock                       # exact R package versions
├── LICENSE                         # BSD-3-Clause
├── .gitignore
└── README.md                       # this file
```

---

## Authors

| Role | Name | Affiliation |
|---|---|---|
| **First author** | Kexin Li | Shengjing Hospital of China Medical University, Shenyang, China |
| **Co-corresponding** | Huayan Liu, PhD, Professor | Department of Neurology, The First Hospital of China Medical University, Shenyang, China |
| **Corresponding** | Boru Jin, PhD | Department of Neurology, The First Hospital of China Medical University, Shenyang, China |

**Repository maintained by**: Boru Jin, PhD (Fudan; current affiliation: The First Hospital of CMU). The GitHub username `borujinfudan-design` is a legacy alumni handle from the maintainer's doctoral training at Fudan University.

**Contact**: jinbr@cmu1h.com (Boru Jin) · liuhy@cmu1h.com (Huayan Liu) · 20222140@cmu.edu.cn (Kexin Li)

---

## Reproducibility

- **R version**: 4.5.2 (locked via `renv.lock`)
- **Pipeline orchestration**: `targets` package (deterministic dependency graph)
- **Pre-registration**: Open Science Framework — DOI `10.17605/OSF.IO/{{XXXXX}}` (companion sister paper: separate OSF DOI)
- **Why OSF, not PROSPERO**: PROSPERO is restricted to systematic reviews; this study is a multi-design causal inference investigation, for which OSF is the established pre-registration venue
- **Reporting guidelines**: PRISMA-IPD (D3 harmonised analysis) + STROBE-MR (D4 MR) + McKenzie & Pencavel 2017 + Imbens-Lemieux 2008 (D1 RDD) + Goodman-Bacon 2021 + Roth-Sant'Anna-Bilinski 2023 (D2 DID)

---

## License

This code is released under the [BSD 3-Clause License](LICENSE). You are free to use, modify, and redistribute, with attribution.

Cohort data are governed by their respective Data Use Agreements and are **not** redistributable through this repository.

---

## Citation

Once published, please cite as:

```
Li K, Liu H, Jin B, et al. Education and brain health across the life course in
low- and middle-income countries: A natural-experiment causal inference study
with cross-cohort triangulation. Lancet Healthy Longev. 202?;?(?):?-?. doi:?
```

> **Article Type Note**: This is an **Original Research Article (causal inference / quasi-experimental observational study)**. It is not a systematic review. The Web of Science Document Type is expected to be `Article` (single label, no `Meta-Analysis` or `Review` co-tag), in compliance with our institutional research output guidelines. The pre-registration is at OSF (not PROSPERO) for this same reason.
