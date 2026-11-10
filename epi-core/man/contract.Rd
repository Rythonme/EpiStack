\name{epi_contract}
\alias{epi_contract}
\alias{epi_schema}
\alias{validate_contract}
\alias{epi_contract_check}
\alias{EPI_CONTRACT_VERSION}
\alias{EPI_REQUIRED_FIELDS}
\alias{print.epi_contract}
\title{EpiStack 统一数据契约与校验}
\description{
定义并校验所有 EpiStack 层共用的长表契约：date、region、count、population、disease。
主键为 date + region + disease；count 必须非负，population 必须为正数。
}
\usage{
epi_schema(version = EPI_CONTRACT_VERSION)

validate_contract(x, strict = TRUE, schema = epi_schema())

epi_contract_check(x, schema = epi_schema())

\method{print}{epi_contract}(x, ...)
}
\arguments{
  \item{version}{契约版本字符串。}
  \item{x}{data.frame 或 \code{epi_contract} 对象。}
  \item{strict}{TRUE 时校验失败即报错；FALSE 时返回问题描述向量。}
  \item{schema}{契约定义列表，默认由 \code{epi_schema()} 提供。}
  \item{...}{传递给 print 方法的额外参数。}
}
\value{
\code{epi_schema()} 返回版本化字段定义列表；\code{validate_contract()} 成功时返回
invisibly TRUE；\code{epi_contract_check()} 返回问题描述字符向量（无问题则长度为 0）。
}
\examples{
epi_schema()$version
d <- data.frame(date = as.Date("2021-01-04"), region = "A", count = 3,
                population = 1e5, disease = "HFRS")
validate_contract(d)
}
