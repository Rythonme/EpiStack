\name{ineq_ci}
\alias{ineq_ci}
\title{集中指数}
\usage{
ineq_ci(x, population = "population", value = "count",
        ses = "ses", region = "region")
}
\arguments{
\item{x}{集中曲线、\code{ineq_curve()} 的返回值，或一地区一行的 data.frame。}
\item{population, value, ses, region}{输入表中对应列的名字。}
}
\value{
单个数值：集中指数。负值表示负担集中于低 SES 地区。
}
\description{
计算人口加权集中指数 CI = 1 - 2×集中曲线下面积（梯形法）。
}
\details{
曲线按 SES 升序构造。给定 \code{cum_pop} 与 \code{cum_value} 列的数据框
也被接受，便于直接用已有曲线复算。
}
\examples{
ineq_ci(ineq_example())
}
