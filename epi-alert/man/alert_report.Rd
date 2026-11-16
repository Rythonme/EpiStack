\name{alert_report}
\alias{alert_report}
\title{输出预警单}
\usage{
alert_report(x, file = NULL, format = c("auto", "console", "csv", "html"),
             title = NULL, max_rows = 24L)
}
\arguments{
\item{x}{\code{alert_counts()} 的结果。}

\item{file}{输出路径；\code{NULL} 只打印到控制台。}

\item{format}{\code{auto}（按扩展名推断）/ \code{console} / \code{csv} / \code{html}。}

\item{title}{报告标题，默认「预警单」。}

\item{max_rows}{HTML 里最多列几条信号，默认 24。}
}
\value{
不可见地返回 \code{x}。
}
\description{
三种出口：控制台自己看；CSV 交给业务方或其它系统（信号清单 +
\code{_regions.csv} 地区汇总）；HTML 是单文件、内联样式、可离线打开的报告，
不依赖 pandoc 或任何前端库。
}
\examples{
x <- alert_counts(alert_example())
alert_report(x)

f <- file.path(tempdir(), "alert.csv")
alert_report(x, f, format = "csv")
file.exists(f)
}
\seealso{\code{\link{alert_counts}}, \code{\link{alert_summary}}}
