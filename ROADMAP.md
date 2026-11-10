# EpiStack 路线图与逐月更新

> 本文件是 **「总体 + 每月进度」的单一事实源**。
> [README.md](README.md) 回答「体系是什么」，本文件回答「什么时候做到哪一步、每月怎么更新」。
>
> - 主仓：[github.com/Rythonme/EpiStack](https://github.com/Rythonme/EpiStack)（公开，MIT）
> - 当前月度版本：**v0.1**（月内修订 **v0.1.1**）· 2026-11
> - 下一月度版本：**v0.2** · 2026-12 · 卫星仓 `epi-ingest`
> - 本月任务归档：[docs/monthly/2026-11.md](docs/monthly/2026-11.md)
> - 最近更新：2026-11-11

---

## 1. 发布节奏

**每月一个可独立发布的卫星仓，主仓只加厚一层，链路始终从头跑得通。**

| 时间 | 动作 | 产出 |
|---|---|---|
| 每月第 1 周 | 复制月度模板，写当月任务与验收标准 | `docs/monthly/YYYY-MM.md` |
| 每月第 2–3 周 | 卫星仓开发：可独立安装、可 `R CMD check`、独立 README | 独立仓库 / 本仓内包目录 |
| 每月第 4 周 | 主仓接入（改一行 `current_impl`）、全链路回归、更新文档与看板 | 新 commit |
| 月末 | 打 `vX.Y` tag + 创建 GitHub Release | **当月 Release** |
| 每晚 | CI 自动重跑合成数据链路 + golden 冒烟 + Pages | 自动校验，断了当天发现 |

月内如需修订，用 patch 版本（`v0.1.1`）；**月度 Release 用 minor 版本**（`v0.1` → `v0.2` → …）。
2027-10 的集成发布直接使用 `v1.0`，不再占用 `v0.12`。

---

## 2. 十二个月路线图

| 月份 | 版本 | 卫星仓 | 加厚层 | 状态 | 当月可独立交付的东西 | Release |
|---|---|---|---|---|---|---|
| **2026-11** | v0.1 | `epi-core` + 薄切片 | L0 / L6 | ✅ **已完成** | 正式 R 包（契约 / 编码 / 邻接 / `read_counts()`）、六层全通、模拟数据演示、主仓编排与 CI | [v0.1](https://github.com/Rythonme/EpiStack/releases/tag/v0.1) · [v0.1.1](https://github.com/Rythonme/EpiStack/releases/tag/v0.1.1) |
| 2026-12 | v0.2 | `epi-ingest` | L1 | 🔜 **下月** | 多源读取器（CSV / Excel / 数据库 / API）+ 质控报告 + 栅格协变量 zonal stats | — |
| 2027-01 | v0.3 | `epi-alert` | L2 | ⬜ 计划 | 4 种预警算法统一接口 + 阈值配置；`WarnEpi` / `surveillance` 适配器 | — |
| 2027-02 | v0.4 | `epi-space-basic` | L3 | ⬜ 计划 | Moran / LISA / 热点图、GWR / MGWR | — |
| 2027-03 | v0.5 | `epi-space-bayes` | L3 | ⬜ 计划 | BYM2 / INLA 模板、景观格局指数（抽自 HFRS 990m 网格流水线） | — |
| 2027-04 | v0.6 | `epi-ineq` | L4 | ⬜ 计划 | CI / SII / 分解 + 中文报告（呼应「医疗卫生的不平等性」课题） | — |
| 2027-05 | v0.7 | `epi-access` | L4 | ⬜ 计划 | OSM 路网出行时间、基层医疗服务区 delineation | — |
| 2027-06 | v0.8 | `epi-report` | L5 | ⬜ 计划 | 多层结果自动汇编、报告脱敏开关 | — |
| 2027-07 | v0.9 | `epi-dashboard` | L5 | ⬜ 计划 | 交互式看板 + GitHub Pages 发布 | — |
| 2027-08 | v0.10 | `epi-flow` | L6 | ⬜ 计划 | `targets` 全流水线、`renv`、CI、定时重跑 | — |
| 2027-09 | v0.11 | `epi-geoai` | L3 / D | ⬜ 计划 | 遥感协变量批处理、GeoFM 评测审计 | — |
| 2027-10 | **v1.0** | `EpiStack 1.0` | 全层 | ⬜ 计划 | 集成发布 + HFRS 完整案例复现 + 文档站 | — |

> 状态图例：✅ 完成 · 🔜 进行中 / 下月 · ⬜ 计划 · ⏸ 暂停。
> 每个月都有**能单独发出去的成果**，同时把体系里对应那一层从「薄实现」换成「正式实现」。

---

## 3. 本月任务归档

- **[2026-11 · 立项月](docs/monthly/2026-11.md)** — `epi-core` 正式 R 包、W1–W4 四周任务、实测结果、踩坑记录、下月交接

后续每月归档放在 `docs/monthly/YYYY-MM.md`，模板见 [TEMPLATE.md](docs/monthly/TEMPLATE.md)。
归档文件**只追加不回溯修改**：已结束月份的文件保持不变，纠错写进当月新归档或 CHANGELOG。

---

## 4. 逐月更新 SOP（每月固定五步）

1. **建归档**：复制 `docs/monthly/TEMPLATE.md` → `docs/monthly/YYYY-MM.md`，填目标、W1–W4 任务、验收标准、下月交接。
2. **发卫星仓**：按「可独立安装 + `R CMD check` 0 ERROR + 自带 README 示例」标准交付；主仓 `R/pipeline_plan.R` 里把对应层的 `current_impl` 从 `thin` 改成 `formal`（**只改这一行**）。
3. **回归**：`Rscript pipeline.R --all --check`。若口径确实变更，用 `Rscript tests/smoke_e2e.R --update` 重生成 golden 基线，并**人工审阅 diff 后**才提交；绝不无条件覆盖基线。
4. **同步文档**：更新本文件状态表与 Release 列、[README.md](README.md) 第 6 节摘要、[CHANGELOG.md](CHANGELOG.md)、`kanban_data.js`（[项目进展看板](项目进展看板.html)）。
5. **发版**：`git tag -a vX.Y` → push tag → 创建 GitHub Release，Release notes 指向当月归档文档；确认 `R-CMD-check` 工作流全绿。

### 完成定义（DoD，每月都要满足）

- [ ] 卫星仓可 `R CMD INSTALL` + `library()`，且 `R CMD check` **0 ERROR**
- [ ] `Rscript pipeline.R --all --check` 退出码 0，golden 冒烟 37 PASS / 0 FAIL
- [ ] 六层链路仍能从头跑到尾（换层不炸链路）
- [ ] 仓库不含任何真实监测数据 / 本地报告 / `.rds` 缓存
- [ ] 路线图、月度归档、CHANGELOG、看板四处状态一致
- [ ] 当月 tag 与 GitHub Release 存在且 notes 可追溯到归档文档

---

## 5. 版本与隐私约定

| 项 | 约定 |
|---|---|
| 版本 | 月度 minor（`v0.1`、`v0.2`…）、月内 patch（`v0.1.1`）、集成 `v1.0`；遵循语义化版本 |
| 发布物 | 代码 + 合成数据 + 单文件 HTML 示例报告 + 契约 schema + 进展看板 |
| 公开数据源 | `demo/make_demo_data.R` 内置模拟数据（固定种子、`D01`–`D31`，不对应任何真实行政区）；所有示例与 CI 默认只用模拟数据 |
| 不发布物 | 本机私有面板及其结果、本地报告、`data_paths.local.R`、阶段缓存 `*.rds`、`.rlib/`、`pipeline_out/`、`tests/_smoke_out/` |
| CI | 只跑合成数据；`nightly-e2e.yml` 带隐私守卫，站点出现 `*HFRS*` / `*真实*` / `*.rds` 即失败 |
| 原始数据 | 只读、不修改、不入库；真实数据仅在本机用于验收，产出留在本地 |

---

## 6. 已知边界（当前）

- 本机私有面板只有地区-年粒度、月度面板仅气候协变量；公开版本已用内置模拟数据完整演示 `--monthly` 月度链路，待月度直报 CSV 接入后可补实测。
- GitHub Actions 与 Pages 在 push 后需观察首次运行结果；本地等价命令与 YAML 语法已验证。
- CI 目前只在 Ubuntu；本机 Windows + R 4.6.0 已实测全链路。

---

*路线图建立：2026-11-11 ｜ 依据 `README.md` v2 体系设计与本机实测*
