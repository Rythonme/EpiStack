\name{ineq_access}
\alias{ineq_access}
\title{距离衰减可达性}
\usage{
ineq_access(x, facilities = NULL, k = 3L, d0 = NULL, beta = 1,
            population = "population", value = "count",
            ses = "ses", region = "region", geo = NULL,
            year_value = NULL)
}
\arguments{
\item{x}{带坐标的契约长表或地区表；坐标列可为 x/y、row/col 或 lon/lat。}
\item{facilities}{设施点 data.frame(name, x, y, capacity)；NULL 自动按人口选。}
\item{k}{自动选取的设施点数。}
\item{d0}{特征距离；NULL 取所有地区-设施距离的中位数。}
\item{beta}{距离衰减指数，正数。}
\item{population, value, ses, region}{输入表中对应列的名字。}
\item{geo}{地区元数据。}
\item{year_value}{指定年份；默认取数据中最新年份。}
}
\value{
列表：\code{regions}（逐地区可达性）、\code{facilities}、\code{overall}、
\code{access_low}、\code{access_high}、\code{ratio_low_high}、
\code{d0}、\code{beta} 与 \code{meta}。
}
\description{
用设施点的距离衰减计算每个地区的可达性，并按人口加权汇总。
}
\details{
公式为 \code{A_i = sum_f cap_f / (1 + (d_if / d0)^beta)}。
距离用欧氏距离，坐标单位由调用方决定（格网步数、公里均可）。
\code{ratio_low_high} 按 SES 中位数分组比较人口加权可达性。
}
\examples{
ineq_access(ineq_example())$overall
}
