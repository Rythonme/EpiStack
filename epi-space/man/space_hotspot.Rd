\name{space_hotspot}
\alias{space_hotspot}
\title{由 LISA 结果标注热点 / 冷点}
\usage{
space_hotspot(lisa, alpha = NULL)
}
\arguments{
\item{lisa}{\code{space_lisa()} 的结果，或含 \code{quadrant / p_i} 的 data.frame。}

\item{alpha}{显著性水平；NULL 时沿用 lisa 里的值。}
}
\value{
data.frame：原列加 \code{significant}（逻辑）与 \code{category}（类别）。
}
\description{
只在 LISA 显著时给地点类别。
}
\details{
HH 且 \code{p < alpha} 判热点，LL 判冷点，HL / LH 判空间离群；
不显著的一律「不显著」，不把噪声当地点。结果按类别和 p 值排序。
}
\examples{
d <- space_example()
W <- space_weights(d, "rook")
x <- space_counts(d, W = W, seed = 20261111L)
x$hotspots[x$hotspots$category != "不显著", c("region", "quadrant", "p_i", "category")]
}
\seealso{
\code{\link{space_lisa}}, \code{\link{space_counts}}
}
