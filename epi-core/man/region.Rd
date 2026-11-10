\name{region}
\alias{region}
\alias{normalize_region}
\alias{epi_region_codes}
\title{地区编码规范化与码表生成}
\description{
清理 UTF-8 BOM、内部空白与省级行政后缀（省 / 市 / 自治区等），
把不同写法的地区名收敛为同一个编码，避免上游换写法导致下游静默丢行。
不做臆造的行政区划代码表，需要别名映射时由调用方传入。
}
\usage{
normalize_region(x, strip_suffix = TRUE, aliases = NULL)

epi_region_codes(regions, strip_suffix = TRUE, aliases = NULL)
}
\arguments{
  \item{x}{地区名称字符向量。}
  \item{regions}{地区名称字符向量。}
  \item{strip_suffix}{是否去掉省级行政后缀。}
  \item{aliases}{命名向量或列表：names 为原始写法，值为目标编码。}
}
\value{
\code{normalize_region()} 返回规范化后的字符向量；
\code{epi_region_codes()} 返回含 region、region_id、label 三列的 data.frame。
}
\examples{
normalize_region(c(" 陕西省 ", "内蒙古自治区"))
epi_region_codes(c("陕西省", "广东省"))
}
