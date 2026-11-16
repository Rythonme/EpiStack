\name{alert_rules_write}
\alias{alert_rules_write}
\alias{alert_rules_read}
\title{规则集的 JSON 读写}
\usage{
alert_rules_write(rules, path)

alert_rules_read(path)
}
\arguments{
\item{rules}{`alert_rules()` 的返回值。}

\item{path}{JSON 文件路径；写入时目录不存在会自动创建。}
}
\value{
\code{alert_rules_write()} 返回路径（不可见）；
\code{alert_rules_read()} 返回 \code{epi_alert_rules} 对象。
}
\description{
把分级阈值存成 JSON 随项目版本管理，换口径改文件、不改包。
}
\examples{
f <- file.path(tempdir(), "rules.json")
alert_rules_write(alert_rules(warn_ratio = 2), f)
alert_rules_read(f)
}
\seealso{\code{\link{alert_rules}}}
