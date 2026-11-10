\name{period}
\alias{period}
\alias{epi_period}
\alias{epi_wrap_period}
\alias{epi_period_label}
\title{时间粒度与季节周期映射}
\description{
把日期映射到季节周期序号，使同一份契约可以承载周报、月报、季报与年报；
切换粒度只改 time_step，不改上下游接口。
}
\usage{
epi_period(date, n_periods = 52L,
           time_step = c("week", "month", "quarter", "year"),
           origin = NULL)

epi_wrap_period(w, n_periods)

epi_period_label(p, time_step = "month")
}
\arguments{
  \item{date}{Date 对象或可解析为日期的字符向量。}
  \item{n_periods}{一个周期内的期数。}
  \item{time_step}{时间粒度：week、month、quarter 或 year。}
  \item{origin}{year 粒度的基准年份；NULL 时取数据中最早年份。}
  \item{w}{待回绕的周期序号向量。}
  \item{p}{周期序号。}
}
\value{
\code{epi_period()} 与 \code{epi_wrap_period()} 返回整数向量；
\code{epi_period_label()} 返回可读标签字符向量。
}
\examples{
epi_period(as.Date("2021-06-15"), 12L, "month")
epi_wrap_period(c(0L, 13L), 12L)
epi_period_label(6L, "month")
}
