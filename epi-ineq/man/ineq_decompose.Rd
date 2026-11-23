\name{ineq_decompose}
\alias{ineq_decompose}
\title{集中指数的组间/组内分解}
\usage{
ineq_decompose(x, groups = 4L, cut = NULL,
               population = "population", value = "count",
               ses = "ses", region = "region", geo = NULL,
               year_value = NULL)
}
\arguments{
\item{x}{契约长表 data.frame，或 \code{epiCore::read_counts()} 的返回值。}
\item{groups}{分位数分组数，默认 4。}
\item{cut}{若给定则按该阈值分两组，与 \code{groups} 互斥。}
\item{population, value, ses, region}{输入表中对应列的名字。}
\item{geo}{地区元数据。}
\item{year_value}{指定年份；默认取数据中最新年份。}
}
\value{
列表：\code{groups}（分组表）、\code{total}、\code{between}、\code{within}、
\code{residual}、\code{rate_diff}、\code{rate_ratio}、\code{paf}、
\code{weights} 与 \code{meta}。
}
\description{
把集中指数拆成组间与组内两部分，并给出组间率差、率比与可避免分值。
}
\details{
把每个地区的率替换为所在组均值后重算的 CI 是组间部分；组内曲线 CI 按
人口份额×病例份额加权求和是组内部分；余量单列，不硬塞进某一块。
\code{paf} 是若所有组都降到最低负担组率时可避免的病例比例。
}
\examples{
d <- ineq_decompose(ineq_example())
c(total = d$total, between = d$between, within = d$within)
}
