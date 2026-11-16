\name{alert_rules}
\alias{alert_rules}
\alias{print.epi_alert_rules}
\title{构造预警分级规则}
\usage{
alert_rules(watch = 1L, warn_run = 2L, warn_ratio = 1.5,
            alarm_run = 3L, alarm_ratio = 2,
            labels = c("正常", "关注", "预警", "告警"), name = NULL)
}
\arguments{
\item{watch}{判为关注所需的最少连续超限期数，默认 1。}

\item{warn_run}{判为预警的连续超限期数，默认 2。}

\item{warn_ratio}{判为预警的超出倍数（实测 / 上界），默认 1.5。}

\item{alarm_run}{判为告警的连续超限期数，默认 3。}

\item{alarm_ratio}{判为告警的超出倍数，默认 2。}

\item{labels}{四级名称，依次为正常、关注、预警、告警。}

\item{name}{规则集名称，写进报告便于追溯。}
}
\value{
类 \code{epi_alert_rules} 的列表。
}
\description{
把「几期算暴发、超几倍算告警」写成可序列化的规则集，而不是散落在代码里。
}
\details{
规则是数据不是代码：不同病种、不同报告制度的阈值差异很大，
把阈值写死在包里只会逼使用者改包源码。这里构造出的规则集可以
\code{\link{alert_rules_write}()} 存成 JSON 随项目版本管理。

校验：必须 \code{watch >= 1}，且 \code{warn_run >= watch}、
\code{alarm_run >= warn_run}、\code{alarm_ratio >= warn_ratio}，
否则直接报错，不静默修正。
}
\examples{
alert_rules()
alert_rules(warn_ratio = 2, alarm_ratio = 3, name = "流感-2026")
}
\seealso{\code{\link{alert_rules_write}}, \code{\link{alert_default_rules}}}
