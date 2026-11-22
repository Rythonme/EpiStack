\name{space_summary}
\alias{space_summary}
\title{空间分析摘要}
\usage{
space_summary(x)
}
\arguments{
\item{x}{\code{space_counts()} 的结果。}
}
\value{
data.frame(metric, value)，便于写进 manifest 或报告。
}
\description{
把全局指标与各类地点数量压成一张可直接引用的表。
}
\details{
包含地区数、年份、全局 I 与 p、置换次数、热点 / 冷点 / 空间离群 /
显著地点数。计数母表始终是四个固定类别，未出现的类别计 0。
}
\examples{
d <- space_example()
W <- space_weights(d, "rook")
x <- space_counts(d, W = W, seed = 20261111L)
space_summary(x)
}
\seealso{
\code{\link{space_counts}}, \code{\link{space_report}}
}
