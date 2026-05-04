# 工作日志 · 2026-05-04（周一）

> **目的**：完整记录今日的策略调整、技术修复与数据决策，便于明天 / 团队成员回顾。
> **作者**：Boru Jin（与 Cursor 协作）
> **关联仓库 commit 范围**：`5d48ff3` … `f9831b7`（GitHub `borujinfudan-design/cognitive-reserve-LMIC-NE-IPD`）

---

## 1 · 战略层重大调整

### 1.1 PROSPERO → OSF（最关键决策）

| 项目 | 之前 | 今日改为 |
|---|---|---|
| 预注册平台 | PROSPERO | **Open Science Framework (OSF)** |
| 主稿件 title | "...integrating natural experiments, individual patient data analysis, and Mendelian randomization" | **"...A natural-experiment causal inference study with cross-cohort triangulation"** |
| 论文叙事定位 | IPD-meta 为骨架 | **因果推断为主线、IPD 为 4 个三角验证设计之一** |
| WoS Article 概率 | ~30%（PROSPERO 几乎必触发 Meta-Analysis 标签）| **~99%**（OSF 不触发 review 索引）|

**根本原因**：CMU 第一附属医院科研处对**原创 `Article` 类型**有硬性要求；PROSPERO 官方定位为 systematic review registry，注册号会被 PubMed/Web of Science 自动归类为 `Meta-Analysis` / `Systematic Review`。

**保留物**：所有 PROSPERO 草稿（`05_*`、`03_*`、`06_*`）已加 **"已废弃 — DO NOT SUBMIT"** 头部 banner，作为审计历史保留。

### 1.2 新建 OSF 注册稿（已生成 docx）

| 文件 | 用途 |
|---|---|
| `_Registrations/07_OSF_注册稿_主稿件_v1_因果推断重定位_2026-05-04.docx` | 主稿件 13 字段可粘贴版 |
| `_Registrations/08_OSF_注册稿_姐妹论文N0_v1_2026-05-04.docx` | 姐妹论文 13 字段 |
| `_Registrations/MORNING_OSF_5min_GUIDE.docx` | Kexin 提交 5 分钟操作清单 |

### 1.3 Cover letter 同步升级到 v3

- `_Templates/01_CoverLetter_主稿件_LancetHealthyLongevity.{md,docx}`
- `_Templates/02_CoverLetter_姐妹论文_AlzheimersDementia_含ICMJE_Disclosure.{md,docx}`
- 把 PROSPERO ID 引用全部替换为 OSF DOI 占位符（`10.17605/OSF.IO/{{XXXXX}}`）
- 主稿件 title 同步到 v4.4 的"natural-experiment causal inference"版本

### 1.4 关于 OSF 的两个常见疑问

| 问题 | 结论 |
|---|---|
| 投稿时 title 与 OSF 注册 title 不一致？ | ✅ **完全可以**，措辞 / 期刊偏好级别的修改不需任何额外操作；只有研究问题/暴露/结局核心改动才需 OSF amendment |
| 能否拖到论文成稿再注册？ | ❌ **不行**。Pre-registration 的"pre"是字面意思；事后注册 = 学术不端，可被撤稿。Lancet / JAMA / NEJM 已部署时间戳 + 协议-论文一致性核查 |

**Kexin 今日已开始 OSF 注册流程**。

---

## 2 · R 工程基础设施修复

### 2.1 `_setup.R` — renv 启动逻辑

**问题**：`renv::init()` 默认 `restart = interactive()`，在 RStudio 里会**重启会话**，把后续的 `renv::install(...)` 整段跳过；后果是用户以为环境装好了，实际只装了 renv 自己。

**修复**：
- `restart = FALSE` 强制不重启
- 三分支：有 `renv.lock` → restore；只有 `renv/` → install + snapshot；都没有 → init + install + snapshot
- `snapshot(packages = .renv_core_pkgs)` 显式只锁核心包，避免 `_targets.R` 里被引用但未安装的 `TwoSampleMR` / `MRPRESSO` 触发交互菜单

### 2.2 `_install_optional_MR.R` — 独立的 GitHub MR 安装

把不在 CRAN 的 `TwoSampleMR` / `MRPRESSO` 拆出来：
- 主流程（`prep_HRS`、`prep_ELSA`、…）**完全不需要**它们
- `_targets.R` 里 `mr_hic` target 单独 `packages = c("TwoSampleMR", "MendelianRandomization", "MRPRESSO")`，只在跑 D4 时加载
- 等 D3 / D1 / D2 都跑通后再 `source("_install_optional_MR.R")`

### 2.3 `renv/settings.json`

`ignored.packages = ["TwoSampleMR", "MRPRESSO"]` — 让 `renv::snapshot` 在依赖扫描时跳过这两个 GitHub 包，永不出现在锁文件里。

