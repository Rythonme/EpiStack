\name{ineq_groups}
\alias{ineq_groups}
\title{按 SES 分组}
\usage{
ineq_groups(x, cut = 0.5, groups = NULL,
            population = "population", value = "count",
            ses = "ses", region = "region", geo = NULL,
            year_value = NULL)
}
\arguments{
\item{x}{契约长表 data.frame，或 \code{epiCore::read_counts()} 的返回值。}
\item{cut}{数值阈值（低于该值为低 SES 组）或 \code{"median"}。}
\item{groups}{按 SES 分位数切成的组数（2–10），与 \code{cut} 二选一。}
\item{population, value, ses, region}{输入表中对应列的名字。}
\item{geo}{地区元数据。}
\item{year_value}{指定年份；默认取数据中最新年份。}
}
\value{
data.frame：\code{group}、\code{n}、\code{population}、\code{count}、
\code{rate}、\code{rate_per_100k}、\code{pop_share}、\code{count_share}。
另有属性 \code{members}（逐地区组标签），供分解使用。
}
\description{
把地区按 SES 切成两组或若干分位组，并给出各组的率与份额。
}
\details{
\code{cut = 0.5} 是主仓切片使用的口径；\code{cut = "median"} 是面板演示的口径。
}
\examples{
ineq_groups(ineq_example(), cut = 0.5)
}
