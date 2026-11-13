\name{ingest_desensitize}
\alias{ingest_desensitize}
\title{对已读取的数据做脱敏}
\description{
把可识别的地区编码换成不可逆假名，再交给外部合作者或上传。
做法是加盐 SHA-256 取前 10 位十六进制：同一盐加同一编码永远得到同一假名，
所以纵向合并与面板匹配不受影响；没有盐就无法反查。
日期只支持整体平移（所有地区同样天数），避免破坏同期可比性。
}
\usage{
ingest_desensitize(x, salt, region = TRUE, date_shift_days = 0L,
                   drop = NULL, key_file = NULL)
}
\arguments{
  \item{x}{\code{epi_ingest} 对象或可直接读取的数据源。}
  \item{salt}{盐值，必须由使用者提供，建议存在本地私有配置里，不要入库。}
  \item{region}{是否把地区编码替换为假名。}
  \item{date_shift_days}{整体日期平移天数，0 表示不平移。}
  \item{drop}{需要从原始列中删除的字段名。}
  \item{key_file}{若非 \code{NULL}，把「原编码 → 假名」对照表写到该路径；
    这是再识别密钥，务必私有保存并加入 \code{.gitignore}。}
}
\value{脱敏后的 \code{epi_ingest} 对象，\code{$meta$desensitized} 记录算法与盐的哈希。}
\examples{
d <- data.frame(date = c("2021-01-01", "2021-02-01"), region = c("D01", "D02"),
                count = c(10, 12), population = 1e5)
if (requireNamespace("openssl", quietly = TRUE) ||
    requireNamespace("digest", quietly = TRUE)) {
  out <- ingest_desensitize(ingest_read(d), salt = "local-secret")
  out$data$region
}
}
