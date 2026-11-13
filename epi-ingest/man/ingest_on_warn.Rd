\name{ingest_on_warn}
\alias{ingest_on_warn}
\title{设置或读取全局 warn 处理策略}
\description{
warn 级命中默认保留并标记。有时整批数据要按更严的口径处理：
\code{ingest_on_warn("drop")} 让 warn 行直接剔除，
\code{ingest_on_warn("error")} 让一旦命中就中止。
设置会写进 \code{options("epiIngest.on_warn")}，对本会话内所有
\code{\link{qc_apply}} 生效。传 \code{NULL} 只读取不修改。
}
\usage{
ingest_on_warn(level = NULL)
}
\arguments{
  \item{level}{\code{"keep"} / \code{"drop"} / \code{"error"}；\code{NULL} 仅查询。}
}
\value{不可见地返回修改前的设置，便于临时切换后还原。}
\examples{
old <- ingest_on_warn("drop")
ingest_on_warn()
ingest_on_warn(old)
}
