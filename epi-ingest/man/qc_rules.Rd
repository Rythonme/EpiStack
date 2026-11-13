\name{qc_rules}
\alias{qc_rules}
\title{构造质控规则集}
\description{
规则是数据不是代码：\code{qc_rules()} 产出一个可序列化的规则集，
可以存成 JSON 随项目版本管理（见 \code{\link{qc_rules_write}}），
换口径时改文件、不改包。
}
\usage{
qc_rules(required = c("date", "region", "count"),
         unique_key = NULL, range = NULL, date_seq = NULL,
         region_code = NULL, outlier = NULL, cross_field = NULL,
         name = NULL)
}
\arguments{
  \item{required}{必填列名，空值即 error。}
  \item{unique_key}{唯一键列；重复时保留首条，其余按 error 剔除。}
  \item{range}{数值范围，如 \code{list(count = c(0, 1e7))}；越界按 error。}
  \item{date_seq}{日期连续性，如 \code{list(by = "month", max_gap = 1)}；
    断档按 warn。}
  \item{region_code}{地区白名单，如 \code{list(allowed = geo$region)}；不在其中按 error。}
  \item{outlier}{异常值检查，如 \code{list(method = "mad", k = 8)}，method 取 mad 或 iqr；按 warn。}
  \item{cross_field}{跨字段一致性，如
    \code{list(list(lhs = "count", op = "<=", rhs = "population"))}；按 error。}
  \item{name}{规则集名称，写进报告与血缘。}
}
\value{\code{epi_qc_rules} 类的列表。}
\seealso{\code{\link{qc_apply}}, \code{\link{ingest_qc_default}}}
\examples{
rules <- qc_rules(required = c("date", "region", "count"),
                  unique_key = c("date", "region"),
                  range = list(count = c(0, 1e6)),
                  date_seq = list(by = "month", max_gap = 1))
rules
}
