\name{ingest_profile}
\alias{ingest_profile}
\title{读取前数据画像}
\description{
给出列类型、缺失率、唯一值数量、日期范围、重复键与无法解析的计数。
这是给数据提供方看的第一张表，比直接打印前几行有用得多。
}
\usage{
ingest_profile(x, ...)
}
\arguments{
  \item{x}{\code{epi_ingest} 对象、数据源或 data.frame。}
  \item{...}{预留参数，当前未使用。}
}
\value{
\code{epi_ingest_profile} 类的列表：n_rows、n_cols、columns（data.frame）、
date_range、duplicate_keys、n_region、coerce、encoding、sep、label。
}
\examples{
d <- data.frame(date = rep(c("2021-01-01", "2021-02-01"), 2),
                region = c("D01", "D01", "D02", "D02"),
                count = c(12, 15, 9, 11), population = 1e5)
ingest_profile(d)
}
