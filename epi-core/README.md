# epiCore · EpiStack 的统一数据契约层（L0）

[![R](https://img.shields.io/badge/R-%3E%3D3.6.0-blue)](https://www.r-project.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green)](../LICENSE)
![Dependencies](https://img.shields.io/badge/dependencies-0-brightgreen)

> 一个**零第三方依赖**的 R 包：把一张原始监测计数表，变成所有下游模块都认的同一份契约。

## 为什么需要它

监测预警、空间建模、健康不平等、报告生成，本来是同一条链上的环节，却常常因为
「日期格式不一样 / 省名带不带后缀 / 人口分母叫 pop 还是 population / 邻接矩阵谁生成」
而拼不到一起。`epiCore` 把这些全部收敛到一个对象：

```
date · region · count · population · disease     # 长表（主键 date+region+disease）
+ geo：region, population, ses, row/col           # 地理与社会经济编码
+ W  ：行标准化、对称、无孤岛的邻接权重矩阵        # L3 / L4 共用
```

**换任何一层实现，上下游接口不变。**

## 安装

### 联网安装（推荐）

Release 附带构建好的源码 tarball，直接把 URL 交给 `install.packages()` 即可，不必 clone 仓库：

```r
install.packages(
  "https://github.com/Rythonme/EpiStack/releases/download/v0.1.1/epiCore_0.1.0.tar.gz",
  repos = NULL, type = "source"
)
library(epiCore)
```

纯 base R、无编译代码，Windows 不需要 Rtools。URL 里的 `v0.1.1` 固定了版本，写进分析脚本便于复现。
0.1.0 共 16 个导出函数，契约版本 0.1.0。

想跟开发分支、指定 tag 或提交，用 `remotes` / `pak`：

```r
remotes::install_github("Rythonme/EpiStack", subdir = "epi-core", ref = "v0.1.1")

# pak：自带解压器，不受下面的 tar 问题影响
pak::pkg_install("github::Rythonme/EpiStack/epi-core@v0.1.1")
```

> **Windows 注意**：仓库内存在中文命名的示例文件，`remotes` 默认调用的外部 `tar.exe`
> 在中文 locale 下会报 `input string ... is invalid`。先执行
> `Sys.setenv(TAR = "internal")` 再装即可（会有 pax header 警告，不影响安装）；
> 或者直接用上面的 URL 一行安装 / `pak`，完全绕开这个问题。

### 本地 / 离线

```bash
git clone https://github.com/Rythonme/EpiStack.git
R CMD INSTALL EpiStack/epi-core
# 或在本仓库根目录装到项目内 .rlib/：
# Rscript -e 'install.packages("epi-core", repos=NULL, type="source", lib=".rlib")'
```

断网 / 无构建工具时，`../bootstrap_core.R` 会按依赖顺序 `source()` `R/` 下的源码，
暴露完全相同的函数。

## 5 分钟上手

```r
library(epiCore)

raw <- data.frame(
  date      = as.character(rep(as.Date("2021-01-04") + 0:6, 2)),
  province  = rep(c("陕西省", "广东省"), each = 7),
  cases_est = c(3, 5, 4, 9, 7, 6, NA,       # 故意混入一条脏记录
                8, 9, 7, 11, 10, 8, 12),
  pop       = rep(c(39500000, 127000000), each = 7),
  stringsAsFactors = FALSE
)
geo <- data.frame(region = c("陕西", "广东"),
                  population = c(39500000, 127000000),
                  row = c(1L, 1L), col = c(1L, 2L),
                  ses = c(0.42, 0.78))

core <- read_counts(raw, geo = geo, time_step = "week",
                    mapping = list(date = "date", region = "province",
                                   count = "cases_est", population = "pop"))
core                       # 契约摘要
core$qc$report             # 每一项质控检出多少行
core$W                     # 邻接权重矩阵
validate_contract(core)    # 严格校验：TRUE 表示通过
```

`read_counts()` 会自动完成：列名别名匹配 → BOM / 空白 / 行政后缀清理 → 日期解析
（支持 `YYYY` / `YYYY-MM` / `YYYY-MM-DD`）→ 主键去重与脏行剔除 → 人口分母回填 →
周期映射 → 邻接权重构建 → 契约校验。

## 导出的函数

| 函数 | 作用 |
|---|---|
| `read_counts()` | 读取 + 契约主入口，返回 `epi_contract` 对象（含内置质控） |
| `validate_contract()` / `epi_contract_check()` | 严格 / 非严格契约校验 |
| `epi_schema()` | 返回版本化契约定义（与 `inst/contract/schema.json` 同步） |
| `normalize_region()` / `epi_region_codes()` | 地区编码规范化与码表生成 |
| `epi_adjacency()` | 规则格网 rook / queen 邻接权重 |
| `epi_read_graph()` | 读真实边界导出的 INLA `.graph` 邻接表 |
| `epi_row_standardize()` / `epi_adjacency_check()` | 行标准化与矩阵体检 |
| `epi_qc()` | 可单独调用的质控器 |
| `epi_period()` / `epi_wrap_period()` / `epi_period_label()` | week / month / quarter / year 周期映射 |

## 时间粒度

同一个 `read_counts()` 支持四种粒度，切换成本只有一个参数：

```r
read_counts(x, time_step = "week")     # 52 期，周报
read_counts(x, time_step = "month")    # 12 期，月报
read_counts(x, time_step = "quarter")  # 4 期
read_counts(x, time_step = "year")     # 年序号，年际趋势
read_counts(x, time_step = "auto")     # 按日期间隔自动推断
```

## 测试

```bash
Rscript tests/test_epi_core.R
```

40 项 base R 断言，覆盖 schema 校验、地区编码、周期映射、格网与 INLA 邻接、
质控留痕、`read_counts()` 主入口与年粒度自动推断。

### R CMD check

源码 tarball 检查结果：**0 ERROR、0 NOTE、1 WARNING**。
唯一 WARNING 为 `checking code files for non-ASCII characters` —— R 源码含 UTF-8 中文注释
与中文质控表头，在 UTF-8 环境下安装、加载、示例与测试均正常；若提交 CRAN，
统一改为 `\uXXXX` 转义即可消除。若 `check` 在中文 locale 或非 ASCII 路径下失败，
先清空 `LC_ALL` / `LANG` 并使用纯 ASCII 临时路径。

## 契约版本规则

`0.1.0` 的字段增删或类型变更必须提升主版本号，并同步更新
`inst/contract/schema.json` 与端到端冒烟测试的 golden 值。`pop` 是 `population`
的兼容旧别名，将在 0.2.0 移除，新代码不要用。

## 数据隐私

本包只处理调用方传入的数据，不联网、不回写原始文件。仓库内只包含合成示例数据；
真实监测数据及其聚合产物一律留在本地，不入库、不上传。

---

*EpiStack v0.1.0 · 2026-11-10 · MIT*
