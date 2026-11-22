\name{space_weights}
\alias{space_weights}
\title{校验或构造空间权重矩阵}
\usage{
space_weights(x, style = c("rook", "queen"),
              row_standardize = TRUE, regions = NULL)
}
\arguments{
\item{x}{权重矩阵，或含 \code{region / row / col} 的格网地区表。}

\item{style}{格网邻接方式：rook（共边）或 queen（共边或共点）。}

\item{row_standardize}{是否行标准化，默认 TRUE。}

\item{regions}{可选：按此顺序重排权重矩阵。}
}
\value{
类 \code{epi_space_weights} 的列表，含 \code{W}、\code{regions}、\code{n}、
\code{density} 与行和范围。
}
\description{
检查权重矩阵是否可用于空间自相关，或从格网坐标构造一个。
}
\details{
检查项：方阵、地区名一致、无自环、非负、邻接结构对称、无孤立地区。
行标准化后 \code{W[i,j]} 与 \code{W[j,i]} 可以不等（度数不同），
但邻接结构必须对称，否则直接报错。
}
\examples{
d <- space_example()
w <- space_weights(d, "rook")
w
head(space_neighbors(w))
}
\seealso{
\code{\link{space_neighbors}}, \code{\link{space_counts}}
}
