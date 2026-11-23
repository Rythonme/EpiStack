# epiIneq

EpiStack 体系的 **L4 层**：把「负担是否偏向弱势地区」说清楚。
契约表 + SES → 集中曲线 / CI → SII → 分组分解 → 可达性。

- **零强制依赖**：`Imports` 只有 `stats` / `utils`。不装 ineq / spdep / sf 也能跑完。
- **不替你下结论**：CI、SII、率比、PAF 同时给出，方向一致才叫证据；分解的余量单列，不硬塞进某一块。
- **可单独替换**：只读契约表，不改列、不回写；换上游不影响本层输出口径。

## 安装

```r
install.packages(
  "https://github.com/Rythonme/EpiStack/releases/download/v0.5.0/epiIneq_0.1.0.tar.gz",
  repos = NULL, type = "source"
)
library(epiIneq)
```

纯 base R，无编译代码，Windows 不需要 Rtools。

## 五分钟上手

```r
library(epiIneq)

d <- ineq_example()                  # 4×4 虚构格网，SES 左低右高
x <- ineq_counts(d)                  # 一站式：曲线 → CI → SII → 分解 → 可达性
x                                    # CI、SII、低/高 SES 率比
x$summary                            # 七项指标与解释
x$groups                             # 低/高 SES 两组的率、人口与病例份额
x$decompose                          # 组间 / 组内 / 余量
x$access                             # 设施点、逐地区可达性、低/高比

ineq_report(x, "不平等分析单.html")   # 单文件 HTML，可离线打开
```

`ineq_counts()` 是推荐入口；每个指标也能单独调用：`ineq_curve()`、
`ineq_ci()`、`ineq_sii()`、`ineq_groups()`、`ineq_decompose()`、
`ineq_access()`、`ineq_gini()`。

## 指标口径

| 指标 | 回答什么 | 方向 |
|---|---|---|
| 集中指数 CI | 病例是否沿 SES 梯度集中 | 负值 = 偏向低 SES |
| 斜率不平等指数 SII | 最弱端到最优势端的预测率差（每十万人） | 负值 = 偏向低 SES |
| 低/高 SES 率比 | 两组率的倍数差 | > 1 = 偏向低 SES |
| Gini | 病例在地区间有多不均 | 不区分 SES 梯度 |
| PAF | 全部降到最低负担组率可避免的比例 | 0–1 |
| 可达性低/高比 | 低 SES 组可达性相对高 SES 组 | < 1 = 弱势可及性更差 |

CI = 1 − 2×人口加权集中曲线下面积（梯形法）。SII 用 SES 人口累积中点位置
对率做人口加权线性回归，斜率即为两端的预测率差。分解把组内率拉平后重算
整体 CI 作为组间部分，组内曲线按「人口份额 × 病例份额」加权求和作为组内部分。

## 输入

一个地区一行的 data.frame，或 `epiCore::read_counts()` 的返回值：

```r
core <- epiCore::read_counts("counts.csv", geo = geo, time_step = "week")
x <- ineq_counts(core)               # SES 与坐标从 core$geo 自动匹配
```

必需列：`region`、`count`、`population`、`ses`（或放在 `geo` 里）。
可达性另需坐标列 `x`/`y`、`row`/`col` 或 `lon`/`lat`；没有坐标时跳过可达性，
其余指标照常给出。设施点可用 `facilities =` 显式传入，否则按人口自动选前三个地区。

## 已知限制

- 只做单时点比较：多年数据默认取最新一年，可用 `year_value` 指定，不做跨年趋势分解。
- 分解是两块近似，离散分组会有余量；余量单列，不强行归入组间或组内。
- 可达性用欧氏距离与距离衰减，不等于真实就医时间；坐标单位由调用方决定。
- SES 取值范围与含义由上游定义，本层只按数值排序分组；`cut` 的默认值 0.5 需要按实际尺度校准。

*EpiStack v0.5.0 · 2026-11-23 · MIT*
