# Changelog

本项目所有版本遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

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
