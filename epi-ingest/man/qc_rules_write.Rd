\name{qc_rules_write}
\alias{qc_rules_write}
\title{把质控规则集写成 JSON}
\description{
规则随项目走：把口径存成可读的 JSON，评审时能 diff，换口径时改文件不改包。
}
\usage{
qc_rules_write(rules, path)
}
\arguments{
  \item{rules}{\code{\link{qc_rules}} 的返回值。}
  \item{path}{输出路径，目录不存在会自动创建。}
}
\value{不可见地返回写入路径。}
\examples{
f <- tempfile(fileext = ".json")
qc_rules_write(qc_rules(name = "demo"), f)
file.exists(f)
}
