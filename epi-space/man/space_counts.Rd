\name{space_counts}
\alias{space_counts}
\title{从契约表产出空间自相关结果（推荐入口）}
\usage{
space_counts(x, W = NULL, value = NULL, year_value = NULL,
             n_perm = 999L, seed = NULL, alpha = 0.05,
             alternative = c("two.sided", "greater", "less"),
             region = "region", count = "count",
             population = "population", year = "year")
}
\arguments{
\item{x}{契约长表 data.frame，或 \code{epiCore::read_counts()} 的返回值。}

\item{W}{权重矩阵；x 是契约时可省略（自动取 \code{x$W}）。}

\item{value}{指定用于自相关的列；默认按 count / population 求率。}

\item{year_value}{取哪一年；默认取数据中最新年份。}

\item{n_perm}{置换次数，默认 999；0 表示只算点估计。}

\item{seed}{随机种子；非 NULL 时置换可复现。}

\item{alpha}{显著性水平，默认 0.05。}

\item{alternative}{全局检验方向：two.sided / greater / less。}

\item{region, count, population, year}{输入表中对应列的名字。}
}
\value{
类 \code{epi_space} 的列表：\code{global}（全局 Moran）、\code{local}（逐地区 LISA）、
\code{hotspots}（含类别的逐地区表）、\code{summary}、\code{values}、\code{W}、
\code{settings} 与 \code{meta}。
}
\description{
一键完成权重校验、全局 Moran、局部 LISA、热点分类与摘要。
}
\details{
本层只读契约，不改列、不回写。观测值按 \code{W} 的地区名对齐，
因此 LISA 的「哪个地区」与权重矩阵严格对应。

若传入无名数值向量给 \code{\link{space_moran}()}，则按传入顺序计算；
主仓切片为保持历史 golden 基线，用的就是这种口径。
}
\examples{
d <- space_example()
W <- space_weights(d, "rook")
x <- space_counts(d, W = W, seed = 20261111L)
x
x$summary
x$hotspots[x$hotspots$category == "热点", c("region", "p_i", "quadrant")]

# 12 个地区以上的小样本可用较少的置换次数先看趋势
y <- space_counts(d, W = W, n_perm = 99L, seed = 1L)
y$global$p
}
\seealso{
\code{\link{space_moran}}, \code{\link{space_lisa}},
\code{\link{space_hotspot}}, \code{\link{space_report}}
}
