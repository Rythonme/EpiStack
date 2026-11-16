# epiAlert

EpiStack 体系的 **L2 层**：把「什么算异常」这件事说清楚。
契约表 → 季节性基线 → 单侧上界 → 四级信号，阈值随项目走。

- **零强制依赖**：`Imports` 只有 `stats` / `utils`。不装 forecast / surveillance 也能跑完。
- **不给自己投票**：评估第 t 期时只用 t 之前的历史，回溯评估也不会越评越平。
- **阈值是数据**：`alert_rules()` 存成 JSON 随项目走，换病种改文件、不改包。

## 安装

```r
install.packages(
  "https://github.com/Rythonme/EpiStack/releases/download/v0.3.0/epiAlert_0.1.0.tar.gz",
  repos = NULL, type = "source"
)
library(epiAlert)
```

配合 [epiCore](https://github.com/Rythonme/EpiStack)（契约）与
[epiIngest](https://github.com/Rythonme/EpiStack)（读取与质控）用：

```r
core <- epiCore::read_counts("counts.csv", geo = geo, time_step = "week")
alert_counts(core)
```

## 五分钟上手

```r
library(epiAlert)

d <- alert_example()          # 四个虚构地区、三年周报，末段注入一次暴发
x <- alert_counts(d)          # 逐期回溯评估
x                             # <epi_alert> 关注/预警/告警各多少条
x$alerts                      # 信号清单：日期、地区、计数、上界、连续期数、级别
x$summary                     # 按地区：评估期数、各级条数、最高级别、最后信号
```

当期监测报表只评最新周期：

```r
y <- alert_counts(d, assess = "latest")
alert_report(y, "预警单.html")          # 单文件 HTML，可直接发出
alert_report(y, "信号.csv", format = "csv")
```

## 基线方法

| method | 取哪些历史 | 上界 | 适用 |
|---|---|---|---|
| `seasonal` | 同地区同周期前后各 `window` 期，只取更早年份 | `exp(μ + kσ) − offset` | 周 / 月 / 季，默认 |
| `pooled` | 该地区全部更早年份 | 同上，不分季节 | 年度数据，默认 |
| `moving` | 紧邻评估期之前最近 `window` 期 | `μ + kσ`（算术尺度） | 短序列、无明显季节 |
| `poisson` | 同季节窗口 | `qpois(pnorm(k), λ)` | 小计数 |

`method = "auto"`（默认）按粒度选：周 / 月 / 季走 `seasonal`，年走 `pooled`。
`alert_methods()` 打印这张表的代码版。

参数就三个：`k`（默认 1.645，约 95% 单侧）、`window`（默认 1）、
`min_obs`（默认 3，历史不够就不给基线，也不假装正常）。

## 分级

```r
alert_rules()          # 超限 1 期关注 / 连续 2 期或 1.5 倍预警 / 连续 3 期或 2 倍告警
```

年度数据一期就是一年，不存在「连续期」，只按超出倍数分级。

阈值跟着项目走：

```r
alert_rules_write(alert_rules(warn_ratio = 2, alarm_ratio = 3, name = "流感-2026"),
                  "alert_rules.json")
x <- alert_counts(core, rules = alert_rules_read("alert_rules.json"))
```

## 与上游的衔接

`alert_counts()` 接受任何满足契约的长表（`date` / `region` / `count`），
也可以直接接 `epiCore::read_counts()` 的返回值。本层只读不写：
不改列、不回写数据，换实现时下游一行不用动。

周期编号与 `epiCore::epi_period()` 同口径，同一份数据在两个包里算出同样的期号。

## 已知限制

- 只做单侧升高检测。下降或双向异常不在本层范围。
- 连续超限期数按整段长度记录：回溯看一段暴发时每期都显示该段总长，当期报表（`assess = "latest"`）看到的才是「已连续几期」。
- 分级规则是默认值，不同病种与报告制度需要自行校准，`k` 与阈值都不是通用常数。
- 有效期内的报告延迟、补报会让最近一两期偏低，建议在质控阶段处理，或把最新一期排除在评估外。
