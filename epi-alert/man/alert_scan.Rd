\name{alert_scan}
\alias{alert_scan}
\title{扫描异常信号并分级}
\usage{
alert_scan(x, method = c("auto", "seasonal", "pooled", "moving", "poisson"),
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

\item{assess}{评估范围：\code{"all"} / \code{"latest"} / 年份向量。}

\item{rules}{分级规则，见 \code{\link{alert_rules}}。}

\item{time_step}{时间粒度，\code{NULL} 时自动推断。}

\item{n_periods}{每年周期数，\code{NULL} 时按粒度推断。}
}
\value{
类 \code{epi_scan} 的列表：
\itemize{
  \item \code{band}：基线带，同 \code{\link{alert_baseline}} 的返回值；
  \item \code{current}：逐期判定明细，含 \code{baseline}、\code{upper}、
        \code{exceed}、\code{ratio}、\code{run_len}、\code{level}；
  \item \code{alerts}：级别非「正常」的行，按级别与计数排序，可直接落盘；
  \item \code{settings}：生效参数与规则。
}
}
\description{
在基线之上判定超限、累计连续期数并给出四级信号。
}
\details{
超限判定为 \code{count > upper}；超出倍数 \code{ratio = count / upper}。
连续超限期数在同一地区内按日期累计，超限段的每一期都记该段长度。

年度数据一期即一年，不存在「连续期」概念，\code{run_len} 最多为 1，
分级只按超出倍数走。
}
\examples{
s <- alert_scan(alert_example())
s
head(s$alerts)
}
\seealso{\code{\link{alert_counts}}, \code{\link{alert_summary}}}
