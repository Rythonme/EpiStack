# 路线图

EpiStack 按层交付：每个月把一层从薄实现换成独立 R 包，层间的契约不变。已经发布的版本可以单独安装使用，正在开发的层不影响现有链路。

## 当前状态

| 层 | 包 | 状态 | 内容 | 版本 |
|---|---|---|---|---|
| L0 | `epiCore` | 已发布 | 契约 schema、地区编码、邻接权重、`read_counts()`、质控、周期映射 | [v0.1](https://github.com/Rythonme/EpiStack/releases/tag/v0.1) · [v0.1.1](https://github.com/Rythonme/EpiStack/releases/tag/v0.1.1) |
| L1 | `epiIngest` | 已发布 | 多源读取、规则化质控、质控单、血统、脱敏、适配器 | [`v0.2.0`](https://github.com/Rythonme/EpiStack/releases/tag/v0.2.0) |
| L2 | `epiAlert` | 计划 | 季节性基线、异常信号、阈值配置 | — |
| L3 | `epiSpace` | 计划 | Moran / LISA / 热点、BYM2 / INLA | — |
| L4 | `epiIneq` | 计划 | 集中指数 / SII / 分解、可达性 | — |
| L5 | `epiReport` | 计划 | 报告汇编、脱敏开关、交互看板 | — |
| L6 | `epiFlow` | 计划 | 全流水线编排、增量重跑、定时调度 | — |

L2–L6 目前由 `vertical_slice/run_e2e.R` 中的薄实现承担，接口与将来的正式包一致，换实现时下游不用改。

## 版本约定

- 每个包独立版本，遵循[语义化版本](https://semver.org/lang/zh-CN/)；包里不带跨包依赖，只依赖契约字段本身。
- 契约版本独立于包版本：字段增删或类型变更才提升主版本，并同步 `epi-core/inst/contract/schema.json`。
- 发布物包含源码包 tarball，写进脚本时用固定 URL，便于复现。

## 数据与隐私

- 仓库只含合成数据：`demo/make_demo_data.R` 以固定种子生成 31 个虚构地区（`D01`–`D31`）的面板与邻接，不对应任何真实行政区。
- 真实监测数据不随仓库分发：通过不入库的 `case_panel/data_paths.local.R` 或 `EPISTACK_PANEL_*` 环境变量指向本地文件，数据只读、产物留在本地。
- CI 只跑合成数据；发布站点出现 `*.rds` 或本地数据路径即判失败。

## 已知限制

- 时间粒度支持周 / 月 / 季 / 年，但月度示例目前使用合成数据；换成真实月度直报数据只需 `--monthly` 指向对应 CSV。
- CI 只覆盖 Ubuntu + 最新 R；Windows 与 macOS 由维护者在本地验证。
- 质控规则是可配置的默认值，不同病种的报告阈值需要自行校准。
