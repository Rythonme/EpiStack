\name{epiIngest-package}
\alias{epiIngest-package}
\alias{epiIngest}
\docType{package}
\title{epiIngest：多源接入与规则化质控}
\description{
EpiStack 体系的 L1 层（R 包 \pkg{epiIngest}）。负责把「数据怎么进来」这件事
做扎实：多源读取、规则化质控、按需脱敏，输出统一的契约长表供下游使用。

\strong{三条设计边界}
\itemize{
  \item 不引强制依赖：\code{Imports} 只有 utils / stats / tools，
    Excel、数据库、栅格、哈希全部走 \code{Suggests}。断网只装 base R 也能读 CSV 并质控。
  \item 规则是数据不是代码：规则集存成 JSON 随项目走，换口径改文件不改包。
  \item 换层不改口径：\code{\link{ingest_counts}} 只调用一次
    \code{epiCore::read_counts()}，与直接用该函数的数值结果必然一致。
}

\strong{典型流程}
\preformatted{
src  <- ingest_source("csv", "counts.csv", mapping = list(date = "日期", count = "发病数"))
ing  <- ingest_read(src)
ingest_profile(ing)                 # 先看数据长什么样
res  <- qc_apply(ing, ingest_qc_default(geo))
qc_report(res, "质控单.html")        # 发给数据提供方
core <- ingest_counts(src, rules = ingest_qc_default(geo), geo = geo)
}
}
\author{EpiStack Authors}
\keyword{package}
