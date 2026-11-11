# Changelog

本项目所有版本遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [安装分发] — 2026-11-11（补充分发通道，不另发 tag、不改算法）

### 新增

- `v0.1.1` Release 追加资产 **`epiCore_0.1.0.tar.gz`**（`R CMD build` 产出，20 KB，仅含代码与合成示例数据）：其他人可用一行 `install.packages("<Release URL>", repos = NULL, type = "source")` 联网安装，无需 clone 仓库、无需第三方包、无需 Rtools，版本固定可复现
- 中英文 README 与 `epi-core/README.md` 补全「联网安装 / 本地安装 / 离线回退」三种方式，去掉文档里的本机 R 绝对路径；`ROADMAP.md` 中「卫星仓可 `install_github()`」的目标提前具备可复制的安装命令

### 实测（R 4.6.0 / Windows）

| 方式 | 结果 |
|---|---|
| Release URL 一行 `install.packages()` | ✅ 0.1.0 / 16 导出函数 / 契约 0.1.0 |
| `pak::pkg_install("github::Rythonme/EpiStack/epi-core@v0.1.1")` | ✅ 同上 |
| `remotes::install_github(..., subdir = "epi-core")` | ⚠️ 默认报 `input string ... is invalid`；先 `Sys.setenv(TAR = "internal")` 后 ✅ |

失败原因：仓库内存在中文命名的示例文件，Windows 中文 locale 下 `remotes` 调用的外部 `tar.exe` 无法转码 UTF-8 文件名；`pak` 自解压与 Release tarball（内部文件名全 ASCII）不受影响。后续版本将考虑把入库文件名统一为 ASCII。

---

## [文档与发布增量] — 2026-11-11（随 `v0.1.1` 一并发布，不另发 tag）

