\name{ingest_qc_default}
\alias{ingest_qc_default}
\title{包内默认质控规则集}
\description{
默认只做「任何监测计数表都该过」的检查：必填、唯一键、非负计数、
日期连续、MAD 异常值。地区白名单与跨字段一致性需要 geo 表或人口列，
传入 \code{geo} 时自动补上白名单。
}
\usage{
ingest_qc_default(geo = NULL, outlier_k = 8)
}
\arguments{
  \item{geo}{地区码表或地区编码向量；提供时加入 region_code 规则。}
  \item{outlier_k}{MAD 阈值倍数，\code{NULL} 表示沿用规则文件里的值。}
}
\value{\code{epi_qc_rules} 类的列表。}
\examples{
r <- ingest_qc_default()
r$required
length(ingest_qc_default(geo = c("D01", "D02"))$region_code$allowed)
}
