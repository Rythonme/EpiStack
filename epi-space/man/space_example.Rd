\name{space_example}
\alias{space_example}
\title{合成格网示例数据}
\usage{
space_example(n_side = 4L, years = 2022:2024, hotspot = NULL)
}
\arguments{
\item{n_side}{格网边长，默认 4（16 个虚构地区）。}

\item{years}{年份向量。}

\item{hotspot}{注入高值的地区，默认取右下角。}
}
\value{
data.frame：date / region / count / population / disease，另带 row / col 供构造格网权重。
}
\description{
确定性合成数据，示例与自检都不依赖外部文件。
}
\details{
空间梯度让高值在注入点周围成片，便于验证 LISA 的热点识别。
用确定性算式而非随机数，不改变调用方的随机数状态。
}
\examples{
d <- space_example()
head(d)
space_weights(d, "rook")
}
\seealso{
\code{\link{space_counts}}
}
