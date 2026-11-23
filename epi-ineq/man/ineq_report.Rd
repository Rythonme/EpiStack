\name{ineq_report}
\alias{ineq_report}
\title{输出分析结果}
\usage{
ineq_report(x, output = c("console", "csv", "html"),
            file = NULL, dir = NULL)
}
\arguments{
\item{x}{\code{ineq_counts()} 的返回值。}
\item{output}{输出方式：\code{"console"}、\code{"csv"} 或 \code{"html"}。}
\item{file}{html 输出路径；csv 输出主表路径。}
\item{dir}{csv 输出目录，与 \code{file} 二选一。}
}
\value{
不可见地返回输出路径（控制台输出返回 NULL）。
}
\description{
把分析结果输出为控制台摘要、三张 CSV 或单文件 HTML 分析单。
}
\details{
HTML 内联 SVG 集中曲线，不引用外部资源，可离线打开或直接发出。
}
\examples{
\dontrun{
x <- ineq_counts(ineq_example())
ineq_report(x, "html", "ineq.html")
}
}
