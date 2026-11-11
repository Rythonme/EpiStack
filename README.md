# EpiStack — 端到端传染病时空分析与健康不平等体系（v2）

[English version](README.en.md) · 当前版本 `v0.1.1` · [路线图与逐月更新](ROADMAP.md) · [本月任务归档](docs/monthly/2026-11.md)

[![R-CMD-check](https://github.com/Rythonme/EpiStack/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/Rythonme/EpiStack/actions/workflows/R-CMD-check.yaml) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> **GitHub 主仓**：[github.com/Rythonme/EpiStack](https://github.com/Rythonme/EpiStack)（公开 · MIT · 2026-11-11 首次发布）
>
> **当前版本 `v0.1.1`（2026-11-10）**：在 `v0.1`（tag）基础上补齐 **W2 编排与 golden 冒烟测试**、**W3 CI / Pages / renv / 英文文档**。
> `v0.1` = `epi-core` 正式 R 包 + 六层端到端切片 + HFRS 真实数据实测。
>
> **v1 的 EpiBulletin 只是 L5 一层，现升级为完整体系。**
>
> **一句话**：从只读原始监测面板出发，经数据质控 → 监测预警 → 时空建模 → 不平等测度 → 综合报告 → 可复现编排，形成一条**一条命令跑通 L0→L6** 的开源体系；每月发布一个可独立安装的卫星仓加厚其中一层，年底集成成 `EpiStack 1.0`。
>
> **最重要的一条设计判断**：不要"先造半年零件、最后拼不起来"。**第一个月就打通一条薄而全的链路**，之后每月只替换某一层的实现，上下游契约不变，链路永远跑得通。这条链路今天已经在本机 R 4.6.0 跑通（见第 5 节实测）。

---

## 快速开始（30 秒，零第三方依赖）

```bash
git clone https://github.com/Rythonme/EpiStack.git
cd EpiStack
Rscript pipeline.R --check        # 合成数据六层全通 + golden 冒烟（37 PASS / 0 FAIL）
Rscript pipeline.R --list         # 只看 L0–L6 分层计划
```

断网也能跑：不需要安装任何第三方 R 包，`bootstrap_core.R` 会自动从源码加载 `epi-core`。
单独跑某条链路：`Rscript vertical_slice/run_e2e.R`（合成数据）或 `Rscript case_hfrs_real/run_hfrs.R`（真实数据仅在本机）。

### 只想单独用 `epiCore` 这个包？联网一行安装（不用 clone 整个仓库）

```r
install.packages(
  "https://github.com/Rythonme/EpiStack/releases/download/v0.1.1/epiCore_0.1.0.tar.gz",
  repos = NULL, type = "source"
)
library(epiCore)
```

这就是本地 `install.packages("path/to/epi-core", ...)` 的联网版：路径换成 Release 资产 URL 即可，
零第三方依赖、纯 R 无需编译工具、版本固定可复现。装开发版可用
`remotes::install_github("Rythonme/EpiStack", subdir = "epi-core", ref = "v0.1.1")`，
Windows 上需先 `Sys.setenv(TAR = "internal")`（仓库含中文文件名，外部 `tar.exe` 会报转码错误）；
`pak::pkg_install("github::Rythonme/EpiStack/epi-core@v0.1.1")` 亦可。
详见 [epi-core/README.md 安装章节](epi-core/README.md#安装)。

---

## 1. 为什么是"体系"，而不是"更大的一个工具"

单一周报工具的天花板很低：它只解决 L5，而你的清单 A–F 六区、153 个仓库、Top10 思路，以及在研的 HFRS 景观格局项目（CLCD 栅格、990m 网格、99.3 万网格-年面板、INLA-BYM2、ED₂₁）和"医疗卫生的不平等性"课题，本来就是**一条链上的不同环节**。

把这些环节拆开做成孤立仓库，一年后是 12 个玩具；用统一数据契约串起来，就是一套能写进论文方法部分、能给课题组复用的体系。

| 目标 | 体系化做法 |
|---|---|
| 每月一个 GitHub 项目 | 每月一个**卫星仓**，可独立安装、独立发 Release、独立写 README |
| 一个完整体系 | 一个 `epistack` **主仓**负责契约、编排、集成与文档；卫星仓通过契约对接 |
| 立刻能开发 | 本月先交付"薄切片"：`run_e2e.R` 六层全通，不依赖任何第三方包 |
| 实用 | 首个真实用例就是你自己的 HFRS 面板；输出物是可转发的单文件 HTML 报告 |

---

## 2. 体系架构：L0–L6

| 层 | 卫星仓 | 职责 | 输入 → 输出 | 主要复用（清单内已直验） |
|---|---|---|---|---|
| **L0** | `epi-core` | 统一数据契约、地区编码表、邻接权重、配置 | 原始表 → 契约长表 | 地基，不依赖外部包 |
| **L1** | `epi-ingest` | 多源接入、缺失/重复/口径校验、脱敏 | CSV/栅格/API → 干净长表 | `rio`、`data.table` |
| **L2** | `epi-alert` | 季节性基线带、Farrington/EWMA/CUSUM、Rt/nowcast 适配 | 长表 → 预警清单 | `surveillance`(A6)、`EpiNow2`(A1)、`EpiEstim`(A2)、`WarnEpi`、`epichannel` |
| **L3** | `epi-space` | Moran/LISA、GWR/MGWR、BYM2/INLA、时空点过程、景观格局指数 | 长表+权重 → 风险图与参数 | `r-inla`(B1)、`CARBayes`(B3)、`inlabru`(B10)、`mgwr`(C7)、`surveillance` |
| **L4** | `epi-ineq` | 集中指数/SII/分解、医疗可达性与服务区 | 长表+SES → 不平等指标 | `healthequal`(E6)、`rineq`(E7)、`osmnx`/`pysal` |
| **L5** | `epi-report` | 单文件 HTML 周报、交互看板、风险地图 | 各层结果 → 可转发成果 | `sitrep`、`EpiSignalDetection`（差异化参考） |
| **L6** | `epi-flow` | `targets` 编排、`renv`、CI、每月定时重跑 | 全部 → 一键复现 | `targets`、`renv`、GitHub Actions |

**横切全层的唯一契约**：

```
date · region · count · population · disease        # 长表
+ geo 表：region, row/col 或行政区划代码, pop, ses  # 地理与社会经济编码
+ W：邻接/空间权重矩阵                              # L3 与 L4 共用
```

所有模块只认这三样东西，这是体系能拼起来的唯一原因，也是"每月换一层不炸链路"的保证。

**不重复造轮子**：L2–L4 一律写成**适配器**，调用清单里已成熟的包，不重写估计算法；本项目贡献的是契约、编排、质控与交付。竞品直验结论（2026-11-10）见文末附录。

---

## 3. 仓库拓扑：主仓 + 卫星仓

```
epistack/                      # 主仓：契约定义、集成测试、编排、文档站、路线图
├── inst/contract/             # 契约 schema + 合成示例数据
├── R/ pipeline_plan.R         # L0–L6 声明式分层计划（每月改一行）
├── pipeline.R                 # targets 雏形执行器，按层调用卫星仓
└── vignettes/case-hfrs.Rmd    # 端到端案例（HFRS）
        │  只通过契约交互
        ├── epi-core      (2026-11)
        ├── epi-ingest    (2026-12)
        ├── epi-alert     (2027-01)
        ├── epi-space     (2027-02 / 03)
        ├── epi-ineq      (2027-04)
        ├── epi-access    (2027-05)
        ├── epi-report    (2027-06 / 07)
        └── epi-flow      (2027-08)
```

每月的仓库都能**独立 clone、独立跑通自己的 README 示例**；主仓每月只加一行依赖版本，集成冒烟测试保证链路不断。这样既满足"每月一个项目"，又不牺牲体系完整性。

**v0.1.1 当前实际目录**：

```
2026-11_epibulletin/
├── epi-core/                  # 本月卫星仓：正式 R 包（可单独 install + check）
│   ├── R/ man/ tests/ inst/  # 源码 / 文档 / 40 项单测 / schema.json
│   └── README.md             # 包级独立说明
├── pipeline.R                 # 主仓统一编排入口（--list / --check / --all / --force）
├── R/                         # pipeline_plan.R 分层计划 + epi_json.R 零依赖 JSON
├── tests/                     # smoke_e2e.R + golden/ 契约基线（37 PASS）
├── .github/workflows/         # R-CMD-check.yaml + nightly-e2e.yml（含隐私守卫）
├── bootstrap_core.R           # 断网可用的包加载引导
├── vertical_slice/run_e2e.R   # 合成数据六层全通（L0/L1 走 epiCore）
├── case_hfrs_real/run_hfrs.R  # HFRS 真实数据实测（--monthly 可切粒度）
│   └── output/                # 本地产物，已排除入库
├── prototype/                 # v1 的 L5 周报原型（保留可用）
├── pipeline_out/              # 编排产物 + 静态报告站，已排除入库
├── 项目进展看板.html + kanban_data.js
├── renv.lock / CHANGELOG.md / LICENSE / .gitignore
└── README.md（中文） + README.en.md（英文）
```

---

## 4. 端到端用例（首个真实验收场景）

> 陕西 HFRS 2005–2025 月度县级发病计数（只读） + CLCD 逐年景观格局 + 气象/七普人口
> → L1 质控 → L2 季节性异常预警 → L3 990m 网格景观指数 + BYM2 风险制图 → L4 城乡/SES 不平等分解
> → L5 一份综合 HTML 报告（预警清单 + 风险格网 + 集中曲线）→ L6 可复现 manifest 与每月定时重跑

这条链同时覆盖你清单的 A（监测）、B（贝叶斯制图）、C（空间工具）、E（不平等）、F（通用统计）五区，且**不需要下载任何新数据**即可先跑通。

---

## 5. 已经跑通的最小切片（不是纸面方案）

```bash
cd "/f/00在研项目/05_Github/2026-11_epibulletin/vertical_slice"
"/d/R/bin/x64/Rscript.exe" run_e2e.R
```

**实测输出（2026-11-10，R 4.6.0，1.5 秒；L0/L1 已换成 `epiCore` 正式包函数）**：

```
[epi-core] 加载方式: installed ｜ 契约版本 0.1.0
[L0 epi-core ] 契约 v0.1.0 校验通过；原始面板 4161 行、16 地区；邻接 16x16
[L1 epi-ingest] read_counts() 质控剔除 2 行（重复 1 / 缺失 1）；清洁契约表 4159 行
[L2 epi-alert ] 季节性基线带 832 组；评估 816 期；异常信号 56 条；注入的 6 周暴发全部命中告警
[L3 epi-space ] rook 权重 16×16；Moran's I = 0.441（置换检验 p = 0.031，显著空间集聚）
[L4 epi-ineq  ] 集中指数 CI = -0.067（负担偏向低 SES 地区）；低/高 SES 报告率比 = 1.23
[L5 epi-report] 单文件综合报告（15 KB，内联 3 张 SVG 图 + 3 张表，断网可开）
[L6 epi-flow  ] run_manifest.json + 4 个阶段缓存（rds），固定种子 20261110
```

每层都是**真实计算而非占位符**：质控真的检出并剔除了脏数据；Moran's I 做了 999 次置换检验；集中指数按人口加权；报告含时序基线带、地区率格网热力图、集中曲线；manifest 是合法 JSON（已解析校验）。
**换成正式包后所有数值与原实现逐位一致**，这是"换层不炸链路"的第一次实证。

### W1 已交付：`epi-core/` 正式 R 包（v0.1.0）

| 组件 | 内容 |
|---|---|
| `R/contract.R` | 版本化 schema、`validate_contract()`（字段/类型/主键/非负计数/正分母） |
| `R/region.R` | `normalize_region()`、`epi_region_codes()`（BOM、空白、行政后缀、别名） |
| `R/adjacency.R` | `epi_adjacency()` 格网 rook/queen、`epi_read_graph()` 真实 INLA 邻接、行标准化与体检 |
| `R/qc.R` | `epi_qc()` 五类脏数据逐行留痕 |
| `R/read_counts.R` | **L0+L1 主入口**，返回 `epi_contract`（data/geo/W/qc/meta），支持 week / month / quarter / year 与 auto 推断 |
| `R/period.R` | 季节周期映射与跨年回绕 |
| `inst/contract/schema.json` | 机器可读契约；`tests/` 40 项 base R 单测；`man/` 6 份 Rd 文档 |

包可 `R CMD INSTALL` + `library(epiCore)`；断网时 `bootstrap_core.R` 自动回退源码加载。
`R CMD check`（源码 tarball）：**0 ERROR、0 NOTE、1 WARNING** —— 唯一 WARNING 是 R 源码含 UTF-8 中文注释与中文质控表头的可移植性提示，功能不受影响；提交 CRAN 前统一转 `\uXXXX` 转义即可。

---

## 5.1 W4 · 面板适配器与模拟数据演示

> **公开仓库不含、也不需要任何真实监测数据。** 默认链路全部使用
> [demo/make_demo_data.R](demo/make_demo_data.R) 生成的纯合成数据（31 个 `D01`–`D31` 地区、
> 固定种子 `20261110`），任何人 clone 后一条命令即可复现；真实面板只在本机通过私有配置接入。

```bash
# 默认：内置模拟数据，六层全通
Rscript case_hfrs_real/run_hfrs.R

# 月度链路同样用模拟数据（地区编码与面板一致）
Rscript case_hfrs_real/run_hfrs.R --monthly case_hfrs_real/output/demo_data/demo_counts_month.csv

# 仅在本机、且已配置私有数据时：
#   cp case_hfrs_real/data_paths.example.R case_hfrs_real/data_paths.local.R  # 填自己的路径
Rscript case_hfrs_real/run_hfrs.R --local
```

**模拟数据演示结果（最新年评估，纯合成）**：

| 指标 | 结果 |
|---|---|
| 契约记录 / 质控 | 651 行 / 剔除 0 行 |
| 最新年样本合计 | 2131 例（历史中位数 6449，−67.0%）→ 单侧升高预警 0 条 |
| 单年 Moran's I | 0.406 (p = 0.003)，SES 空间梯度使集聚信号显著 |
| 多年累积 Moran's I | 0.858 (p = 0.001) |
| 集中指数 CI | −0.113；低/高 SES 组率比 1.45 |
| 月度演示 | 1116 行 / 372 地区-期 / 11 条升高信号（季节性基线带） |

产物：`case_hfrs_real/output/面板分析报告_模拟.html`（单文件、内联 SVG、含口径声明）、
`run_manifest_panel_模拟.json`、`alerts_panel_模拟.csv`。`output/` 整个目录已在 `.gitignore` 中排除。

**本机私有面板**：路径只写在不入库的 `case_hfrs_real/data_paths.local.R`（模板
[data_paths.example.R](case_hfrs_real/data_paths.example.R)），或用 `EPISTACK_HFRS_*` 环境变量注入。
本机已完成一次真实面板端到端验收，**数据与结果均不公开**；其口径为年刊的地区-年发病率，
月度面板仅含气候协变量、没有发病结局，因此按年际单侧基线检测，绝不把推算值伪装成月度实测。
拿到月度直报 CSV 后 `--monthly` 可一键切到 `time_step="month"`，上下游契约不变。

---

## 5.2 W2/W3 · 主仓编排、golden 冒烟测试与 CI

**一条命令跑全部交付**（默认只跑合成数据，CI 上不需要、也读不到任何真实监测数据）：

```bash
cd "/f/00在研项目/05_Github/2026-11_epibulletin"
"/d/R/bin/x64/Rscript.exe" pipeline.R --list              # 打印 L0–L6 分层计划
"/d/R/bin/x64/Rscript.exe" pipeline.R --check             # 跑链路 + golden 集成冒烟测试
"/d/R/bin/x64/Rscript.exe" pipeline.R --all --check       # 额外跑本机 HFRS 真实链路
"/d/R/bin/x64/Rscript.exe" pipeline.R --force             # 忽略指纹缓存强制重跑
```

**W2 · targets 雏形**：`R/pipeline_plan.R` 是主仓唯一"每月改一行"的地方——把某层的
`current_impl` 从 `thin` 改成 `formal`、`impl` 指向当月卫星仓即可，上下游契约不变。
`pipeline.R` 用 **输入指纹（脚本 + 包源码的 md5）** 实现 targets 的
skip-if-unchanged：指纹未变且产物齐全就跳过；已实测「脚本改动 → 该阶段自动重跑、
未改动阶段保持 cached」。统一产出 `pipeline_out/pipeline_manifest.json`（7 层状态、
每阶段耗时、契约版本、冒烟结果、隐私声明）与 `pipeline_out/site/`（合成报告 + 看板导航页）。
2027-08 的 `epi-flow` 只需替换执行器，不改计划文件描述的层级与产物契约。

**W2 · 契约 golden-file**：`tests/golden/vertical_slice_v0.1.0.json` 固化固定种子下的
27 项指标；`tests/smoke_e2e.R` 重跑六层链路并做 10 项结构断言（L0–L5 阶段齐全、
4 个阶段缓存、HTML 完整性、**注入的 6 周暴发必须全部命中最高级告警**、契约探针的
字段/质控/权重行和等）。合计 **37 PASS / 0 FAIL**，失败即非零退出。
有意改变口径时用 `Rscript tests/smoke_e2e.R --update` 重生成基线，但必须人工审阅 diff。

**W3 · 工程化**：

| 文件 | 作用 |
|---|---|
| `.github/workflows/R-CMD-check.yaml` | push/PR：`R CMD build` + `check`（**0 ERROR 门禁**）+ `pipeline.R --check`，上传日志与合成报告站 |
| `.github/workflows/nightly-e2e.yml` | 每晚（北京 02:00）重跑链路 → **隐私守卫**（站点里出现 `*HFRS*` / `*真实*` / `*.rds` 即失败）→ GitHub Pages 发布 |
| `renv.lock` | 零第三方依赖基线快照（R 4.6.0 + CRAN）；将来引入依赖时用 `renv::snapshot()` 覆盖 |
| `README.en.md` | 英文版说明（架构、Quickstart、包 API、验证、CI、隐私、路线图） |
| `R/epi_json.R` | base R 极简 JSON 读写，保证 L6 manifest / golden / pipeline 状态在断网环境可解析，不引入 jsonlite |

> Pages 首次使用需在仓库 Settings → Pages 把 Source 设为 **GitHub Actions**。
> 站点只发布**合成数据报告 + 项目看板**；HFRS 真实数据及其分析报告留在本机 `pipeline_out/hfrs_year/`，
> 已被 `.gitignore` 排除，不入库、不上传、不发布。

**本机实测（2026-11-10，R 4.6.0）**：`pipeline.R --check` → 1 阶段 cached + 37 PASS；
`--all --check` → `vertical_slice:cached, hfrs_year:ran`（真实链路 4/4 产物齐全）；
`pipeline_manifest.json` 已用 JSON 解析器交叉校验；`pipeline_out/site/` 4 个文件（index / report / kanban.html / kanban_data.js）。

---

## 6. 十二个月路线图（每月一个可发布仓库）

> **完整状态表、逐月更新 SOP 与版本约定见 [ROADMAP.md](ROADMAP.md)**；每月任务归档在 [docs/monthly/](docs/monthly/2026-11.md)，本月为 [2026-11](docs/monthly/2026-11.md)。以下为速览。

| 月份 | 卫星仓 | 加厚层 | 当月可独立交付的东西 |
|---|---|---|---|
| **2026-11** | `epi-core` + 薄切片 | L0 / L6 | ✅ **v0.1.0 已发布**：正式 R 包（40 项单测 + R CMD check）、六层全通、HFRS 真实数据实测、v0.1 tag |
| 2026-12 | `epi-ingest` | L1 | 多源读取器 + 质控报告；支持栅格协变量 zonal stats |
| 2027-01 | `epi-alert` | L2 | 4 种预警算法统一接口 + 阈值配置；`WarnEpi`/`surveillance` 适配器 |
| 2027-02 | `epi-space-basic` | L3 | Moran/LISA/热点图、GWR/MGWR |
| 2027-03 | `epi-space-bayes` | L3 | BYM2/INLA 模板、景观格局指数（直接抽自 HFRS 流水线） |
| 2027-04 | `epi-ineq` | L4 | CI/SII/分解 + 中文报告（呼应统计大赛课题） |
| 2027-05 | `epi-access` | L4 | OSM 路网出行时间、基层医疗服务区 delineation |
| 2027-06 | `epi-report` | L5 | 综合报告系统：多层结果自动汇编、可开关脱敏 |
| 2027-07 | `epi-dashboard` | L5 | 交互式看板 / GitHub Pages 发布 |
| 2027-08 | `epi-flow` | L6 | `targets` 全流水线、`renv`、CI、定时重跑 |
| 2027-09 | `epi-geoai` | L3 / D | 遥感协变量批处理、GeoFM 评测审计（清单 D32–D35 新趋势） |
| 2027-10 | `epistack 1.0` | 全层 | 集成发布 + HFRS 完整案例复现 + 文档站 |

> 每个月都有**能单独发出去的成果**，同时把体系里对应那一层从"薄实现"换成"正式实现"；
> 月末打 `vX.Y` tag 并创建一个 GitHub Release，Release notes 指向当月归档。

---

## 7. 关键技术决策

| 决策 | 选择 | 理由 |
|---|---|---|
| 语言边界 | **R 为主**；Python 只在栅格/GeoAI 侧，落盘 CSV/GeoTIFF 交换 | 你的主力是 R 4.6.0；避免 `reticulate` 把整条链拖进双环境依赖 |
| 重依赖处理 | INLA / Stan / GeoAI 一律放 `Suggests`，装不上也能跑 L0–L2、L5、L6 | **保证"断网、只装 base R 也能端到端跑通"**，这是体系不烂尾的底线 |
| 编排 | v0.1.1：`pipeline.R` 声明式分层计划 + md5 指纹缓存 + 统一 manifest（targets 雏形）；2027-08 换真 `targets` | 先让链路存在、再让链路可缓存，最后才谈完整工程化 |
| 依赖锁定 | 零第三方 `renv.lock` + GitHub Actions `R-CMD-check` + 每晚 e2e | 别人 clone 一条 `Rscript pipeline.R --check` 就能跑 |
| 测试 | 40 项包单测 + **契约 golden-file**（27 指标）+ 端到端冒烟（10 结构断言，注入暴发必须命中）= 37 PASS | 链路断了当晚定时任务就会红 |
| 隐私 | 原始面板只读；仓库只放合成数据；CI 不跑 `--all`；Pages 发布前有隐私守卫 | 符合原始数据保护规则，真实监测数据不上传、不发布 |
| 报告 | 手写内联 SVG，不用 pandoc / rmarkdown / Shiny | 输出单文件 HTML，收件方零安装 |

---

## 8. 体系级验收标准（v0.1 / 1.0）

- **v0.1（2026-11-10 已达成，tag `v0.1`）**：`Rscript run_e2e.R` 一条命令，从只读原始面板到含六层结果的综合 HTML 报告 + manifest；换 L0/L1 为 `epiCore` 正式包后数值逐位不变；注入暴发 6 周全中；`R CMD INSTALL` + `library(epiCore)` 可用，40 项单测通过，`R CMD check` 0 ERROR；HFRS 真实面板（651 行 / 31 省 / 2004–2024）本地端到端实测完成，真实数据不入库。✅
- **v0.1.1（2026-11-10 已达成）**：`Rscript pipeline.R --check` 一条命令跑通编排 + golden 冒烟（37 PASS / 0 FAIL）；指纹缓存与改动触发重跑已验证；`--all` 下真实链路 4/4 产物齐全；统一 `pipeline_manifest.json` + 静态报告站；GitHub Actions 两个工作流、零依赖 `renv.lock`、中英文 README 齐备。✅
- **1.0（2027-10）**：`targets::tar_make()` 一键复现 HFRS 完整案例；任一卫星仓可单独 `install_github()` 并跑通自身 README 示例；`R CMD check` 全绿；中文文档站 + 英文 README。

---

## 9. 最大的风险：范围失控（对策已内置）

| 风险 | 对策 |
|---|---|
| 体系太大，半年后什么都没发布 | **薄切片先行**：本月已有六层全通；每月只加厚一层，且当月必须能独立发 Release |
| 主仓膨胀成"什么都装"的巨石 | 主仓只放契约/编排/集成；重算法全在卫星仓，通过契约调用 |
| 换一层导致上下游崩 | 契约 schema 有版本与 golden-file 测试；集成冒烟测试每晚跑 |
| 被质疑"和现成包重复" | L2–L4 明确写成适配器并致谢，README 首屏给竞品差异表 |
| 算法口径被同行挑刺 | 阈值可配置、报告强制免责声明、文档标注方法学出处 |
| 中文/编码在他人机器乱码 | 全链路 UTF-8、HTML 内嵌 charset、CI（Ubuntu）覆盖 UTF-8 路径；Windows 本机 R 4.6.0 已实测；`R CMD check` 需在无 `LC_ALL/LANG` 干扰的环境执行（见 CHANGELOG 踩坑记录） |

---

## 10. 本月四周排期（四周全部完成，均提前）

| 周 | 交付 |
|---|---|
| W1（11/11–11/17） | ✅ **提前完成**：`epi-core` 正式包（schema / 地区编码 / 邻接权重 / `read_counts()`）、40 项单测、Rd 文档、R CMD check；切片 L0/L1 已替换为包调用且回归一致 |
| W2（11/18–11/24） | ✅ **提前完成**：`pipeline.R` 声明式编排 + md5 指纹缓存 + 统一 manifest；契约 golden-file（27 指标）与集成冒烟（10 项结构断言）= 37 PASS / 0 FAIL；`R/epi_json.R` 零依赖 JSON 读写 |
| W3（11/25–12/01） | ✅ **提前完成**：`R-CMD-check.yaml`（build + check 0 ERROR 门禁 + 冒烟）、`nightly-e2e.yml`（每晚 e2e + 隐私守卫 + Pages）、零依赖 `renv.lock`、`README.en.md` 英文说明 |
| W4（12/02–12/08） | ✅ **提前完成**：HFRS 真实数据本地实测（省-年面板 + 真实邻接 + 真实 SES）、`--monthly` 月度切换接口、CHANGELOG、MIT、中英文说明、`v0.1` tag。**口径修正**：本机无真实月度发病序列，月度链路仅完成合成数据接口冒烟，待月度直报数据接入后补实测 |

> 四周工作已在 11/10 当天全部落地（`v0.1` 与 `v0.1.1` 两个 tag）。
> **下一步（12 月，卫星仓 `epi-ingest`）**：把 L1 的 `epi_qc()` 扩成多源读取器 + 质控报告 +
> 栅格协变量 zonal stats，仍按「可独立安装、可 `R CMD check`」的标准发布；主仓只需把
> `R/pipeline_plan.R` 里 L1 的 `current_impl` 改成 `formal`。

---

## 11. 发布与逐月更新

本仓库采用「**一次发布总体 + 按月增量更新**」：先把体系设计、数据契约、可运行链路与本月任务一次性公开，之后每月只更新对应卫星仓与文档，主仓结构保持稳定。

| 内容 | 文件 | 更新频率 |
|---|---|---|
| 体系总体（架构 / 契约 / HFRS 用例 / 验收 / 竞品） | [README.md](README.md) · [README.en.md](README.en.md) | 架构变更时 |
| 12 个月状态表 + 逐月更新 SOP + 版本/隐私约定 | [ROADMAP.md](ROADMAP.md) | **每月** |
| 当月任务、验收、实测、踩坑、下月交接 | [docs/monthly/2026-11.md](docs/monthly/2026-11.md)（模板 [TEMPLATE.md](docs/monthly/TEMPLATE.md)） | **每月新建一份** |
| 版本变更明细 | [CHANGELOG.md](CHANGELOG.md) | 每次发版 |
| 任务状态看板 | [项目进展看板.html](项目进展看板.html) + `kanban_data.js` | 状态变化时只改数据文件 |
| 正式 R 包 | `epi-core/` | 卫星仓发版时 |

**月度固定动作**：新建归档 → 发布卫星仓 → 主仓 `current_impl` 改一行 → `pipeline.R --all --check` + golden 冒烟 → 同步四处状态 → 打 `vX.Y` tag + 创建月度 Release。详见 [ROADMAP.md 第 4 节](ROADMAP.md)。

**已发布**：[v0.1](https://github.com/Rythonme/EpiStack/releases/tag/v0.1)（立项）· [v0.1.1](https://github.com/Rythonme/EpiStack/releases/tag/v0.1.1)（W2/W3 工程化收尾，本月正式版本）。
**下月**：2026-12 · `epi-ingest` · `v0.2`。
**报告站**：[rythonme.github.io/EpiStack](https://rythonme.github.io/EpiStack/)（仅合成数据，每晚自动更新）。

> 公开仓库**不含任何真实监测数据**：所有示例与 CI 默认使用 `demo/make_demo_data.R` 生成的模拟面板；本机私有面板只通过不入库的配置接入，数据与结果不公开；站点发布带隐私守卫。

---

## 附录：竞品直验（2026-11-10，链接均实际访问）

| 仓库 | 定位 | 本体系的关系 |
|---|---|---|
| [`avallecam/epichannel`](https://github.com/avallecam/epichannel) | endemic channel 基线带，多年未维护 | L2 适配器可选后端之一 |
| [`pan-mingyue/WarnEpi`](https://github.com/pan-mingyue/WarnEpi) | CRAN 2025，EWMA/mCUSUM/调整 Serfling | L2 适配器，仅输出标志位 |
| [`EU-ECDC/EpiSignalDetection`](https://github.com/EU-ECDC/EpiSignalDetection) | Farrington/GLRNB + Shiny + HTML 报告 | L2/L5 差异化参考；绑定 ECDC Atlas 与 pandoc |
| [`R4EPI/sitrep`](https://github.com/R4EPI/sitrep) | 暴发调查 Rmd→Word 模板 | L5 参考；手工模板，非常规监测链路 |

清单 A–F 区其余 153 条资源为 L2–L5 的算法池；本体系不重写它们，只负责把它们编排成一条可复现、可交付的链路。

---

*v2 体系设计：2026-11-10 ｜ 首次公开发布：2026-11-11（[github.com/Rythonme/EpiStack](https://github.com/Rythonme/EpiStack)）｜ 依据 `Github/GitHub资源检索清单.md`（153 条、Top10 思路，更新至 2026-11-09）+ 本机实测*
