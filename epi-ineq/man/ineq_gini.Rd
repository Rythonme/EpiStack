\name{ineq_gini}
\alias{ineq_gini}
\title{Gini 系数（按率排序）}
\usage{
ineq_gini(x, population = "population", value = "count",
          ses = "ses", region = "region", geo = NULL,
          year_value = NULL)
}
\arguments{
\item{x}{契约长表 data.frame，或 \code{epiCore::read_counts()} 的返回值。}
\item{population, value, ses, region}{输入表中对应列的名字。}
\item{geo}{地区元数据。}
\item{year_value}{指定年份；默认取数据中最新年份。}
}
\value{
单个数值：人口加权 Gini 系数。
}
\description{
按率而非 SES 排序的集中曲线，衡量病例在地区间的集中程度。
}
\details{
Gini 不区分这种集中是否沿社会经济梯度；若要回答「是否偏向弱势」，
请用 \code{\link{ineq_ci}} 或 \code{\link{ineq_sii}}。
}
\examples{
ineq_gini(ineq_example())
}
