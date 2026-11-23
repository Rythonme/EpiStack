\name{ineq_counts}
\alias{ineq_counts}
\title{一站式健康不平等分析（推荐入口）}
\usage{
ineq_counts(x, geo = NULL, year_value = NULL, cut = 0.5, groups = 4L,
            facilities = NULL, k = 3L, d0 = NULL, beta = 1,
            population = "population", value = "count",
            ses = "ses", region = "region")
}
\arguments{
\item{x}{契约长表 data.frame，或 \code{epiCore::read_counts()} 的返回值。}
\item{geo}{地区元数据，可从中补 SES 与坐标；契约对象自动取 \code{x$geo}。}
\item{year_value}{取哪一年；默认取数据中最新年份。}
\item{cut}{低/高 SES 分组阈值，默认 0.5；也可取 \code{"median"}。}
\item{groups}{分解用的分位数分组数，默认 4。}
\item{facilities}{设施点 data.frame(name, x, y, capacity)；NULL 表示按人口自动选。}
\item{k}{自动选取的设施点数。}
\item{d0}{可达性的特征距离；NULL 取距离中位数。}
\item{beta}{距离衰减指数，默认 1。}
\item{population, value, ses, region}{输入表中对应列的名字。}
}
\value{
类 \code{epi_ineq} 的列表：\code{curve}、\code{ci}、\code{sii}、\code{gini}、
\code{decompose}、\code{access}、\code{groups}、\code{core}、\code{summary}、
\code{tot} 与 \code{meta}。
}
\description{
把数据准备、集中曲线、CI、SII、Gini、分解与可达性串成一次调用。
}
\details{
无坐标时 \code{access} 为 NULL，其余指标照常给出。\code{core} 中的
\code{CI} 与 \code{rate_ratio} 用 \code{cut = 0.5} 的口径，与主仓切片一致。
}
\seealso{
\code{\link{ineq_curve}}, \code{\link{ineq_sii}}, \code{\link{ineq_decompose}}, \code{\link{ineq_access}}
}
\examples{
x <- ineq_counts(ineq_example())
x$summary
}
