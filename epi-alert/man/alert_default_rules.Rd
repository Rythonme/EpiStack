\name{alert_default_rules}
\alias{alert_default_rules}
\title{包内默认分级规则}
\usage{
alert_default_rules()
}
\value{
类 \code{epi_alert_rules} 的列表，等价于 \code{alert_rules()} 的默认值。
}
\description{
超限 1 期关注；连续 2 期或超 1.5 倍预警；连续 3 期或超 2 倍告警。
随包提供同一份 JSON 模板：\code{system.file("rules", "alert_default.json",
package = "epiAlert")}，复制到自己项目里改完即可用。
}
\examples{
alert_default_rules()
}
\seealso{\code{\link{alert_rules}}}
