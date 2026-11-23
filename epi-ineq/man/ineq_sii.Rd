\name{ineq_sii}
\alias{ineq_sii}
\title{斜率不平等指数（SII）}
\usage{
ineq_sii(x, population = "population", value = "count",
         ses = "ses", region = "region", per = 1e5,
         geo = NULL, year_value = NULL)
}
\arguments{
\item{x}{契约长表 data.frame，或 \code{epiCore::read_counts()} 的返回值。}
\item{population, value, ses, region}{输入表中对应列的名字。}
\item{per}{率的展示倍数，默认每十万人。}
\item{geo}{地区元数据。}
\item{year_value}{指定年份；默认取数据中最新年份。}
}
\value{
列表：\code{sii}、\code{se}、\code{p_value}、\code{r_squared}、
\code{intercept}、\code{n}、\code{per} 与 \code{direction}。
}
\description{
用 SES 人口累积中点位置对率做人口加权回归，斜率即最弱势端到最优势端的预测率差。
}
\details{
至少需要 3 个地区。对疾病负担而言斜率为负表示弱势地区负担更重，
与 CI 的负号方向一致。回归用 \code{stats::lm()}，无需额外包。
}
\examples{
ineq_sii(ineq_example())$sii
}
