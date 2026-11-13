# 更新日志

遵循[语义化版本](https://semver.org/lang/zh-CN/)。每个包独立版本，发布物同时提供源码 tarball。

## v0.2.0 — 2026-11-13

新增 L1 卫星包 `epiIngest` 0.2.0，并接入主仓链路。

**读取**

- `ingest_source()` / `ingest_read()` / `ingest_profile()`：CSV、TSV 与任意分隔符文本，自动识别 UTF-8 / GBK / BOM，支持目录或路径向量的多文件合并。
- `$data` 只保留契约列，`$raw` 保留原始列，`$meta` 记录编码、分隔符、md5 与强制转换失败数。
- `ingest_profile()` 输出列类型、缺失率、日期范围与重复键，用于读之前先看一眼。

**质控**

- `qc_rules()` / `qc_apply()` / `qc_report()`：必填、唯一键、数值范围、未来日期、日期断档、地区白名单、MAD/IQR 异常值、跨字段一致性八类规则。
- `error` 级剔除该行，`warn` 级保留并标记，逐行记录到行号；`ingest_on_warn()` 可全局把 warn 也当作剔除或报错。
- 规则可 `qc_rules_write()` 存成 JSON 随项目走；报告输出到控制台、CSV（含逐行明细）或单文件 HTML。

**其他能力**

- `ingest_lineage()` 记录文件 md5、规则哈希与行数变化，可写 JSON 归档。
- `ingest_desensitize()` 提供加盐 SHA-256 假名与可选日期平移；盐值不写入元数据。
- 适配器：Excel（`readxl`）、数据库（`DBI`）、HTTP 接口（base R，自带 JSON 解析）、栅格 zonal 统计（`terra`）。全部在 `Suggests`，缺包时 `epi_ingest_capabilities()` 明确报出缺哪个，不静默降级。
- `ingest_counts()` 直接输出 `epi_contract`，内部只调用一次 `epiCore::read_counts()`，与直接调用的结果一致。

**主仓**

- L1 从薄实现改为 `epiIngest`；`vertical_slice/run_e2e.R` 改用 `ingest_counts()`，契约与邻接结果不变。
- 新增演示阶段 `ingest_demo/`：合成数据 → 读取画像 → 质控单 → 契约比对 → 血缘。
- `bootstrap_ingest.R` 优先使用已安装的包，装不上回退源码加载。

## v0.1.1 — 2026-11-11

- `epiCore` 提供源码 tarball 资产，可用一行 `install.packages("<Release URL>", repos = NULL, type = "source")` 安装，无需 clone 仓库、无需 Rtools。
- 补齐中英文 README 的安装与快速开始章节。
- Windows 上用 `remotes::install_github()` 安装子目录包时，外部 `tar` 无法处理中文文件名；先 `Sys.setenv(TAR = "internal")` 再装，或改用 Release tarball。

## v0.1 — 2026-11-10

首个版本，`epiCore` 0.1.0。

- 契约：`date, region, count, population, disease`，附 `geo` 编码表与 `W` 邻接权重；`epi_schema()` / `validate_contract()` 校验主键唯一、计数非负、人口为正。
- 读取：`read_counts()` 完成列名别名匹配、BOM 与行政后缀清理、日期解析（`YYYY` / `YYYY-MM` / `YYYY-MM-DD`）、去重与脏行剔除、人口分母回填、周期映射、邻接构建。
- 地区与空间：`normalize_region()`、`epi_region_codes()`、`epi_adjacency()`（格网 rook/queen）、`epi_read_graph()`（INLA `.graph`），自动对称化并对孤岛报错。
- 周期：`epi_period()` 支持 week / month / quarter / year 与自动推断。
- 交付：40 项单测、可 `R CMD INSTALL` 安装、`bootstrap_core.R` 断网源码回退；六层端到端示例与编排入口 `pipeline.R`。
