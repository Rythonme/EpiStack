# epiRobust

EpiStack 体系的 **L3.5 层**：空间流行病学结论的稳健性体检。

前几层回答"哪里聚集、聚集有多强"，本层回答一个更难回避的问题：**这个结论有多少是分析选择决定的？**

## 四项检查

| 检查 | 威胁 | 输出 |
|---|---|---|
| `robust_maup()` | 可修改面元单元问题（尺度效应） | 多聚合尺度下的 Moran's I、热点数与结论区间 |
| `robust_weights()` | 邻接定义任意性 | rook / queen / kNN 下的方向与显著性对比 |
| `robust_conley()` | 空间依赖让 SE 偏小 | 多个距离截断的 Conley HAC 标准误 vs 朴素 SE |
| `robust_multiplicity()` | LISA 逐地区检验的假阳性 | Bonferroni 与 BH-FDR 校正后的显著地区 |

`robust_check()` 一次跑完四项，`robust_report()` 汇编成单文件离线 HTML 报告。

Moran 与 LISA 的公式和置换口径与 `epiSpace` 逐字一致，结果可直接对照。核心统计只用 base R + stats，不依赖 spdep / sf / INLA。

## 安装

```r
install.packages(
  "https://github.com/Rythonme/EpiStack/releases/download/v0.6.0/epiRobust_0.1.0.tar.gz",
  repos = NULL, type = "source"
)
# 开发版：remotes::install_github("Rythonme/EpiStack", subdir = "epi-robust", ref = "v0.6.0")
```

## 五分钟上手

```r
library(epiRobust)

d <- robust_example(n_side = 6L)   # 36 个虚构地区，合成数据
res <- robust_check(d, n_perm = 199L, seed = 20261124L)
print(res)

robust_report(res, "体检报告.html")  # 浏览器直接打开
```

接你自己的数据：

```r
core <- epiCore::read_counts("counts.csv", geo = geo, time_step = "month")
res  <- robust_check(core, scales = c(1L, 2L, 3L), seed = 20261124L)
```

契约表至少需要 `region / count`，MAUP 与权重检查还需要 `row / col`（或上游 `geo` 表）。真实监测数据不入库，本包只读不回写。

## 演示结果（36 个虚构地区，199 次置换）

| 检查 | 发现 |
|---|---|
| MAUP | 原始格网 I = +0.9055（p = 0.005），聚合到 3× 后 I = -0.0009（p = 1.000）——**符号翻转** |
| 权重 | rook / queen / kNN 的 I 分别为 +0.9055 / +0.8471 / +0.8741，方向一致 |
| Conley | 空间稳健 SE 最大放大到朴素 SE 的 **2.04 倍** |
| 多重比较 | 原始 12 个显著地区，校正后只剩 1 个 |

这正是一个"看起来很强的聚集结论"在体检中暴露的脆弱性：权重定义无关紧要，但空间尺度和多重比较足以改变结论。

## 方法口径

- Moran's I：`(n / S0) × Σ w_ij z_i z_j / Σ z_i²`，置换 p 为 `(1 + #{|I_null| ≥ |I_obs|}) / (n_perm + 1)`
- kNN 权重：欧氏距离取 k 近邻后对称化、行标准化
- Conley HAC：Bartlett 核 `w = 1 − d/c`，`(X'X)⁻¹ [ΣᵢΣⱼ wᵢⱼ eᵢ eⱼ xᵢ xⱼ'] (X'X)⁻¹`；截断须大于最小格距，否则权重全为 0，函数返回 NA 并跳过
- BH-FDR：标准 Benjamini–Hochberg 逐步向上法

## 已知限制

- MAUP 聚合目前只支持规则格网的整数倍合并；不规则行政区需要先用上游把区面转成格网或邻接图
- 只覆盖尺度与分区敏感性的一部分，完整的 zoning effect（同尺度换边界）需另配边界变体
- Conley 默认对率做截距回归；要控制协变量请传 `design` 矩阵
- 置换 p 值在地区数少时分辨率有限；地区数 < 20 时谨慎解释
- 本层只诊断，不做病因推断，也不替代预注册的分析方案

## 验证

- 23 项单元测试全过
- `R CMD check`：0 ERROR / 1 WARNING（与前几层一致的中文文案可移植性提示）/ 0 NOTE