### 2.4 `_targets.R`

- `tar_option_set(packages = ...)` 中移除 `TwoSampleMR` / `MRPRESSO`
- `mr_hic` target 单独指定 packages，保证 `tar_make(prep_HRS)` 在没装 MR 包时也能跑

**关联 commits**：`bd357c4`、`0a4567b`

---

## 3 · `prep_HRS.R` — 完整重写并跑通

### 3.1 数据源决策

| 选项 | 关键缺陷 | 决定 |
|---|---|---|
| Gateway Harmonized HRS Version D（`H_HRS_d.dta`，855 MB）| **没有** `raedyrs`、`r{w}cogtot`、`imrc/dlrc/ser7/bwc20` | ❌ 弃用 |
| **RAND HRS Longitudinal File 2022**（`randhrs1992_2022v1.dta`，1.74 GB）| 全部所需变量都在 | ✅ **采用** |

### 3.2 Langa-Weir 2022 join

- 文件：`11_LangaWeir_Cognitive_Classification/cogfinalimp_9522wide.dta`（286 列，宽格式）
- ID 是分两列 `hhid` + `pn`（标准 HRS 约定，**`hhidpn = hhid * 1000 + pn`**），不是直接的 `hhidpn`
- 提取：
  - `cogtot27_imp{year}` —— LW imputed 0-27 总分（覆盖 r{w}cogtot 的缺失，特别是 RAND HRS 在 wave 14-16 缺的部分）
  - `cogfunction{year}` —— **官方 Langa-Weir 三分类**（1=normal / 2=CIND / 3=dementia），优先级高于我们手算的 cutpoints
- Wave-year 映射：wave 3=1996、4=1998、…、16=2022（共 14 个 wave 可 join）

### 3.3 路径修复

- HRS 文件实际在子目录 `02_Gateway_Harmonized_HRS/`，不是 `data/raw/HRS/` 直接根目录
- `prep_HRS_fn` 使用候选路径列表 `Find(file.exists, candidates)` 兼容三种常见布局

### 3.4 跑通后核心指标

```
✔ prep_HRS completed [1m 33.8s, 2.32 MB]

总样本               : 283,547 person-waves / 45,234 unique persons
Wave 覆盖            : 2-16 (1993-2023)
Langa-Weir 官方覆盖  : 256,799 / 283,547 (90.6%)
cog_raw 填充率       : 86.5%
痴呆率 (LW2022)       : 17,382 / 262,354 (6.63%)   ← HRS 文献区间 6-12%
教育年数 (mean ± SD) : 12.37 ± 3.35                ← 美国分布
输出文件             : data/derived/hrs_long.rds (1.2 MB, xz 压缩)
```

**关联 commits**：`73cf16a`、`d59660c`、`761bb02`

---

## 4 · `prep_ELSA.R` — 已就绪（待跑）

### 4.1 数据源

- 主源：**`05_UKDS_Original/UKDA-5050-stata/stata/stata13_se/gh_elsa_h.dta`**（Gateway Harmonized ELSA Version H，13,687 列）
- HCAP 备选：`04_ELSA_HCAP_Multi-Country/.../h_elsa_hcap_a2.dta`（金标准认知，wave 9 子样本，~1,100 人；本版本暂未 join，留作 W2）
- 注意 `01_Gateway_Harmonized_ELSA/` 文件夹**为空**，所以不能从那里取

### 4.2 ELSA 与 HRS 的关键差异

| 项 | HRS | ELSA |
|---|---|---|
| ID | `hhidpn` (numeric) | **`idauniq`** |
| Waves | 2-16 (1994-2022) | 1-10 (1998-2021) |
| iyear | `r{w}iwendy` | **`r{w}iwy`** |
| age | `r{w}agey_e` | **`r{w}agey`** |
| cogtot | `r{w}cogtot` (LW 27) | **不存在** → 手算 `imrc + dlrc + orient`（max 24）|
| 教育年数 | `raedyrs` (continuous) | **不存在** → 从 `raeducl`（3-cat）映射 |
| 痴呆 | Langa-Weir 官方 | g2aging `r{w}cogimp` + 自算 cutoffs（0-7 dem / 8-11 CIND / 12-24 normal）|
| 认知子项 | imrc/dlrc/ser7/bwc20 | imrc/dlrc/orient/verbf |

### 4.3 `recode_education_UK`（新增）

- `raeducl` 1/2/3 → ISCED 2/3/6 → years 9/12/16（Banks 2018, Steptoe 2013 ELSA 经典映射）
- 若 HCAP 子样本带 `raedyrs_e` 则覆盖 midpoint

**关联 commit**：`f9831b7`

### 4.4 待跑命令

```r
source("R/02_prep_ELSA.R")
targets::tar_make(prep_ELSA, callr_function = NULL)
```

