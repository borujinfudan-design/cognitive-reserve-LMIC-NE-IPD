# cognitive-reserve-LMIC-NE-IPD

> **Education and brain health across the life course in low- and middle-income countries: A multi-cohort triangulation study using natural experiments and individual patient data meta-analysis**

[![PROSPERO](https://img.shields.io/badge/PROSPERO-CRD42026XX01-blue)](https://www.crd.york.ac.uk/PROSPERO/)
[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD%203--Clause-green)](LICENSE)
[![R](https://img.shields.io/badge/R-%E2%89%A54.5-276DC3?logo=r)](https://www.r-project.org/)
[![Pre-registered](https://img.shields.io/badge/Pre--registered-OSF-yellow)](https://osf.io/)

A coordinated **Bradford Hill triangulation** of four independent study designs to test whether education causally protects late-life brain health in low- and middle-income countries (LMICs):

1. **D1** — China 1986 Compulsory Schooling Law **fuzzy RDD** on mid-life cognition (CHARLS)
2. **D2** — India post-1947 state-level educational expansion **DID** on late-life dementia prevalence (LASI)
3. **D3** — **6-cohort IPD meta-analysis** on dementia incidence and cognitive trajectory (HRS, ELSA, SHARE, CHARLS, LASI, MHAS; N ≈ 239,500 / N ≈ 164,500 main analysis)
4. **D4** — **2-sample Mendelian randomization** for HIC subsample (Lee 2018 → Bellenguez 2022)

Inference: 4 estimands (LATE / ATT / ATE-association / Genetic effect) are **not pooled**; convergence in direction and magnitude across distinct confounding and selection structures supports a causal interpretation per Lawlor et al. 2016 (IJE).

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
- **Pre-registration**: PROSPERO CRD42026XX01 (companion sister paper: CRD42026XX02)
- **Pre-analysis plan**: deposited at OSF (link to be added on publication)
- **Reporting guidelines**: PRISMA-IPD (D3) + STROBE-MR (D4) + McKenzie & Pencavel 2017 (D1, D2)

---

## License

This code is released under the [BSD 3-Clause License](LICENSE). You are free to use, modify, and redistribute, with attribution.

Cohort data are governed by their respective Data Use Agreements and are **not** redistributable through this repository.

---

## Citation

Once published, please cite as:

```
Li K, Liu H, Jin B, et al. Education and brain health across the life course in
low- and middle-income countries: A multi-cohort triangulation study using
natural experiments and individual patient data meta-analysis.
Lancet Healthy Longev. 202?;?(?):?-?. doi:?
```
