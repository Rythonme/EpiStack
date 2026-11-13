\name{ingest_read}
\alias{ingest_read}
\title{读取数据源为标准长表}
\description{
把数据源读成三部分：\code{$data} 只有契约列
（date / region / count / population / disease），\code{$raw} 保留原始列，
\code{$meta} 记录编码、分隔符、md5 与强制转换失败计数。
本函数不做任何剔除——剔除是 \code{\link{qc_apply}} 的职责，边界清晰才好审计。
}
\usage{
ingest_read(x, ...)
}
\arguments{
  \item{x}{\code{epi_source} 对象、文件或目录路径、或 data.frame。}
  \item{...}{预留参数，当前未使用。}
}
\value{
\code{epi_ingest} 类的列表：
\itemize{
  \item \code{data}：标准长表，列顺序固定为 date / region / count，可选 population / disease；
  \item \code{raw}：原始列，用于追溯提供方给出的每一个字段；
  \item \code{source}：来源声明；
  \item \code{meta}：n_rows / n_files / files / encoding / sep / md5 / backend / read_at / coerce / mapping。
}
}
\examples{
d <- data.frame(date = c("2021-01-01", "2021-02-01"), region = "D01",
                count = c(12, 15), population = 1e5, stringsAsFactors = FALSE)
ing <- ingest_read(d)
ing$data
ing$meta$backend
}
