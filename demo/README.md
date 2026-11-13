# 内置模拟数据

仓库里所有的示例与测试都跑这份数据，不依赖任何真实监测数据。

`make_demo_data.R` 用固定种子生成结构一致、数值完全合成的替代数据：

| 生成物 | 内容 | 列结构 |
|---|---|---|
| `demo_incidence.csv` | 31 个地区 × 21 年发病计数，含长期下降趋势、SES 梯度与泊松噪声 | `province, year, cases_est, pop, rate_per100k` |
| `demo_adj.graph` | 4×8 规则格网取前 31 格的 rook 邻接（无孤岛、对称、行标准化） | INLA `.graph` |
| `demo_ses.csv` | 各地区各年 SES，沿格网呈空间梯度，便于演示 Moran's I | `prov, year, X1_gdp_pcap` |
| `demo_month.csv` | 地区-月气候协变量，用于核验 `epi_period()` 的月度轴 | `province, year, month, temp, prec, season` |

地区编码为 `D01`–`D31`，不对应任何真实行政区；固定种子 `20261110`，结果可复现。

## 用法

```bash
# 默认即模拟数据：生成到 output/demo_data/ 并跑完整六层链路
Rscript case_panel/run_panel.R

# 月度链路（生成器同时产出地区编码一致的模拟月度发病数据）
Rscript case_panel/run_panel.R --monthly case_panel/output/demo_data/demo_counts_month.csv

# 主仓编排
Rscript pipeline.R --check
```

生成的文件落在 `case_panel/output/demo_data/` 或 `pipeline_out/<stage>/demo_data/`，均在 `.gitignore` 中，不会入库。

## 换成自己的数据

1. 复制 [data_paths.example.R](../case_panel/data_paths.example.R) 为 `case_panel/data_paths.local.R`（已忽略），填入自己的路径；
2. 或设置 `EPISTACK_PANEL_INCIDENCE` / `_GRAPH` / `_SES` / `_MONTHLY` 四个环境变量；
3. 运行 `Rscript case_panel/run_panel.R --local`。

输入数据只读，产物留在本地，不入库也不上传。
