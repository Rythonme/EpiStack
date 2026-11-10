# Changelog

本项目所有版本遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [v0.1.1] — 2026-11-10（工程化收尾，epiCore 包版本仍为 0.1.0）

W2/W3 提前完成：**编排可一键运行、链路变化可自动拦截、CI 可自动验证与发布**。

### 新增

- **主仓编排 `pipeline.R` + `R/pipeline_plan.R`（targets 雏形）**
  - 声明式 L0–L6 分层计划：每月只需把对应层的 `current_impl` 从 `thin` 改成 `formal`
  - md5 输入指纹缓存实现 skip-if-unchanged（已验证：改脚本只重跑该阶段，未改动阶段 `cached`）
  - `--list` / `--check` / `--all` / `--force` / `--out`；统一 `pipeline_out/pipeline_manifest.json`（层状态、耗时、契约版本、冒烟结果、隐私声明）
  - `pipeline_out/site/` 静态报告站：`index.html` + 合成报告 + 进展看板，供 Pages 发布
  - 真实数据链路 `hfrs_year` 仅在本地只读数据源齐全时运行；CI 上自动 `skipped_missing_data`
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
- `pipeline.R --all --check`：`vertical_slice:cached, hfrs_year:ran`，真实链路 4/4 产物齐全；统一 manifest 已用 JSON 解析器与 node 交叉校验
- 链路指标保持 v0.1 基线逐位一致：4159 行、56 条信号、暴发 6 周全中、Moran's I 0.441 (p=0.031)、CI −0.067

### 踩坑记录

- `sprintf` 参数与占位符数量不符、`smoke_bad` 括号多一个 → 两次语法/运行期错误，均在当天回归中捕获并修复
- 缓存状态文件在「cached」阶段被覆写成空对象会导致下次强制重跑 → 改为以旧 state 为底、只覆盖真正重跑过的阶段
- `epi_json_stringify()` 对空原子向量会触发 `is.na()` 长度为 0 的报错 → 增加 `length(v)==0` 分支
- Windows 中文路径经命令行传给 Rscript 子进程会乱码 → 编排与冒烟一律在同一 R 会话内 `source(..., local=new.env())`，只通过环境变量注入路径

### 已知边界

- 本机**没有真实 HFRS 月度发病序列**（沿用 v0.1 口径说明）。
- GitHub Actions 工作流与 Pages 部署尚未在远端实际触发；文件语法与本地等价命令已验证，push 后需观察首次运行。
- CI 目前只在 Ubuntu 运行；Windows/macOS 未纳入矩阵（本机 Windows 已实测全链路）。

---

## [v0.1] — 2026-11-10（tag `v0.1`，对应 epiCore 包版本 0.1.0）

EpiStack 体系的第一个可发布版本：`epi-core` 正式 R 包 + 端到端切片 + HFRS 真实数据实测。

### 新增

- **`epi-core/` 正式 R 包（v0.1.0，零第三方依赖）**
  - `epi_schema()` / `validate_contract()`：版本化契约 `date, region, count, population, disease`，含主键唯一性、非负计数、正人口分母校验
  - `normalize_region()` / `epi_region_codes()`：地区编码规范化（BOM、空白、行政后缀、别名）
  - `epi_adjacency()` / `epi_read_graph()` / `epi_row_standardize()`：规则格网 rook/queen 权重与真实 INLA .graph 邻接，自动对称化、孤岛报错
  - `epi_qc()`：重复键 / 缺失负计数 / 坏日期 / 未知地区 / 坏人口分母的逐行留痕质控
  - `read_counts()`：L0+L1 主入口，返回 `epi_contract`（data / geo / W / qc / meta）；支持 week / month / quarter / year 四种粒度与自动推断、中英文列名别名、BOM 与 UTF-8
  - `epi_period()` / `epi_wrap_period()`：季节周期映射与跨年回绕
  - `inst/contract/schema.json`：机器可读契约定义；`tests/test_epi_core.R`：40 项 base R 单元测试
  - 可 `R CMD INSTALL` 安装并 `library(epiCore)`；断网时 `bootstrap_core.R` 回退源码加载
- **端到端切片 L0/L1 已替换为正式包函数**：`vertical_slice/run_e2e.R` 的契约、质控、邻接、周期全部走 epiCore；回归结果与原实现逐位一致
- **HFRS 真实数据实测**：`case_hfrs_real/run_hfrs.R`，只读真实省-年面板 + 真实 31 省邻接 + 真实人均 GDP，输出单文件报告与 manifest；`--monthly` 参数支持拿到月度直报数据后一键切换粒度
- 项目进展看板与路线图同步；MIT 许可证

### 实测记录（2026-11-10，R 4.6.0）

- 合成切片：4159 行契约表、56 条异常信号、注入暴发 6 周全中、Moran's I = 0.441 (p = 0.031)、CI = −0.067
- HFRS 真实面板：651 行 / 31 省 / 2004–2024，质控 0 剔除；2024 年合计 5588 例（较历史中位数 −47.5%），单侧升高预警 0 条；单年 Moran's I = −0.071，多年累积 I = 0.189 (p = 0.074)；CI = −0.078，陕西占全国病例 28.4%

### 质量验证

- `R CMD INSTALL` + `library(epiCore)` 通过；`tests/test_epi_core.R` 40 项断言全通过
- `R CMD build` + `R CMD check`（源码 tarball，R 4.6.0 / Windows）：**0 ERROR、0 NOTE、1 WARNING**
  - 唯一 WARNING：R 源码含 UTF-8 中文注释与中文质控表头（可移植性提示，功能不受影响）
  - 复现注意：先清除 `LC_ALL / LANG` 环境变量，并使用纯 ASCII 临时路径，否则 check 子进程会因 locale 与中文路径失败
- 合成切片在替换 L0/L1 前后结果逐位一致；HFRS 年粒度与月度接口两种模式均跑通

### 已知边界

- 本机**没有真实 HFRS 月度发病序列**：年鉴只提供省-年发病率，省-月面板仅有气候协变量。月度链路用合成数据完成接口冒烟验证，待月度直报数据接入后即可完整实测。
- L2–L5 仍为各用例的薄实现，按 12 个月路线图逐月替换为卫星仓。
