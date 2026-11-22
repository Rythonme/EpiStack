\name{space_moran}
\alias{space_moran}
\title{全局空间自相关：Moran's I 置换检验}
\usage{
space_moran(x, W = NULL, value = NULL, n_perm = 999L,
            seed = NULL, alternative = c("two.sided", "greater", "less"))
}
\arguments{
\item{x}{数值向量（顺序与 W 的地区名一致），或契约表 / data.frame。}

\item{W}{权重矩阵；x 是 epiCore 契约时可省略。}

\item{value}{若 x 是表，指定用哪一列；默认按率（count / population）。}

\item{n_perm}{置换次数，默认 999。}

\item{seed}{随机种子；非 NULL 时函数在置换前固定。}

\item{alternative}{双侧（默认）、greater 或 less。}
}
\value{
类 \code{epi_space_moran} 的列表：\code{I}、\code{p}、\code{I_null}、\code{n_perm} 等。
}
\description{
回答「整体是否存在空间聚集」。
}
\details{
统计量为 \code{I = (n / S0) * sum_ij w_ij z_i z_j / sum_i z_i^2}，
其中 \code{z = x - mean(x)}，\code{S0 = sum(W)}。
置换分布由 \code{replicate(n_perm, I(sample(x)))} 得到，
双侧 p 值为 \code{(1 + sum(abs(I_null) >= abs(I))) / (n_perm + 1)}。

给定同一个 seed，结果可逐位复现；不传 seed 时不改变调用方的随机数状态之外，
置换结果每次不同。
}
\examples{
d <- space_example()
W <- space_weights(d, "rook")
v <- tapply(d$count, d$region, sum)
space_moran(v, W = W$W, seed = 20261111L)
space_moran(v, W = W$W, n_perm = 0L)$I
}
\seealso{
\code{\link{space_lisa}}, \code{\link{space_counts}}
}