---

## 5 · 文档与 GitHub

### 5.1 README + MORNING_RUN_GUIDE 更新

- README badge：移除 PROSPERO，改 **OSF + Original Article**
- Quick start：改成两阶段（核心 setup → 可选 MR install）
- MORNING_RUN_GUIDE：解释 `restart = FALSE` 修复

### 5.2 GitHub 提交节奏

| commit | 内容 |
|---|---|
| `5d48ff3` | OSF 重定位（README + renv 配置）|
| `4cf5e7d` | 修 renv bootstrap：核心包 / GitHub MR 拆分 |
| `bd357c4` | snapshot 只锁核心包；ignored.packages |
| `0a4567b` | 移除 snapshot type= 冗余警告 |
| `73cf16a` | 修 HRS 路径（子目录候选）|
| `d59660c` | RAND HRS 2022 重写 + LW join 框架 |
| `761bb02` | hhid+pn → hhidpn；cogfunction 官方分类 |
| `f9831b7` | prep_ELSA + UK education |

---

## 6 · 完成 / 待办

### ✅ 完成

- OSF 主稿件 + 姐妹论文注册稿（13 字段 docx）
- Cover letter v3 × 2（已切到 OSF + 因果推断框架）
- R repo README + 早晨指南文档
- PROSPERO docx 全部加废弃 banner
- 全部 docx 重生成（`_build_plan_word.py` 已更新）
- R 环境核心包安装 + `renv.lock` 写入
- **prep_HRS 跑通，输出 hrs_long.rds**
- prep_ELSA 脚本就绪，待跑

### 🔜 接下来（按优先级）

1. **Kexin 提交 OSF 主稿件注册** → 拿到 DOI 回填占位符
2. 跑 `prep_ELSA`，确认指标合理
3. `prep_MHAS`（墨西哥；g2aging 同语言，~30 分钟可写完）
4. `prep_LASI`（印度；含 LASI-DAD HCAP）
5. `prep_CHARLS`（中国；native 数据，需较多定制）
6. SHARE 待审批 → 暂留占位
7. `10_combine_5cohorts` → `20_table1` → `30_cox` → `31_meta`
8. `_install_optional_MR.R` → `60_RDD_China` / `61_DID_India` / `70_MR_HIC`

### ⚠️ 仍未解决 / 跨日跟进

- **SHARE 数据审批**：邮件跟进
- **LASI dementia imputation**：跟进 LASI 邮件
- **印度 DID 政策表 v2**：网搜补全 state-level expansion 指标（目前 `IN_EduExpansion_byState_v2.csv` 仅占位）
- **HRS 敏感数据**（APOE / PGS）：另轨申请；与主分析可并行
- **HCAP join**（ELSA 1100 人金标准）：W2 加进去做 sensitivity

---

## 7 · 经验教训（写给未来自己）

1. **PROSPERO 不是给 IPD-meta + causal inference 类研究用的**：宁可花 30 分钟切到 OSF，不要为了"已经写了 36 字段"硬上 PROSPERO。
2. **g2aging Harmonized 系列 ≠ RAND HRS Longitudinal**：Harmonized 版本舍弃了很多关键变量（raedyrs、cogtot、imrc/dlrc/ser7/bwc20）；做 IPD 分析必须回到 RAND HRS Longitudinal File。同理 ELSA 走 g2aging Harmonized ELSA Version H + UKDS Original raw。
3. **Langa-Weir 文件 ID 是 `hhid + pn`，不是 `hhidpn`**：所有人都在踩这个坑；记得 `hhidpn = hhid * 1000 + pn`。
4. **`renv::init(restart = interactive())` 在 RStudio 是个隐藏炸弹**：必显式 `restart = FALSE`，否则会话重启，后续 `install` 整段失效。
5. **`renv::snapshot` 会扫整个项目找依赖**：包括 `_targets.R` 里的字符串包名。GitHub-only 包必须 `ignored.packages` 显式排除，否则 snapshot 会反复弹交互菜单。
6. **写 prep 脚本前**：先跑 1 分钟 `names(haven::read_dta(..., n_max = 1))` 诊断，把列名拿全了再写脚本，能避免 3-4 轮试错。
7. **痴呆率 6-12% 是 HRS 65+ 文献区间**：跑出来落在这个区间基本说明 prep 对了；超出立即查算法。
8. **教育年数 mean ~12.4 ± 3.3 是美国分布**；ELSA 期望 ~12 ± 3.5；CHARLS / LASI / MHAS 期望 ~6-9 ± 4-5（教育水平显著低）。

---

> **下次接力点**：跑通 `prep_ELSA`；如果数字合理，并排做 `prep_MHAS`。
> **回访这份日志**：`docs/PROGRESS_LOG_2026-05-04.md`
