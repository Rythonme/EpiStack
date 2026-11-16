\name{alert_summary}
\alias{alert_summary}
\title{按地区汇总异常信号}
\usage{
alert_summary(x)
}
\arguments{
\item{x}{\code{alert_counts()} 或 \code{alert_scan()} 的结果。}
}
\value{
data.frame，每个地区一行：\code{n_periods} 评估期数、\code{n_exceed} 超限期数、
\code{n_watch} / \code{n_warn} / \code{n_alarm} 各级条数、\code{peak_level}
最高级别、\code{max_ratio} 最大超出倍数、\code{last_alert} 最后一次信号日期。
按最高级别、告警条数、最大倍数依次排序。
}
\description{
逐期明细是给分析看的，汇总表是给「先看哪里」用的。
}
\examples{
x <- alert_counts(alert_example())
alert_summary(x)
}
\seealso{\code{\link{alert_counts}}, \code{\link{alert_report}}}
