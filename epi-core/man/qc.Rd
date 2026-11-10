\name{epi_qc}
\alias{epi_qc}
\title{监测计数接入质控}
\description{
对规范化长表逐行检查重复主键、缺失或负计数、无法解析的日期、
未知地区编码与无效人口分母；脏行一律剔除并逐项留痕，不静默改数。
}
\usage{
epi_qc(raw, geo = NULL, keys = c("date", "region", "disease"),
       check_population = FALSE)
}
\arguments{
  \item{raw}{含 date、region、count、disease 的 data.frame。}
  \item{geo}{可选地理编码表，用于校验未知地区编码。}
  \item{keys}{主键列名。}
  \item{check_population}{是否同时检查 population 列是否有效。}
}
\value{
列表：data（干净表）、report（质控报告 data.frame）、dropped（剔除行数）、
masks（每类问题的逐行逻辑掩码）。
}
\examples{
d <- data.frame(date = "2021-01-04", region = "A", count = c(3, NA),
                disease = "HFRS")
epi_qc(d)$dropped
}
