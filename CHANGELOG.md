# 更新日志

遵循[语义化版本](https://semver.org/lang/zh-CN/)。每个包独立版本，发布物同时提供源码 tarball。

## v0.4.1 — 2026-11-22

统一示例数据的病种代码为 `DEMO`，并重新发布受影响的两个包。

- 源码、测试、文档与合成输入中的示例病种代码统一为 `DEMO`；契约字段、校验规则与数值结果不变，golden 37 项全过。
- `epiCore` 升至 0.1.1、`epiIngest` 升至 0.2.1，Release 分别位于 `v0.1.2` 与 `v0.2.1`；旧 tarball 资产已移除，安装链接同步更新。
- 站点隐私扫描改为拦截真实/私有数据文件名，不再按病种名匹配（否则会误伤 `demo-report.html`）。

## v0.4.0 — 2026-11-22

新增 L3 卫星包 `epiSpace` 0.1.0，并接入主仓链路。

**空间统计**

- `space_moran()`：全局 Moran's I 与双侧置换检验，`I = (n/S0)·Σw_ij z_i z_j / Σz_i²`；给定 seed 可逐位复现。
- `space_lisa()` / `space_hotspot()`：逐地区局部 I 与置换 p，按 HH / LL / HL / LH 分象限；只有显著时才标注热点、冷点或空间离群。
- `space_weights()` / `space_neighbors()`：校验权重的结构对称、无自环、无孤立地区，或从格网坐标构造 rook / queen 权重；行标准化后数值不对称属正常。
- `space_counts()` 一站式入口：权重校验 → 全局 → 局部 → 热点 → 摘要；观测值按权重矩阵的地区名对齐。
- `space_bym2_template()`：产出 BYM2 的数据清单、INLA 邻接图代码与模型模板，INLA 列为 Suggests，本包不拟合、不写文件。
- 输出：控制台摘要、CSV（逐地区 + 摘要）、单文件 HTML 分析单。

**主仓**

- L3 从薄实现改为 `epiSpace`；`vertical_slice/run_e2e.R` 用 `space_moran()` 取代手写 Moran，Moran's I 与 p 值与旧实现逐项一致，golden 37 项未改。
- 新增 `space_demo/run_space.R` 与 `space_l3` 编排阶段：4×4 合成格网注入角落聚集，热点识别命中且全部落在注入区域。
- CI 增加 epiSpace 的 build / check / 单测；站点新增空间分析单入口。

## v0.3.0 — 2026-11-16

新增 L2 卫星包 `epiAlert` 0.1.0，并接入主仓链路。

**基线**

- `alert_baseline()` / `alert_counts()`：四种方法——`seasonal`（同季节窗口对数正态上界）、`pooled`（不分季节，年度默认）、`moving`（最近若干期算术均值加 k 倍标准差）、`poisson`（单侧泊松上分位）；默认按时间粒度自动选择。
- 历史只取评估期之前、且只取更早年份的同期观测，回溯评估时本期不进入自己的基线。
- `assess` 决定评估范围：`"all"` 逐期回溯（默认）、`"latest"` 只评最新周期、或年份向量。

**分级与输出**

- `alert_rules()` / `alert_rules_read()` / `alert_rules_write()`：连续期数与超出倍数两条线并看，阈值存 JSON 随项目走，校验不合格直接报错。
- `alert_summary()` 按地区汇总各级条数、最高级别与最大倍数；`alert_report()` 输出控制台、CSV 或单文件 HTML 预警单。
- `alert_methods()` 列出方法与适用粒度，`alert_example()` 提供确定性合成数据供示例与自检。

**主仓**

- L2 从薄实现改为 `epiAlert`；`vertical_slice/run_e2e.R` 改用 `alert_counts()`，基线、上界、连续期数与级别与旧实现逐行一致，golden 基线未改。
- 新增 `alert_demo/run_alert.R` 与 `alert_l2` 编排阶段：注入 3 期暴发，回溯与当期各评估一遍，产物进站点。

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
