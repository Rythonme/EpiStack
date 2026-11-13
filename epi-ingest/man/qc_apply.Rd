\name{qc_apply}
\alias{qc_apply}
\title{执行质控规则集}
\description{
按规则逐条检查并逐行留痕。error 级一律剔除；warn 级默认保留并标记，
可用 \code{on_warn} 或全局开关 \code{\link{ingest_on_warn}} 改为剔除或中止。
所有命中都记录到行号，能追回原始表的哪一行。
}
\usage{
qc_apply(x, rules = NULL, on_warn = NULL)
}
\arguments{
  \item{x}{\code{epi_ingest} 对象、数据源或 data.frame。}
  \item{rules}{\code{\link{qc_rules}} 的返回值或规则 JSON 路径；
    \code{NULL} 时使用 \code{\link{ingest_qc_default}}。}
  \item{on_warn}{warn 级命中如何处理：\code{"keep"} 保留并标记（默认）、
    \code{"drop"} 直接剔除、\code{"error"} 命中即中止。\code{NULL} 表示读全局设置。}
}
\value{
\code{epi_qc} 类的列表：data（清洗后的表）、report（按规则汇总）、
masks（逐行留痕，含 rule / level / row / detail）、dropped、n_error、n_warn、
n_input、n_output、on_warn、rules、source、read、ingest。
}
\examples{
d <- data.frame(date = c("2021-01-01", "2021-01-01", "2021-02-01"),
                region = c("D01", "D01", "D01"),
                count = c(10, 10, -3), population = 1e5)
res <- qc_apply(d, qc_rules(unique_key = c("date", "region"),
                            range = list(count = c(0, 1e6))))
res$report
res$dropped
}
