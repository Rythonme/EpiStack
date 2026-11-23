\name{ineq_summary}
\alias{ineq_summary}
\title{关键指标汇总}
\usage{
ineq_summary(x)
}
\arguments{
\item{x}{\code{ineq_counts()} 的返回值，或已有 metric/value 列的汇总表。}
}
\value{
data.frame：\code{metric}、\code{value} 与 \code{note}。
}
\description{
把 CI、SII、率比、Gini、PAF、分解占比与可达性比整理成一张表。
}
\examples{
ineq_summary(ineq_counts(ineq_example()))
}
