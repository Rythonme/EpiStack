\name{alert_example}
\alias{alert_example}
\title{合成周报示例数据}
\usage{
alert_example(regions = c("A 区", "B 区", "C 区", "D 区"),
              years = 2022:2024, n_periods = 52L, outbreak = NULL)
}
\arguments{
\item{regions}{地区名向量。}

\item{years}{年份向量。}

\item{n_periods}{每年周数。}

\item{outbreak}{注入升高的地区，默认取最后一个地区。}
}
\value{
data.frame，列同契约：\code{date}、\code{region}、\code{count}、
\code{population}、\code{disease}。
}
\description{
四个虚构地区的周报计数，冬季高、夏季低，最后一个地区在最后一年末段持续升高。
用确定性算式生成，不调用 \code{set.seed()}，两次调用结果完全一致；
不含任何真实观测，只用于示例与自检。
}
\examples{
d <- alert_example()
range(d$date)
sum(d$count)
}
\seealso{\code{\link{alert_counts}}}
