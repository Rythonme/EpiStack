\name{alert_methods}
\alias{alert_methods}
\title{可用的基线方法}
\usage{
alert_methods()
}
\value{
data.frame，四列：\code{method}、\code{label}、\code{time_step}（适用粒度）、
\code{note}（口径说明）。
}
\description{
四种方法：\code{seasonal}（同季节窗口的对数正态上界，周 / 月 / 季默认）、
\code{pooled}（不分季节，年度默认）、\code{moving}（最近若干期的算术均值加
\code{k} 倍标准差）、\code{poisson}（同季节窗口历史均数作 \eqn{\lambda}，
取单侧泊松上分位，小计数时更稳）。
}
\examples{
alert_methods()[, c("method", "time_step")]
}
\seealso{\code{\link{alert_baseline}}}
