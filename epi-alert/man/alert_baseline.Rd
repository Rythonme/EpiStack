\name{alert_baseline}
\alias{alert_baseline}
\title{计算逐期基线带}
\usage{
alert_baseline(x, method = c("auto", "seasonal", "pooled", "moving", "poisson"),
               window = 1L, k = 1.645, min_obs = 3L, offset = 0.5,
               assess = "all", time_step = NULL, n_periods = NULL)
}
\arguments{
\item{x}{契约长表，含 \code{date} / \code{region} / \code{count}；
也可以是 \code{epiCore::read_counts()} 的返回值，此时粒度与周期数自动沿用。}

\item{method}{基线方法，见 \code{\link{alert_methods}}。
默认 \code{"auto"}：周 / 月 / 季走 \code{seasonal}，年度数据走 \code{pooled}。}

\item{window}{\code{seasonal} 取同周期前后各几期；\code{moving} 取最近几期。默认 1。}

\item{k}{上界系数，默认 1.645（约 95\% 单侧）。}

\item{min_obs}{最少历史观测数，不足则该期不给基线。默认 3。}

\item{offset}{对数变换的连续性校正，默认 0.5。}

\item{assess}{评估范围：\code{"all"} 逐期回溯、\code{"latest"} 只评最新周期，
或年份向量。默认 \code{"all"}。}

\item{time_step}{时间粒度 \code{week} / \code{month} / \code{quarter} / \code{year}，
\code{NULL} 时按日期间隔推断。}

\item{n_periods}{每年周期数，\code{NULL} 时按粒度取 52 / 12 / 4 / 1。}
}
\value{
data.frame，每行对应一个评估目标，列为
\code{region}、\code{period}、\code{cycle}、\code{date}、
\code{baseline}、\code{upper}、\code{n_hist}、\code{method}。
历史不足 \code{min_obs} 时 \code{baseline} 与 \code{upper} 为 \code{NA}。
}
\description{
为每个评估目标计算基线与单侧上界。历史只取评估期之前的观测。
}
\details{
季节 / 合并 / 泊松三种方法只取更早年份（\code{cycle} 严格小于评估期）的历史，
同一年内相邻期不进入基线——否则本期暴发会抬高相邻期的上界，回溯评估越评越平。
\code{moving} 是时间序列口径，取紧邻评估期之前最近 \code{window} 期。

上界公式（对数正态）：\code{exp(mean(log(count + offset)) + k * sd) - offset}；
泊松方法取 \code{qpois(pnorm(k), lambda)}，小计数时比对数正态稳。
}
\examples{
d <- alert_example()
b <- alert_baseline(d)
head(b[b$cycle == max(b$cycle), ])

# 年度数据自动改用合并基线
dy <- d[format(d$date, "\%m-\%d") == "01-01", ]
unique(alert_baseline(dy, time_step = "year")$method)
}
\seealso{\code{\link{alert_counts}}, \code{\link{alert_scan}}}
