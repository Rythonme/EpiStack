\name{ingest_lineage}
\alias{ingest_lineage}
\title{汇总一次读取与质控的血缘}
\description{
「这份表是怎么来的、删了几行、用的哪版规则」应当一条命令答得出来。
血缘随产物一起走，可写入 JSON 归档，进报告与复现代码。
}
\usage{
ingest_lineage(x, file = NULL)
}
\arguments{
  \item{x}{\code{epi_ingest}、\code{epi_qc} 或带 \code{$ingest} 的 \code{epi_contract}。}
  \item{file}{若非 \code{NULL}，把血缘写入该 JSON 路径。}
}
\value{
\code{epi_lineage} 类的列表，含 run（包版本、时间、R 版本、平台）、
source、files（文件名 / md5 / 编码 / 分隔符）、qc（规则哈希、行数变化）、contract。
}
\examples{
d <- data.frame(date = c("2021-01-01", "2021-02-01"), region = "D01",
                count = c(10, 12), population = 1e5)
lin <- ingest_lineage(qc_apply(d, qc_rules()))
lin$qc$n_dropped
}
