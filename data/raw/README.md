# `data/raw/` — Original cohort datasets

> **NOT committed to git.** All files in this directory are obtained under
> Data Use Agreements with the respective cohort authorities and may not
> be redistributed.

## Expected layout

```
data/raw/
├── HRS/                          # Health and Retirement Study (USA)
│   └── H_HRS_d.dta               # g2aging Harmonized HRS, wave 15 (2020)
├── ELSA/                         # English Longitudinal Study of Ageing (UK)
│   ├── gh_elsa_h.dta             # g2aging Harmonized ELSA (long, all waves)
│   └── h_elsa_hcap_a2.dta        # ELSA-HCAP 2018 sub-sample
├── SHARE/                        # Survey of Health, Ageing & Retirement in Europe
│   └── (pending Research Data Center approval)
├── CHARLS/                       # China Health and Retirement Longitudinal Study
│   ├── 01_2011_baseline/
│   ├── 02_2013_wave2/
│   ├── 03_2014_LifeHistory/
│   ├── 04_2015_wave3/
│   ├── 05_2018_wave4/
│   ├── 06_2020_wave5/
│   ├── 07_COVID/
│   └── 08_2024_wave6/
├── LASI/                         # Longitudinal Aging Study in India
│   ├── H_LASI_a.dta              # g2aging Harmonized LASI wave 1
│   └── LASI-DAD/                 # HCAP sub-sample
└── MHAS/                         # Mexican Health and Aging Study
    └── H_MHAS_c2.dta             # g2aging Harmonized MHAS
```

## How to populate (for the maintainer's local machine)

The actual files live outside the git repo at:
`/Users/jinboru/Documents/pyplots/5. DATABASE/{cohort}/...`

We use **symlinks** (created by `_setup.R` or manually) so that the R scripts
see them under `data/raw/{cohort}/` without copying GBs of data.

Example (zsh):
```bash
cd cognitive-reserve-LMIC-NE-IPD/data/raw
ln -s "/Users/jinboru/Documents/pyplots/5. DATABASE/HRS"     HRS
ln -s "/Users/jinboru/Documents/pyplots/5. DATABASE/ELSA"    ELSA
ln -s "/Users/jinboru/Documents/pyplots/5. DATABASE/CHARLS"  CHARLS
ln -s "/Users/jinboru/Documents/pyplots/5. DATABASE/LASI"    LASI
ln -s "/Users/jinboru/Documents/pyplots/5. DATABASE/MHAS"    MHAS
```
