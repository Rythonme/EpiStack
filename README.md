# EpiStack

把原始传染病监测数据，变成可发布的异常预警、空间风险图和健康不平等分析报告。
纯 R 实现，零第三方依赖，断网可跑。

[English](README.en.md) · 版本 `v0.5.0` · [更新日志](CHANGELOG.md) · [路线图](ROADMAP.md)

[![R-CMD-check](https://github.com/Rythonme/EpiStack/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/Rythonme/EpiStack/actions/workflows/R-CMD-check.yaml) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## 它是什么

一条分层的分析链路。每层只做一件事，层与层之间只通过同一份数据契约交互，因此可以单独使用其中任意一层，也可以整条跑。

| 层 | 包 | 作用 | 输入 → 输出 |
|---|---|---|---|
| L0 | `epiCore` | 数据契约、地区编码、邻接权重 | 原始表 → 契约长表 |
| L1 | `epiIngest` | 多源读取与质控 | CSV / Excel / 数据库 / API → 干净长表 |
| L2 | `epiAlert` | 季节性基线、异常信号 | 长表 → 预警清单 |
| L3 | `epiSpace` | Moran / LISA / BYM2 | 长表 + 权重 → 风险图 |
| L3.5 | `epiRobust` | MAUP / 权重 / 空间稳健 SE / 多重比较 | 长表 + 权重 → 体检报告 |
| L4 | `epiIneq` | 集中指数 / SII / 分解 | 长表 + SES → 不平等指标 |
| L5 | `epiReport` | 单文件 HTML 报告 | 各层结果 → 可转发成果 |
| L6 | `epiFlow` | 编排与可复现清单 | 全部 → 一键复现 |

已发布 L0（`epiCore`）、L1（`epiIngest`）、L2（`epiAlert`）、L3（`epiSpace`）、L3.5（`epiRobust`）与 L4（`epiIneq`），其余层按月发布，接口不变。

契约——所有层只认这三样东西：

```r
# 长表
date · region · count · population · disease

# 地理与社会经济编码
geo   # region, population, ses, row/col 或行政区划代码

# 邻接权重（行标准化、对称、无孤岛）
W
```

## 安装

```r
# L0 契约与读取
install.packages(
  "https://github.com/Rythonme/EpiStack/releases/download/v0.1.2/epiCore_0.1.1.tar.gz",
  repos = NULL, type = "source"
)

# L1 多源接入与质控
install.packages(
  "https://github.com/Rythonme/EpiStack/releases/download/v0.2.1/epiIngest_0.2.1.tar.gz",
  repos = NULL, type = "source"
)

# L2 季节性基线与预警分级
install.packages(
  "https://github.com/Rythonme/EpiStack/releases/download/v0.3.0/epiAlert_0.1.0.tar.gz",
  repos = NULL, type = "source"
)

# L3 空间自相关与热点识别
install.packages(
  "https://github.com/Rythonme/EpiStack/releases/download/v0.4.0/epiSpace_0.1.0.tar.gz",
  repos = NULL, type = "source"
)

# L3.5 空间稳健性体检
install.packages(
  "https://github.com/Rythonme/EpiStack/releases/download/v0.6.0/epiRobust_0.1.0.tar.gz",
  repos = NULL, type = "source"
)

# L4 集中指数 / SII / 分解 / 可达性
install.packages(
  "https://github.com/Rythonme/EpiStack/releases/download/v0.5.0/epiIneq_0.1.0.tar.gz",
  repos = NULL, type = "source"
)

library(epiCore); library(epiIngest); library(epiAlert); library(epiSpace); library(epiRobust); library(epiIneq)
```

纯 R，无需编译工具，也不需要 Rtools。开发版安装方式见 [epi-core/README.md](epi-core/README.md)、
[epi-ingest/README.md](epi-ingest/README.md)、[epi-alert/README.md](epi-alert/README.md)、
[epi-space/README.md](epi-space/README.md)、[epi-robust/README.md](epi-robust/README.md) 与 [epi-ineq/README.md](epi-ineq/README.md)。

## 快速开始

```bash
git clone https://github.com/Rythonme/EpiStack.git
cd EpiStack

Rscript pipeline.R --check     # 跑通全链路 + 结果自检
Rscript pipeline.R --list      # 只看分层计划
```

运行结果在 `pipeline_out/`：

- `site/index.html` —— 报告站，浏览器打开即可
- `pipeline_manifest.json` —— 本次运行的清单（各层状态、耗时、契约版本）
- `<stage>/` —— 各层的 HTML 报告、预警 CSV、阶段缓存

单独跑某条链路（都在仓库根目录执行）：

```bash
Rscript vertical_slice/run_e2e.R      # 六层示例，合成数据
Rscript alert_demo/run_alert.R        # 预警演示：基线 → 分级 → 回溯评估
Rscript space_demo/run_space.R        # 空间演示：Moran → LISA → 热点
Rscript case_panel/run_panel.R        # 面板示例，内置模拟数据
```

四条命令都不需要外部数据，clone 下来直接可跑。

## 用 `epiCore` 读自己的数据

```r
library(epiCore)

core <- read_counts(
  "counts.csv",
  geo       = geo,                 # region, population, ses, row, col
  time_step = "month",             # week / month / quarter / year / auto
  graph     = "provinces.graph",   # 可选：INLA 邻接；有 row/col 时自动按格网建邻接
  mapping   = list(date = "报告日期", region = "省份", count = "发病数")
)

core$data                # date region count population disease year period
core$geo                 # 规范化地区码表
core$W                   # 邻接权重矩阵
core$qc$report           # 每一项质控检出多少行
validate_contract(core)  # TRUE 表示通过
```

`read_counts()` 会依次完成：列名别名匹配 → BOM、空白、行政后缀清理 → 日期解析（`YYYY` / `YYYY-MM` / `YYYY-MM-DD`）→ 主键去重与脏行剔除 → 人口分母回填 → 周期映射 → 邻接权重构建 → 契约校验。

| 函数 | 作用 |
|---|---|
| `read_counts()` | 读取与契约主入口，返回 `epi_contract` 对象 |
| `validate_contract()` / `epi_contract_check()` | 严格 / 非严格契约校验 |
| `epi_schema()` | 版本化契约定义（与 `inst/contract/schema.json` 同步） |
| `normalize_region()` / `epi_region_codes()` | 地区编码规范化与码表生成 |
| `epi_adjacency()` / `epi_read_graph()` | 格网 rook/queen 邻接、INLA `.graph` 邻接 |
| `epi_qc()` | 可单独调用的质控器 |
| `epi_period()` / `epi_wrap_period()` / `epi_period_label()` | week / month / quarter / year 周期映射 |

时间粒度切换只改一个参数：

```r
read_counts(x, time_step = "week")     # 52 期
read_counts(x, time_step = "month")    # 12 期
read_counts(x, time_step = "quarter")  # 4 期
read_counts(x, time_step = "year")     # 年序号
read_counts(x, time_step = "auto")     # 按日期间隔推断
```

## 用 `epiIngest` 接脏数据

```r
library(epiIngest)

src <- ingest_source("csv", "counts.csv",
                     mapping = list(date = "日期", region = "省份", count = "发病数"))

ingest_profile(ingest_read(src))   # 先看：列类型、缺失率、日期范围、重复键

rules <- ingest_qc_default(geo)    # 默认规则 + 地区白名单
res   <- qc_apply(src, rules)      # error 剔除，warn 保留并标记，逐行留痕
qc_report(res, "质控单.html")       # 单文件报告，可直接发给数据提供方

core <- ingest_counts(src, rules = rules, geo = geo, time_step = "month")
core$ingest$n_dropped              # 规则剔除了多少行
```

规则可以存成文件跟着项目走，`qc_apply(src, "config/qc_rules.json")` 即可复用。
Excel / 数据库 / HTTP 接口 / 栅格协变量走可选适配器，缺包时
`epi_ingest_capabilities()` 会明确告诉你缺哪个。

## 用 `epiAlert` 做预警

```r
library(epiAlert)

x <- alert_counts(core)                 # 契约表 → 基线 → 超限 → 分级
x$alerts                                # 信号清单：日期 / 地区 / 计数 / 上界 / 连续期数 / 级别
x$summary                               # 按地区：各级条数、最高级别、最后信号

alert_report(x, "预警单.html")           # 单文件报告，可直接发出
alert_counts(core, assess = "latest")   # 当期监测口径：只评最新周期
```

基线只用评估期之前的历史（季节窗口取更早年份的同周期），因此回溯评估时本期不会给自己投票。
四种基线方法（`seasonal` / `pooled` / `moving` / `poisson`）按粒度自动选择，
`alert_methods()` 列出适用场景。

分级阈值是数据不是代码：`alert_rules(warn_ratio = 2, alarm_ratio = 3)` 改口径，
`alert_rules_write()` 存成 JSON 随项目版本管理。

## 用 `epiSpace` 看空间格局

```r
library(epiSpace)

x <- space_counts(core)                 # 契约 + 权重 → 全局 → 局部 → 热点
x$global                                # Moran's I 与置换 p 值
x$hotspots                              # 逐地区：局部 I、置换 p、HH/LL/HL/LH、类别
space_report(x, "空间分析单.html")       # 单文件报告，可直接发出
```

权重来自上游契约，也可用 `epiCore::epi_read_graph()` 读真实边界的邻接图；
格网数据用 `space_weights(geo, style = "rook")` 直接构造。

全局 Moran 用 999 次置换给出 p 值；局部 LISA 只在置换显著时标注热点（HH）、
冷点（LL）或空间离群（HL/LH）。观测值按权重矩阵的地区名对齐，换邻接定义
就要重新解释结果。需要贝叶斯模型时，`space_bym2_template()` 产出 INLA 的
数据与代码模板，本包不拟合、也不要求装 INLA。

## 用 `epiIneq` 看健康不平等

```r
library(epiIneq)

d <- ineq_example()                  # 4×4 虚构格网，SES 左低右高
x <- ineq_counts(d)                  # 曲线 → CI → SII → 分解 → 可达性
x$summary                            # 七项指标与解释
x$groups                             # 低/高 SES 两组的率与份额
x$decompose                          # 组间 / 组内 / 余量
ineq_report(x, "不平等分析单.html")   # 单文件报告
```

CI = 1 − 2×人口加权集中曲线下面积，负值表示负担偏向低 SES；SII 是两端预测率差。
CI、SII、率比方向一致才算证据。SES 与坐标从上游 `core$geo` 自动匹配；
没有坐标时跳过可达性，其余指标照常给出。`ineq_methods()` 列出各方法适用范围。

## 用 `epiRobust` 做空间稳健性体检

```r
library(epiRobust)

d <- robust_example(n_side = 6L)   # 6×6 虚构格网，无任何真实病例
x <- robust_check(d, scales = c(1L, 2L, 3L),
                  styles = c("rook", "queen", "knn"),
                  n_perm = 199L, seed = 20261124L)
x$verdicts                         # 四项检查各自的结论
x$maup$table                       # 多尺度 Moran / LISA / 热点数
robust_report(x, "稳健性体检报告.html")
```

体检回答的是「这个结论是不是分析选择造出来的」：换聚合尺度会不会翻转 Moran 符号、
换邻接定义会不会改变显著性、空间相关是否让标准误偏小、多重比较后还剩几个热点。
演示中原始尺度 I = +0.9055，3× 聚合后翻转为 −0.0009，12 个显著热点校正后仅剩 1 个。
`robust_methods()` 列出各检查的适用边界；包本身只依赖 `stats` / `utils`。

## 数据与隐私

仓库只包含合成数据：`demo/make_demo_data.R` 用固定种子生成 31 个虚构地区（`D01`–`D31`）的面板，不对应任何真实行政区。所有示例和默认链路都只跑这份数据。

真实监测数据不随仓库分发，也不上传。把路径写进不入库的 `case_panel/data_paths.local.R`（模板见 `data_paths.example.R`），或通过 `EPISTACK_PANEL_*` 环境变量传入即可；数据始终只读，产出留在本地。

## 目录

```
EpiStack/
├── epi-core/                  # L0：正式 R 包（源码 / 文档 / 单测 / schema）
├── epi-ingest/                # L1：正式 R 包（多源读取 / 质控 / 报告 / 脱敏）
├── epi-alert/                 # L2：正式 R 包（基线 / 分级 / 汇总 / 预警单）
├── epi-space/                 # L3：正式 R 包（Moran / LISA / 热点 / BYM2 模板）
├── epi-robust/                # L3.5：正式 R 包（MAUP / 权重 / Conley SE / 多重比较）
├── epi-ineq/                  # L4：正式 R 包（集中曲线 / CI / SII / 分解 / 可达性）
├── ingest_demo/               # L1 演示：合成数据 → 质控单 → 契约等价性
├── alert_demo/                # L2 演示：注入暴发 → 回溯评估 → 预警单
├── space_demo/                # L3 演示：注入角落聚集 → 热点识别 → 分析单
├── ineq_demo/                 # L4 演示：弱势负担格网 → CI/SII → 分解 → 可达性
├── robust_demo/               # L3.5 演示：多尺度 / 多邻接 → 稳健性体检报告
├── demo/                      # 合成数据生成器
├── vertical_slice/            # 六层端到端示例
├── case_panel/                # 面板用例（默认模拟数据，--local 读本地私有数据）
├── pipeline.R                 # 编排入口
└── tests/                     # 端到端自检与基线
```

## 文档

- 在线示例：[rythonme.github.io/EpiStack](https://rythonme.github.io/EpiStack/)（报告与看板）
- [ROADMAP.md](ROADMAP.md) —— 各层发布状态
- [docs/monthly/](docs/monthly/) —— 每个发布周期的说明与实测结果
- [CHANGELOG.md](CHANGELOG.md) —— 变更日志
- [epi-core/README.md](epi-core/README.md) —— L0 包的使用与安装细节
- [epi-ingest/README.md](epi-ingest/README.md) —— L1 包的使用与安装细节
- [epi-alert/README.md](epi-alert/README.md) —— L2 包的使用与安装细节
- [epi-space/README.md](epi-space/README.md) —— L3 包的使用与安装细节
- [epi-robust/README.md](epi-robust/README.md) —— L3.5 包的使用与安装细节
- [epi-ineq/README.md](epi-ineq/README.md) —— L4 包的使用与安装细节

## 许可

MIT
