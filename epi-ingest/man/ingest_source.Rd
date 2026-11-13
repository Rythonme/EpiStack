\name{ingest_source}
\alias{ingest_source}
\title{声明一个数据源}
\description{
把「数据从哪来、怎么读」描述成一个可序列化的 \code{epi_source} 对象。
声明与读取分开，好处是同一份读取配置能存进项目、写进报告，
也可以只声明不读（先做能力检查）。
}
\usage{
ingest_source(type = c("csv", "tsv", "delim", "excel", "db", "api", "raster"),
              path = NULL, url = NULL, query = NULL, con = NULL,
              sheet = NULL, layer = NULL, headers = NULL,
              records_path = NULL,
              encoding = "auto", sep = NULL, skip = 0L,
              mapping = NULL, label = NULL)
}
\arguments{
  \item{type}{源类型：\code{csv} / \code{tsv} / \code{delim} 为分隔符文本，
    \code{excel} 为工作簿，\code{db} 为数据库查询，\code{api} 为 HTTP 接口，
    \code{raster} 为栅格（请改用 \code{\link{ingest_zonal}} 提取）。}
  \item{path}{文件或目录路径。目录会读取其中所有 csv/tsv/txt 并按列名对齐纵向合并。}
  \item{url}{\code{type = "api"} 时的 HTTP 地址。}
  \item{query}{\code{type = "db"} 时的 SQL 查询语句。}
  \item{con}{\code{type = "db"} 时的 DBI 连接对象。}
  \item{sheet}{Excel 工作表名或序号。}
  \item{layer}{栅格图层名或序号。}
  \item{headers}{命名字符向量，附加的 HTTP 请求头。}
  \item{records_path}{JSON 响应中记录数组的点路径，如 \code{"result.records"}。}
  \item{encoding}{\code{"auto"} 或显式编码（UTF-8 / GBK / GB18030 等）。}
  \item{sep}{分隔符；\code{NULL} 时按内容嗅探。}
  \item{skip}{跳过开头行数。}
  \item{mapping}{列名映射，如 \code{list(date = "日期", region = "省份", count = "发病数")}。}
  \item{label}{可读的数据源名称，默认取文件名。}
}
\value{
\code{epi_source} 类的列表，含 type / path / url / query / con / mapping 等字段。
}
\examples{
src <- ingest_source("csv", "counts.csv",
                     mapping = list(date = "日期", region = "省份", count = "发病数"))
src$type
}
