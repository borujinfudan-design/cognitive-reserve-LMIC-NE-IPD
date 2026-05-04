# 🌅 明早开机第一件事 — 30 分钟跑通 prep_HRS

> **目标**：用 R 端到端跑一次 HRS 数据准备脚本，输出 `data/derived/hrs_long.rds`
> **耗时**：~30 分钟（含 R 包安装；下次只需 30 秒）
> **完成标志**：终端看到 `[validate_schema:HRS] OK` + 看到 RDS 文件出现

---

## 第 1 步 · 打开 RStudio 并切换到项目（30 秒）

1. **打开 RStudio**（Spotlight 搜 "RStudio"）
2. 点 **File → Open Project...**
3. 找到这个文件双击：
   ```
   /Users/jinboru/Documents/pyplots/5. DATABASE/6. ANALYSIS_PIPELINE/03_R_pipeline/cognitive-reserve-LMIC-NE-IPD.Rproj
   ```
4. RStudio 右下角 Files 面板应该看到 `R/`、`data/`、`docs/` 等

> ⚠️ **必须用 .Rproj 打开项目**！否则 `here::here()` 会指向错误目录。

---

## 第 2 步 · 一键安装核心 R 包（首次约 15–20 分钟）

在 RStudio Console 输入：

```r
source("_setup.R")
```

会自动：

1. 安装 `renv` 包管理器（若尚未安装）
2. 若已有 `renv.lock`：`renv::restore()`（与仓库锁定版本一致）
3. 若无锁文件：初始化 renv（**`restart = FALSE`**，不会在 RStudio 里半截重启打断脚本），再 **CRAN 安装核心依赖**（`haven`, `targets`, `survival`, `metafor`, `rdrobust`, `fixest`, `MendelianRandomization` 等）
4. **不会**自动安装 GitHub 上的 `TwoSampleMR` / `MRPRESSO`——避免首次环境就被 IEU 依赖卡死；跑通 `prep_HRS` **不需要**它们
5. 创建 `data/derived/`、`results/logs/` 等目录

**D4 孟德尔随机化**（等主流程跑通后再执行）：

```r
source("_install_optional_MR.R")
```

期间会弹出多个安装进度条。**全部回答 `y`**（如果问要不要从 source 编译）。

完成会看到：

```
[setup] complete.
  Next (HRS prep):  targets::tar_make(prep_HRS)
  D4 MR (optional): source("_install_optional_MR.R"); tar_make(mr_hic)
```

> ☕ 这一步喝杯咖啡的功夫。下次再开：有 `renv.lock` 则只需 `source("_setup.R")`（很快）。

> **技术说明**：之前 `_setup.R` 在 `renv::init()` 时默认 `restart = interactive()`，RStudio 会**重启会话**导致后面的 `renv::install()` **整段被跳过**；现已显式 `restart = FALSE`，同一会话内可装完所有核心包并 `snapshot`。

---

## 第 3 步 · 跑 prep_HRS（约 2-3 分钟）

继续在 Console 里输入：

```r
targets::tar_make(prep_HRS)
```

`targets` 会自动：

1. 加载 `_targets.R` 流水线定义
2. Source 所有 helpers + 脚本
3. 调用 `prep_HRS_fn()` 函数
4. 读 `data/raw/HRS/H_HRS_d.dta`（通过 symlink）
5. 抽 32 列、按 14 个 wave 拼成 long 格式
6. 应用 `recode_education(country = "USA")`
7. 应用 `derive_dementia(method = "langa_weir_2020")`
8. 验证 schema → 写 `data/derived/hrs_long.rds`

---

## 第 4 步 · 检查结果（30 秒）

### 4a. 看 RDS 是否生成

终端 / RStudio Files 面板看 `data/derived/` 下应该有：

```
hrs_long.rds   (估计 30-80 MB；具体看 HRS 实际人数)
```

### 4b. 看日志

```r
cat(readLines("results/logs/prep_HRS.log"), sep = "\n")
```

期望看到末尾 5 行类似：

```
[2026-05-04 06:1?:??] [validate_schema:HRS] OK — XXXXX rows × 22 cols
[2026-05-04 06:1?:??] FINAL: XXXXX person-wave rows × 22 columns
[2026-05-04 06:1?:??]   waves represented:   2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
[2026-05-04 06:1?:??]   iyear range:         1994 - 2020
[2026-05-04 06:1?:??]   dementia (LW2020):   ???? / ?????? (?.??%)
[2026-05-04 06:1?:??] wrote .../hrs_long.rds (??.? MB)
```

