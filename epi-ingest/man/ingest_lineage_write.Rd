\name{ingest_lineage_write}
\alias{ingest_lineage_write}
\title{把血缘写成 JSON}
\description{把 \code{\link{ingest_lineage}} 的结果落盘，随分析产物一起归档。}
\usage{
ingest_lineage_write(x, path)
}
\arguments{
  \item{x}{\code{epi_lineage} 对象，或其他可交给 \code{ingest_lineage()} 的对象。}
  \item{path}{输出 JSON 路径。}
}
\value{不可见地返回写入路径。}
\examples{
d <- data.frame(date = "2021-01-01", region = "D01", count = 10, population = 1e5)
f <- tempfile(fileext = ".json")
ingest_lineage_write(d, f)
file.exists(f)
}
