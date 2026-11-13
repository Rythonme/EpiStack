\name{qc_report}
\alias{qc_report}
\title{输出质控单}
\description{
三种出口对应三种真实场景：控制台给自己看，CSV 发给数据提供方按行号去改，
HTML 是单文件、内联样式、可离线打开的报告。不依赖 pandoc 或任何外部工具。
}
\usage{
qc_report(x, file = NULL, format = c("auto", "console", "csv", "html"),
          title = NULL, max_examples = 5L)
}
\arguments{
  \item{x}{\code{\link{qc_apply}} 的结果，或可直接读取的数据源。}
  \item{file}{输出路径；\code{NULL} 只打印到控制台。}
  \item{format}{\code{"auto"} 按扩展名判断，或显式指定
    \code{console} / \code{csv} / \code{html}。}
  \item{title}{报告标题。}
  \item{max_examples}{HTML 中每种规则最多列几行命中样例。}
}
\value{不可见地返回 \code{epi_qc} 对象，便于链式调用。}
\examples{
d <- data.frame(date = c("2021-01-01", "2021-02-01"), region = "D01",
                count = c(10, NA), population = 1e5)
res <- qc_apply(d, qc_rules())
qc_report(res)
}
