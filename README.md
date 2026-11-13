# EpiStack

把原始传染病监测数据，变成可发布的异常预警、空间风险图和健康不平等分析报告。
纯 R 实现，零第三方依赖，断网可跑。

[English](README.en.md) · 版本 `v0.1.1` · [更新日志](CHANGELOG.md) · [路线图](ROADMAP.md)

[![R-CMD-check](https://github.com/Rythonme/EpiStack/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/Rythonme/EpiStack/actions/workflows/R-CMD-check.yaml) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## 它是什么

一条分层的分析链路。每层只做一件事，层与层之间只通过同一份数据契约交互，因此可以单独使用其中任意一层，也可以整条跑。

| 层 | 包 | 作用 | 输入 → 输出 |
|---|---|---|---|
| L0 | `epiCore` | 数据契约、地区编码、邻接权重 | 原始表 → 契约长表 |
| L1 | `epiIngest` | 多源读取与质控 | CSV / Excel / 数据库 / API → 干净长表 |
| L2 | `epiAlert` | 季节性基线、异常信号 | 长表 → 预警清单 |
| L3 | `epiSpace` | Moran / LISA / BYM2 | 长表 + 权重 → 风险图 |
| L4 | `epiIneq` | 集中指数 / SII / 分解 | 长表 + SES → 不平等指标 |
| L5 | `epiReport` | 单文件 HTML 报告 | 各层结果 → 可转发成果 |
| L6 | `epiFlow` | 编排与可复现清单 | 全部 → 一键复现 |

已发布 L0（`epiCore`），其余层按月发布，接口不变。

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
install.packages(
  "https://github.com/Rythonme/EpiStack/releases/download/v0.1.1/epiCore_0.1.0.tar.gz",
  repos = NULL, type = "source"
)
library(epiCore)
```

纯 R，无需编译工具，也不需要 Rtools。开发版安装方式见 [epi-core/README.md](epi-core/README.md)。

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

单独跑一条链路：

```bash
cd vertical_slice && Rscript run_e2e.R          # 合成数据六层示例
Rscript case_hfrs_real/run_hfrs.R               # 内置模拟面板（默认，无需配置）
```

两条命令都不需要任何外部数据，clone 下来直接可跑。

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
| `read_counts()` | L0 + L1 主入口，返回 `epi_contract` 对象 |
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

## 数据与隐私

仓库只包含合成数据：`demo/make_demo_data.R` 用固定种子生成 31 个虚构地区（`D01`–`D31`）的面板，不对应任何真实行政区。所有示例和默认链路都只跑这份数据。

真实监测数据不随仓库分发，也不上传。把路径写进不入库的 `case_hfrs_real/data_paths.local.R`（模板见 `data_paths.example.R`），或通过 `EPISTACK_HFRS_*` 环境变量传入即可；数据始终只读，产出留在本地。

## 目录

```
EpiStack/
├── epi-core/                  # L0：正式 R 包（源码 / 文档 / 单测 / schema）
├── demo/                      # 合成数据生成器
├── vertical_slice/            # 六层端到端示例
├── case_hfrs_real/            # 面板用例（默认模拟数据，--local 读本地私有数据）
├── pipeline.R                 # 编排入口
└── tests/                     # 端到端自检与基线
```

## 文档

- [ROADMAP.md](ROADMAP.md) —— 各层发布状态
- [docs/monthly/](docs/monthly/) —— 每月任务与实测记录
- [CHANGELOG.md](CHANGELOG.md) —— 变更日志
- [epi-core/README.md](epi-core/README.md) —— 包的使用与安装细节

## 许可

MIT
