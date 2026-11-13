\name{qc_rules_read}
\alias{qc_rules_read}
\title{从 JSON 读回质控规则集}
\description{
零依赖读取规则文件（不使用 jsonlite）。规则文件由
\code{\link{qc_rules_write}} 生成，可以连同项目一起做版本管理。
}
\usage{
qc_rules_read(path)
}
\arguments{
  \item{path}{规则 JSON 文件路径。}
}
\value{\code{epi_qc_rules} 类的列表。}
\examples{
rules <- qc_rules(range = list(count = c(0, 1e6)), name = "demo")
f <- tempfile(fileext = ".json")
qc_rules_write(rules, f)
qc_rules_read(f)$range$count
}
