\name{space_report}
\alias{space_report}
\title{输出空间分析单}
\usage{
space_report(x, file = NULL, format = c("auto", "console", "csv", "html"),
             title = NULL, max_rows = 24L)
}
\arguments{
\item{x}{\code{space_counts()} 的结果。}

\item{file}{输出路径；NULL 只打印控制台。}

\item{format}{auto（按扩展名）/ console / csv / html。}

\item{title}{报告标题。}

\item{max_rows}{HTML 里最多列几条地区。}
}
\value{
不可见地返回 x。
}
\description{
三种出口：控制台自看、CSV 交给别的系统、单文件 HTML 直接发出。
}
\details{
HTML 单文件无外部资源，可离线打开。CSV 出口同时写逐地区结果与摘要表，
摘要文件名是在给定文件名后加 \code{_summary.csv}。
}
\examples{
d <- space_example()
W <- space_weights(d, "rook")
x <- space_counts(d, W = W, seed = 20261111L)
space_report(x)
f <- file.path(tempdir(), "空间分析单.html")
space_report(x, f)
}
\seealso{
\code{\link{space_counts}}, \code{\link{space_summary}}
}
