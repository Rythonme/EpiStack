\name{ineq_curve}
\alias{ineq_curve}
\title{人口加权集中曲线}
\usage{
ineq_curve(x, region = "region", count = "count",
           population = "population", ses = "ses",
           year_value = NULL, geo = NULL)
}
\arguments{
\item{x}{契约长表 data.frame，或 \code{epiCore::read_counts()} 的返回值。}
\item{region, count, population, ses}{输入表中对应列的名字。}
\item{year_value}{取哪一年；默认取数据中最新年份。}
\item{geo}{地区元数据，可从中补 SES。}
}
\value{
类 \code{epi_ineq_curve} 的列表：\code{curve}（逐地区累积份额）、
\code{CI}、\code{area}（梯形面积）与 \code{meta}。
}
\description{
按 SES 升序画人口加权集中曲线，并给出集中指数。
}
\details{
横轴是人口累积份额，纵轴是病例累积份额。CI 等于 1 减去曲线下面积的两倍；
负值表示同样的人口份额累积了更多病例，即负担集中于低 SES 地区。
}
\examples{
cv <- ineq_curve(ineq_example())
cv$CI
}
