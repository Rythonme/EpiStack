\name{ineq_example}
\alias{ineq_example}
\title{合成面板示例}
\usage{
ineq_example(n_side = 4L, years = 2022:2024)
}
\arguments{
\item{n_side}{格网边长，默认 4（16 个虚构地区）。}
\item{years}{年份向量。}
}
\value{
data.frame：契约列 date/region/count/population/disease，另带 ses/x/y。
}
\description{
生成确定性的合成数据：SES 从左到右递增，率从左到右递减。
}
\details{
不调用随机数，不改变调用方的随机数状态。地区为虚构格网，不对应真实行政区。
}
\examples{
head(ineq_example())
}
