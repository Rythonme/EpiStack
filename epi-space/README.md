# epiSpace

EpiStack 体系的 **L3 层**：把「哪里聚集」这件事说清楚。
契约表 + 邻接权重 → 全局 Moran → 局部 LISA → 热点 / 冷点 / 空间离群。

- **零强制依赖**：`Imports` 只有 `stats` / `utils`。不装 spdep / sf / INLA 也能跑完全部描述性分析。
- **权重先体检**：结构不对称、有孤立地区直接报错，不拿坏权重算出一个好看的数字。
- **不显著不分类**：只有 LISA 置换 p 值达标的地区才叫热点或冷点。

## 安装

```r
install.packages(
  "https://github.com/Rythonme/EpiStack/releases/download/v0.4.0/epiSpace_0.1.0.tar.gz",
  repos = NULL, type = "source"
)
library(epiSpace)
```

配合 [epiCore](https://github.com/Rythonme/EpiStack)（契约与邻接权重）用：

```r
core <- epiCore::read_counts("counts.csv", geo = geo, time_step = "week")
space_counts(core)
```

## 五分钟上手

```r
library(epiSpace)

d <- space_example()                 # 4×4 虚构格网，角落注入一片高值
W <- space_weights(d, "rook")        # 共边邻接、行标准化
x <- space_counts(d, W = W, seed = 20261111L)
x                                    # 全局 Moran's I、p、热点 / 冷点数
x$global                             # I、置换 p、置换零分布
x$hotspots                           # 逐地区：I_i、p_i、象限、类别
x$summary                            # 摘要表，可直接进 manifest
```

固定 `seed` 后置换结果逐位可复现；不传 seed 则每次不同，也不特殊照顾调用方的随机数状态。

```r
space_report(x, "空间分析单.html")    # 单文件，可离线打开
space_report(x, "lisa.csv", format = "csv")
```

## 权重从哪来

三种用法，返回的东西一样：

```r
# 1) 直接用上游契约带来的权重（推荐）
space_counts(core)

# 2) 从格网坐标构造
W <- space_weights(geo_with_row_col, style = "queen")
space_counts(counts, W = W)

# 3) 读真实边界导出的 INLA 邻接表，再交给本层
W <- epiCore::epi_read_graph("graph.txt", regions = region_codes)
space_counts(counts, W = W)
```

权重要求：方阵、带一致地区名、对角线为 0、邻接结构对称、无孤立地区。
行标准化后 `W[i,j]` 与 `W[j,i]` 可以不等（度数不同），这没问题。

## 口径

| 层次 | 统计量 | 回答的问题 |
|---|---|---|
| 全局 | Moran's I + 999 次置换 | 整体有没有空间聚集 |
| 局部 | LISA 四象限 HH / LL / HL / LH | 哪个地区是高-高或低-低聚集 |
| 地点 | 显著 HH 为热点、LL 为冷点、HL/LH 为离群 | 具体在哪里 |

`I = (n / S0) × Σ w_ij z_i z_j / Σ z_i²`，`z = x − mean(x)`；
置换分布由 `replicate(n_perm, I(sample(x)))` 得到，双侧 p 值用
`(1 + #{|I_null| ≥ |I_obs|}) / (n_perm + 1)`。

观测值默认按 `W` 的地区名对齐，所以「哪个地区」与权重矩阵严格对应。
主仓六层切片为保持历史 golden 基线，沿用了旧的地区排序口径（把无名向量直接交给
`space_moran()`）；新代码请用 `space_counts()` 的对齐口径。

## BYM2 模板

```r
tpl <- space_bym2_template(core)
tpl$data          # 模型数据清单，按 W 的地区顺序
tpl$graph_code    # 从 sf / spdep 导出 INLA 邻接图的代码
tpl$code          # inla() 调用与 BYM2 公式
tpl$checklist     # 用前要核对的事项
```

本层**只生成模板，不拟合模型、不写文件、不调用 INLA**。INLA 列为 Suggests，
装不装都不影响上面全部功能。先验参数需要按病种与样本量自行校准。

## 与上游的衔接

`space_counts()` 接受契约长表（`date / region / count / population`），
也可以直接接 `epiCore::read_counts()` 的返回值。本层只读不写：
不改列、不回写数据。没有人口列时用计数本身做自相关，摘要里会标明。

## 已知限制

- 只做单侧高值与双侧聚集的描述，不做时空交互、不做病因推断。
- 地区数少（n < 20）时置换 p 值分辨率有限，999 次置换最小只能到 0.001。
- 权重定义直接决定结论：换 rook / queen、换邻接图，结果都可能变，报告里请写明用的哪一种。
- LISA 的显著性没有做多重比较校正；地区多时应自行控制假阳性。
- BYM2 模板不是可直接引用的模型设定，先验、offset 与收敛诊断都要按项目核对。
