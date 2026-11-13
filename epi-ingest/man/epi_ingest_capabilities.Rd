\name{epi_ingest_capabilities}
\alias{epi_ingest_capabilities}
\title{列出当前环境可用的读取能力}
\description{
返回一张能力表，如实报告每条读取路径是否就绪，缺包时直接给出
\code{install.packages()} 提示。缺包可以少一条路，但不能悄悄少。
}
\usage{
epi_ingest_capabilities()
}
\value{data.frame，列：capability、requires、available、note。}
\examples{
cap <- epi_ingest_capabilities()
cap[cap$capability \%in\% c("delimited", "excel"), c("capability", "available")]
}
