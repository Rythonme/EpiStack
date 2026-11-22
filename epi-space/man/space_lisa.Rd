\name{space_lisa}
\alias{space_lisa}
\title{局部空间自相关与四象限}
\usage{
space_lisa(x, W = NULL, value = NULL, n_perm = 999L,
           seed = NULL, alpha = 0.05)
}
\arguments{
\item{x}{数值向量（顺序与 W 的地区名一致），或契约表 / data.frame。}

\item{W}{权重矩阵；x 是 epiCore 契约时可省略。}

\item{value}{若 x 是表，指定用哪一列；默认按率（count / population）。}

\item{n_perm}{置换次数，默认 999。}

\item{seed}{随机种子；非 NULL 时在置换前固定。}

\item{alpha}{显著性水平，默认 0.05。}
}
\value{
类 \code{epi_space_lisa} 的列表，\code{table} 含 region / value / z /
spatial_lag / I_i / p_i / quadrant。
}
\description{
回答「哪里聚集」：逐地区给出局部 Moran 统计量与四象限。
}
\details{
\code{I_i = z_i * sum_j w_ij z_j / (sum_i z_i^2 / n)}。
象限按 \code{(z_i, 空间滞后)} 的符号分成 HH（高高）、LL（低低）、
HL（高低）与 LH（低高）。显著性用 \code{|I_i|} 的置换 p 值。
}
\examples{
d <- space_example()
W <- space_weights(d, "rook")
v <- tapply(d$count, d$region, sum)
li <- space_lisa(v, W = W$W, seed = 20261111L)
head(li$table)
}
\seealso{
\code{\link{space_hotspot}}, \code{\link{space_moran}}
}