### 4c. 验证结构（可选）

```r
hrs <- readRDS("data/derived/hrs_long.rds")
str(hrs)              # should show 22 columns matching SCHEMA_VARS
table(hrs$wave)       # should show waves 2-15 with thousands of rows each
table(hrs$dem_dx, useNA = "always")   # 0/1/NA distribution
summary(hrs$edu_yrs)  # range 0-17, mean ~12 (US population)
summary(hrs$age)      # adults, range 50-105
```

---

## 第 5 步 · 把日志截图发给我（10 秒）

不论成功还是失败，都把 **完整 console 输出** 截图发给我，我会：

- ✅ **成功**：立刻开始 `02_prep_ELSA.R`（同样模板，半天搞定 5 个 cohort 的剩下 4 个）
- ❌ **失败**：根据错误信息修代码，10-30 分钟内 push 修复版

---

## 🚨 常见报错 & 你能自己处理的（不用等我）

### ❌ `Error: cannot find data/raw/HRS/H_HRS_d.dta`

**原因**：symlink 没建好或 H_HRS_d.dta 在别的位置

**自查**：
```r
list.files("data/raw/HRS")          # 期望看到 H_HRS_d.dta
file.exists("data/raw/HRS/H_HRS_d.dta")   # TRUE
```

如果 list.files 是空的，重建 symlink：
```bash
cd "/Users/jinboru/Documents/pyplots/5. DATABASE/6. ANALYSIS_PIPELINE/03_R_pipeline/data/raw"
rm -f HRS && ln -s "/Users/jinboru/Documents/pyplots/5. DATABASE/HRS" HRS
ls HRS/   # 应该看到 H_HRS_d.dta
```

如果 H_HRS_d.dta 实际叫别的名（比如 `H_HRS_e.dta`），告诉我实际文件名，我改脚本。

---

### ❌ `Error in haven::read_dta(...)`

**原因**：`haven` 没装好。重跑：
```r
install.packages("haven")
```

---

### ❌ `Error: missing source columns: raedyrs, raeduc`

**原因**：g2aging Harmonized HRS 的列名变了（旧版本用别的名）。

**应对**：在 RStudio 里跑：
```r
hrs_raw <- haven::read_dta("data/raw/HRS/H_HRS_d.dta", n_max = 1)
grep("^ra", names(hrs_raw), value = TRUE)[1:50]
grep("^r1", names(hrs_raw), value = TRUE)[1:50]
```

把输出**截图**发我，我对照实际列名修脚本（应该 5 分钟内修好）。

---

### ⚠️ 警告 `expected columns absent`

**正常**：HRS d 版本可能没有 PGS 列（在 sensitive health data 里）。脚本会自动忽略，把 `apoe4` / `pgs_*` 设为 NA。**不影响主流程**。

---

## 🎯 跑成功后告诉我什么

最理想的反馈：
```
prep_HRS 成功了，RDS 文件 ?? MB，
日志看到 dementia 比例 ?.??%
str(hrs) 输出截图：[贴图]
```

我会立刻：
1. 评估痴呆比例是否合理（HRS 历史范围 8-12%，65+人口）
2. 评估教育年数分布是否合理（美国 mean ~12-13 年）
3. 开 W2.1 — 同样的模板套到 ELSA、CHARLS、LASI、MHAS

---

## 💡 顺便测试 helpers（可选 · 1 分钟）

如果你好奇 helpers 单独跑长什么样：

```r
# Education recoder
test_df <- data.frame(raedyrs = c(8, 12, 16, NA),
                      raeduc  = c(1, 3, 5, 4))
source("R/helpers/schema_check.R")
source("R/helpers/recode_education.R")
recode_education(test_df, country = "USA")

# 期望输出 4 行，edu_isced = 2, 3, 6, 4
# edu_cat = Lower secondary, Upper secondary, Tertiary, Upper secondary
```

```r
# Dementia classifier
test_df <- data.frame(cog_raw = c(3, 8, 15, NA), age = c(70, 70, 70, 70))
source("R/helpers/derive_dementia.R")
derive_dementia(test_df, method = "langa_weir_2020")

# 期望输出 4 行：dem_dx = 1, 0, 0, NA
#                cind_dx = 0, 1, 0, NA
```

---

> 🌟 **整个流程跑完一次以后，你就拥有了一个真正可复现的研究流水线。** 后面 5 个 cohort 都按同样模板，每个只要 1-2 小时就能套出来。
