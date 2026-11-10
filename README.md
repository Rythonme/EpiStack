# EpiStack — 端到端传染病时空分析与健康不平等体系（v2）

> **当前版本 `v0.1.0`（2026-11-10 已打 tag）**：`epi-core` 正式 R 包 + 六层端到端切片 + HFRS 真实数据实测。
>
> **v1 的 EpiBulletin 只是 L5 一层，现升级为完整体系。**
>
> **一句话**：从只读原始监测面板出发，经数据质控 → 监测预警 → 时空建模 → 不平等测度 → 综合报告 → 可复现编排，形成一条**一条命令跑通 L0→L6** 的开源体系；每月发布一个可独立安装的卫星仓加厚其中一层，年底集成成 `EpiStack 1.0`。
>
> **最重要的一条设计判断**：不要"先造半年零件、最后拼不起来"。**第一个月就打通一条薄而全的链路**，之后每月只替换某一层的实现，上下游契约不变，链路永远跑得通。这条链路今天已经在本机 R 4.6.0 跑通（见第 5 节实测）。

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
├── R/  pipeline.R             # targets 流水线，按层调用卫星仓
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

**v0.1 当前实际目录**：

```
2026-11_epibulletin/
├── epi-core/                  # 本月卫星仓：正式 R 包（可单独 install + check）
│   ├── R/ man/ tests/ inst/  # 源码 / 文档 / 40 项单测 / schema.json
│   └── README.md             # 包级独立说明
├── bootstrap_core.R           # 断网可用的包加载引导
├── vertical_slice/run_e2e.R   # 合成数据六层全通（L0/L1 走 epiCore）
├── case_hfrs_real/run_hfrs.R  # HFRS 真实数据实测（--monthly 可切粒度）
│   └── output/                # 本地产物，已排除入库
├── prototype/                 # v1 的 L5 周报原型（保留可用）
├── 项目进展看板.html + kanban_data.js
├── CHANGELOG.md / LICENSE / README.md / .gitignore
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

## 5.1 W4 · HFRS 真实数据端到端实测

```bash
cd "/f/00在研项目/05_Github/2026-11_epibulletin/case_hfrs_real"
"/d/R/bin/x64/Rscript.exe" run_hfrs.R
# 拿到月度直报 CSV 后：
"/d/R/bin/x64/Rscript.exe" run_hfrs.R --monthly your_monthly_counts.csv
```

**只读数据源**（全部本地、不入库）：`incidence_province_year.csv`（651 行，31 省 × 2004–2024）、
`prov_adj.graph`（真实 31 省邻接，海南已人工连广东）、
`analysis_panel_2012_2024.csv`（真实人均 GDP 作 SES）、
`panel_province_month.csv`（真实省-月气候面板 7812 行）。

> **必须说明的数据口径**：本机**没有真实 HFRS 月度发病序列**。年鉴是年刊，只提供省-年发病率，
> `cases_est` 是按人口反算的估计发病数；省-月面板只有气温/降水，**没有任何月度发病结局**。
> 因此默认实测按**年际单侧基线**做异常检测，绝不把推算值伪装成月度实测。
> 月度链路已用合成数据完成接口冒烟验证（1116 行、372 地区-期、检出 9 条信号），
> 拿到月度直报 CSV 后用 `--monthly` 一键切到 `time_step="month"` 的季节性基线带，上下游契约不变。

**真实数据实测结果（2024 年评估）**：

| 指标 | 结果 | 解读 |
|---|---|---|
| 契约记录 / 质控 | 651 行 / 剔除 0 行 | 真实面板完整，L0/L1 契约校验通过 |
| 2024 全国合计 | 5588 例（历史中位数 10643，**−47.5%**） | 长期下降 → 单侧升高预警 **0 条**，监测应同时关注"低于基线"的结构性变化 |
| 单年 Moran's I | −0.071 (p = 0.423) | 单年计数稀疏、检验功效不足 |
| 2004–2024 累积 Moran's I | 0.189 (p = 0.074) | 累积率下空间集聚信号才显现 |
| 集中指数 CI | −0.078 | 负担略偏向低人均 GDP 省份 |
| 低/高 GDP 组率比 | 0.81 | 与 CI 反向：陕西一省占全国 28.4%（4.00/10万），GDP 恰好略高于中位数被划入"高组"——说明单一中位数切点不稳健 |

产物：`output/HFRS真实数据实测报告.html`（单文件、3 张内联 SVG、含数据口径声明与三条发现）、
`output/run_manifest_hfrs.json`、`output/alerts_hfrs.csv`。**`output/` 整个目录已在 `.gitignore` 中排除**，真实数据及其聚合结果只在本地。

---

## 6. 十二个月路线图（每月一个可发布仓库）

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

> 每个月都有**能单独发出去的成果**，同时把体系里对应那一层从"薄实现"换成"正式实现"。

---

## 7. 关键技术决策

| 决策 | 选择 | 理由 |
|---|---|---|
| 语言边界 | **R 为主**；Python 只在栅格/GeoAI 侧，落盘 CSV/GeoTIFF 交换 | 你的主力是 R 4.6.0；避免 `reticulate` 把整条链拖进双环境依赖 |
| 重依赖处理 | INLA / Stan / GeoAI 一律放 `Suggests`，装不上也能跑 L0–L2、L5、L6 | **保证"断网、只装 base R 也能端到端跑通"**，这是体系不烂尾的底线 |
| 编排 | v0.1 用阶段 rds 缓存 + manifest；2027-08 换 `targets` | 先让链路存在，再谈工程化 |
| 依赖锁定 | `renv` + GitHub Actions `R-CMD-check` | 可复现，别人 clone 就能跑 |
| 测试 | 每层 golden-file 单测 + **端到端冒烟测试**（注入暴发必须命中） | 链路断了当天就能发现 |
| 隐私 | 原始面板只读；仓库只放合成数据；报告可 `show_counts=FALSE` | 符合原始数据保护规则，真实监测数据不上传 |
| 报告 | 手写内联 SVG，不用 pandoc / rmarkdown / Shiny | 输出单文件 HTML，收件方零安装 |

---

## 8. 体系级验收标准（v0.1 / 1.0）

- **v0.1（2026-11-10 已达成，tag `v0.1`）**：`Rscript run_e2e.R` 一条命令，从只读原始面板到含六层结果的综合 HTML 报告 + manifest；换 L0/L1 为 `epiCore` 正式包后数值逐位不变；注入暴发 6 周全中；`R CMD INSTALL` + `library(epiCore)` 可用，40 项单测通过，`R CMD check` 0 ERROR；HFRS 真实面板（651 行 / 31 省 / 2004–2024）本地端到端实测完成，真实数据不入库。✅
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
| 中文/编码在他人机器乱码 | 全链路 UTF-8、HTML 内嵌 charset、CI 覆盖 Windows/macOS/Linux |

---

## 10. 本月剩余动作（四周）

| 周 | 交付 |
|---|---|
| W1（11/11–11/17） | ✅ **提前完成**：`epi-core` 正式包（schema / 地区编码 / 邻接权重 / `read_counts()`）、40 项单测、Rd 文档、R CMD check；切片 L0/L1 已替换为包调用且回归一致 |
| W2（11/18–11/24） | 集成冒烟测试 + 契约 golden-file 版本化；`run_e2e.R` 改为主仓 `pipeline.R` 的 targets 雏形 |
| W3（11/25–12/01） | GitHub Actions：R-CMD-check + 每晚跑 e2e + gh-pages 报告；`renv.lock` |
| W4（12/02–12/08） | ✅ **提前完成**：HFRS 真实数据本地实测（省-年面板 + 真实邻接 + 真实 SES）、`--monthly` 月度切换接口、CHANGELOG、MIT、中英文说明、`v0.1` tag。**口径修正**：本机无真实月度发病序列，月度链路仅完成合成数据接口冒烟，待月度直报数据接入后补实测 |

> W1 与 W4 提前完成，W2/W3 的工程化（CI / renv / targets 雏形）仍是本月剩余工作。

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

*v2 体系设计：2026-11-10 ｜ 依据 `Github/GitHub资源检索清单.md`（153 条、Top10 思路，更新至 2026-11-09）+ 本机实测*
