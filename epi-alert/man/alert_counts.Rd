\name{alert_counts}
\alias{alert_counts}
\title{从契约表产出预警结果（推荐入口）}
\usage{
alert_counts(x, method = c("auto", "seasonal", "pooled", "moving", "poisson"),
             window = 1L, k = 1.645, min_obs = 3L, offset = 0.5,
             assess = "all", rules = alert_default_rules(),
             time_step = NULL, n_periods = NULL)
}
\arguments{
\item{x}{契约长表，或 \code{epiCore::read_counts()} 的返回值。}

\item{method}{基线方法，默认按粒度自动选择，见 \code{\link{alert_baseline}}。}

\item{window}{季节窗口或滑动窗口宽度，默认 1。}

\item{k}{上界系数，默认 1.645。}

\item{min_obs}{最少历史观测数，默认 3。}

\item{offset}{对数变换的连续性校正，默认 0.5。}

\item{assess}{评估范围：\code{"all"} 逐期回溯（默认）、\code{"latest"}
只评最新周期、或年份向量。}

\item{rules}{分级规则，见 \code{\link{alert_rules}}。}

\item{time_step}{时间粒度，\code{NULL} 时自动推断。}

\item{n_periods}{每年周期数，\code{NULL} 时按粒度推断。}
}
\value{
类 \code{epi_alert} 的列表：
\code{band}（基线带）、\code{current}（逐期明细）、\code{alerts}（信号清单）、
\code{summary}（按地区汇总）、\code{settings}（生效参数）、
\code{meta}（输入规模与包版本）。
}
\description{
一键完成基线、超限判定、分级与按地区汇总，是推荐入口。
}
\details{
本函数只读契约、不改契约。默认 \code{assess = "all"} 逐期回溯，
适合做历史检验；当期监测报表传 \code{assess = "latest"}。

分级默认：连续超限 1 期判关注，连续 2 期或超 1.5 倍判预警，
连续 3 期或超 2 倍判告警。阈值可用 \code{\link{alert_rules}()} 改写。
}
\examples{
x <- alert_counts(alert_example())
x
x$summary

# 只评最新周期的当期报表口径
y <- alert_counts(alert_example(), assess = "latest")
nrow(y$alerts)

# 分级阈值随项目走
f <- file.path(tempdir(), "alert_rules.json")
alert_rules_write(alert_rules(warn_ratio = 2, alarm_ratio = 3), f)
strict <- alert_counts(alert_example(), rules = alert_rules_read(f))
sum(strict$current$level == "告警")
}
\seealso{
\code{\link{alert_summary}}, \code{\link{alert_report}},
\code{\link{alert_rules}}, \code{\link{alert_methods}}
}
