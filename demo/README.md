# 内置模拟数据（公开仓库默认数据源）

> **公开仓库不包含、也不需要任何真实监测数据。**
> 所有示例链路默认使用本目录生成的纯合成数据。

## 为什么

端到端链路需要「地区-时间计数面板 + 邻接权重 + 社会经济指标 + 月度时间轴」四类输入。
为了让任何人 `clone` 后一条命令就能复现，同时不接触任何真实数据，
`make_demo_data.R` 用固定种子生成**结构完全相同、数值完全合成**的替代数据：

| 生成物 | 内容 | 列结构 |
|---|---|---|
| `demo_incidence.csv` | 31 个地区 × 21 年发病计数，含长期下降趋势、SES 梯度与泊松噪声 | `province, year, cases_est, pop, rate_per100k` |
| `demo_adj.graph` | 4×8 规则格网取前 31 格的 rook 邻接（无孤岛、对称、行标准化） | INLA `.graph` 格式 |
| `demo_ses.csv` | 各地区各年 SES，沿格网呈空间梯度以便演示 Moran's I | `prov, year, X1_gdp_pcap` |
| `demo_month.csv` | 地区-月气候协变量，仅用于核验 `epi_period()` 月度轴 | `province, year, month, temp, prec, season` |

地区编码为 `D01`–`D31`，**不对应任何真实行政区**；固定种子 `20261110`，结果可完全复现。

## 用法

```bash
# 默认即模拟数据：生成到 output/demo_data/ 并跑完整六层链路
Rscript case_hfrs_real/run_hfrs.R

# 月度链路（生成器同时产出地区编码一致的模拟月度发病数据）
Rscript case_hfrs_real/run_hfrs.R --monthly case_hfrs_real/output/demo_data/demo_counts_month.csv

# 主仓编排（默认阶段即可，CI 同样只跑合成数据）
Rscript pipeline.R --check
```

生成的文件落在 `case_hfrs_real/output/demo_data/` 或 `pipeline_out/<stage>/demo_data/`，
均在 `.gitignore` 中，不会入库。

## 换成自己的私有数据

1. 复制 [data_paths.example.R](../case_hfrs_real/data_paths.example.R) 为 `case_hfrs_real/data_paths.local.R`（已忽略），填入自己的路径；
2. 或设置 `EPISTACK_HFRS_INCIDENCE` / `_GRAPH` / `_SES` / `_MONTHLY` 四个环境变量；
3. 运行 `Rscript case_hfrs_real/run_hfrs.R --local`。

真实面板只读、产物留在本机、**不入库不上传**；公开仓库与 CI 永远只跑合成数据。