首次发布到 GitHub 主仓 [Rythonme/EpiStack](https://github.com/Rythonme/EpiStack)（公开 · MIT）。
本次补文档、发布元数据与**隐私加固**（内置模拟数据替代全部真实数据示例），不改动核心算法与 golden 口径、不新增 tag；这些改动一并纳入 `v0.1.1` 的 Release notes。

### 新增

- **`ROADMAP.md`**：12 个月状态表（含版本与 Release 列）、发布节奏、**逐月更新 SOP（五步 + DoD 检查表）**、版本与隐私约定；作为「总体 + 每月进度」的单一事实源
- **`docs/monthly/2026-11.md`**：本月任务归档（W1–W4 任务与验收、模拟数据演示、交付清单、踩坑与决策、已知边界、下月交接）
- **`docs/monthly/TEMPLATE.md`**：月度归档模板，含月末 DoD 检查表；已结束月份归档只追加不回溯修改
- 中英文 README 补仓库地址、CI 徽章、`git clone` 快速开始与「发布与逐月更新」章节；路线图速览指向 ROADMAP.md
- **远端发布完成**：公开仓库 `Rythonme/EpiStack` 已建立并推送 51 个文件与 `v0.1` / `v0.1.1` 两个 tag；两个 GitHub Release 已创建；`R-CMD-check` 首次远端运行通过；Pages 启用 `build_type=workflow`（仅合成数据站点）
- **内置模拟数据**：`demo/make_demo_data.R` 生成 31 地区面板、邻接、SES 与月度轴（含月度发病结局），固定种子、地区编码 `D01`–`D31`，不对应任何真实行政区；`case_hfrs_real/run_hfrs.R` 默认走模拟数据，`--local` 才读本机私有面板。公开仓库不含任何本机路径、真实数据文件名或真实观测值

### 约定

- **月度 Release 用 minor**（`v0.1` → `v0.2` → …），月内修订用 patch（`v0.1.1`），2027-10 集成直接发 `v1.0`
- 每月一个 `docs/monthly/YYYY-MM.md` 归档 + 一个 GitHub Release，Release notes 指向当月归档
- **公开仓库不含任何真实数据**：所有示例默认使用 `demo/make_demo_data.R` 的模拟面板；真实监测数据、本地报告、私有配置与阶段缓存一律不入库，CI 只跑合成数据并带隐私守卫

---

## [v0.1.1] — 2026-11-10（工程化收尾，epiCore 包版本仍为 0.1.0）

W2/W3 提前完成：**编排可一键运行、链路变化可自动拦截、CI 可自动验证与发布**。

### 新增

- **主仓编排 `pipeline.R` + `R/pipeline_plan.R`（targets 雏形）**
  - 声明式 L0–L6 分层计划：每月只需把对应层的 `current_impl` 从 `thin` 改成 `formal`
  - md5 输入指纹缓存实现 skip-if-unchanged（已验证：改脚本只重跑该阶段，未改动阶段 `cached`）
  - `--list` / `--check` / `--all` / `--force` / `--out`；统一 `pipeline_out/pipeline_manifest.json`（层状态、耗时、契约版本、冒烟结果、隐私声明）
  - `pipeline_out/site/` 静态报告站：`index.html` + 合成报告 + 进展看板，供 Pages 发布
  - 流水线改为 `panel_demo`（模拟面板，CI 安全、公开默认）与 `panel_local`（本机私有面板，配置缺失时自动 `skipped_missing_data`）两条
- **契约 golden-file 与端到端冒烟**：`tests/golden/vertical_slice_v0.1.0.json`（27 项指标）+ `tests/smoke_e2e.R`（10 项结构断言），合计 **37 PASS / 0 FAIL**；`--update` 重生成基线需人工审阅
- **`R/epi_json.R`**：base R 极简 JSON 解析/序列化，L6 manifest、golden、pipeline 状态全部零依赖可读写
- **`.github/workflows/R-CMD-check.yaml`**：`R CMD build` + `check`（0 ERROR 门禁）+ `pipeline.R --check`，上传日志与合成站点
- **`.github/workflows/nightly-e2e.yml`**：每晚重跑链路 → 隐私守卫（站点出现 `*HFRS*` / `*真实*` / `*.rds` 即失败）→ GitHub Pages 部署
- **`renv.lock`**：零第三方依赖基线快照（R 4.6.0 + CRAN）；未来引入依赖时用 `renv::snapshot()` 覆盖
- **`README.en.md`** 英文说明；中文 README 补 5.2 节、W2/W3 排期与验收标准

### 变更

- `vertical_slice/run_e2e.R`、`case_hfrs_real/run_hfrs.R` 支持 `EPISTACK_PROJECT_ROOT` / `EPISTACK_OUT_DIR` 注入，使主仓可在同一 R 会话内按层调用；**原命令行用法完全不变**
- `case_hfrs_real/run_hfrs.R` 的 L6 提示改为输出实际目录名（原先写死 `output/cache/`）
- `.gitignore` 新增 `pipeline_out/`、`tests/_smoke_out/`

### 实测记录（2026-11-10，R 4.6.0）

- `pipeline.R --check`：1 阶段 `cached` + 冒烟 37 PASS / 0 FAIL，退出码 0
- `pipeline.R --all --check`：3 个阶段全绿，本机私有链路 4/4 产物齐全；统一 manifest 已用 JSON 解析器与 node 交叉校验
- 链路指标保持 v0.1 基线逐位一致：4159 行、56 条信号、暴发 6 周全中、Moran's I 0.441 (p=0.031)、CI −0.067

### 踩坑记录

- `sprintf` 参数与占位符数量不符、`smoke_bad` 括号多一个 → 两次语法/运行期错误，均在当天回归中捕获并修复
- 缓存状态文件在「cached」阶段被覆写成空对象会导致下次强制重跑 → 改为以旧 state 为底、只覆盖真正重跑过的阶段
- `epi_json_stringify()` 对空原子向量会触发 `is.na()` 长度为 0 的报错 → 增加 `length(v)==0` 分支
- Windows 中文路径经命令行传给 Rscript 子进程会乱码 → 编排与冒烟一律在同一 R 会话内 `source(..., local=new.env())`，只通过环境变量注入路径

### 已知边界

- 本机私有面板只有地区-年粒度、月度面板仅气候协变量；公开版本已用内置模拟数据完整演示月度链路，待真实月度直报数据接入后可补实测。
- GitHub Actions 工作流与 Pages 部署尚未在远端实际触发；文件语法与本地等价命令已验证，push 后需观察首次运行。
- CI 目前只在 Ubuntu 运行；Windows/macOS 未纳入矩阵（本机 Windows 已实测全链路）。

---

## [v0.1] — 2026-11-10（tag `v0.1`，对应 epiCore 包版本 0.1.0）

EpiStack 体系的第一个可发布版本：`epi-core` 正式 R 包 + 端到端切片 + 本机私有面板验收（数据与结果不公开）。

### 新增

- **`epi-core/` 正式 R 包（v0.1.0，零第三方依赖）**
  - `epi_schema()` / `validate_contract()`：版本化契约 `date, region, count, population, disease`，含主键唯一性、非负计数、正人口分母校验
  - `normalize_region()` / `epi_region_codes()`：地区编码规范化（BOM、空白、行政后缀、别名）
  - `epi_adjacency()` / `epi_read_graph()` / `epi_row_standardize()`：规则格网 rook/queen 权重与 INLA .graph 邻接，自动对称化、孤岛报错
  - `epi_qc()`：重复键 / 缺失负计数 / 坏日期 / 未知地区 / 坏人口分母的逐行留痕质控
  - `read_counts()`：L0+L1 主入口，返回 `epi_contract`（data / geo / W / qc / meta）；支持 week / month / quarter / year 四种粒度与自动推断、中英文列名别名、BOM 与 UTF-8
  - `epi_period()` / `epi_wrap_period()`：季节周期映射与跨年回绕
  - `inst/contract/schema.json`：机器可读契约定义；`tests/test_epi_core.R`：40 项 base R 单元测试
  - 可 `R CMD INSTALL` 安装并 `library(epiCore)`；断网时 `bootstrap_core.R` 回退源码加载
- **端到端切片 L0/L1 已替换为正式包函数**：`vertical_slice/run_e2e.R` 的契约、质控、邻接、周期全部走 epiCore；回归结果与原实现逐位一致
- **面板适配器与模拟数据演示**：`case_hfrs_real/run_hfrs.R` 默认使用 `demo/make_demo_data.R` 生成的纯合成面板；本机私有面板通过不入库的 `data_paths.local.R` 接入、结果不公开；`--monthly` 支持月度链路一键切换
- 项目进展看板与路线图同步；MIT 许可证

### 实测记录（2026-11-10，R 4.6.0）

- 合成切片：4159 行契约表、56 条异常信号、注入暴发 6 周全中、Moran's I = 0.441 (p = 0.031)、CI = −0.067
- 本机私有面板：已完成端到端验收，**数据与结果不公开**；公开版本模拟面板演示：651 行 / 31 地区、质控 0 剔除、Moran's I = 0.406 (p = 0.003)、多年累积 I = 0.858 (p = 0.001)、CI = −0.113

### 质量验证

- `R CMD INSTALL` + `library(epiCore)` 通过；`tests/test_epi_core.R` 40 项断言全通过
- `R CMD build` + `R CMD check`（源码 tarball，R 4.6.0 / Windows）：**0 ERROR、0 NOTE、1 WARNING**
  - 唯一 WARNING：R 源码含 UTF-8 中文注释与中文质控表头（可移植性提示，功能不受影响）
  - 复现注意：先清除 `LC_ALL / LANG` 环境变量，并使用纯 ASCII 临时路径，否则 check 子进程会因 locale 与中文路径失败
- 合成切片在替换 L0/L1 前后结果逐位一致；HFRS 年粒度与月度接口两种模式均跑通

### 已知边界

- 本机私有面板只有地区-年粒度，月度面板仅气候协变量；月度链路已用内置模拟数据完整演示，待月度直报数据接入后即可实测。
- L2–L5 仍为各用例的薄实现，按 12 个月路线图逐月替换为卫星仓。
