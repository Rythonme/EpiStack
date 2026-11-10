\name{read_counts}
\alias{read_counts}
\alias{epi_contract-class}
\title{读取监测计数并生成统一契约对象}
\description{
L0 与 L1 的主入口：把 CSV 路径或 data.frame 转成 \code{epi_contract} 对象，
内含规范长表、地理码表、邻接权重矩阵、质控报告与元数据。
支持中英文列名别名、UTF-8 BOM、YYYY / YYYY-MM / YYYY-MM-DD 日期，
以及 week / month / quarter / year 四种时间粒度（auto 可自动推断）。
}
\usage{
read_counts(x, geo = NULL, mapping = NULL, disease = "HFRS",
            time_step = c("auto", "week", "month", "quarter", "year"),
            n_periods = NULL, graph = NULL,
            adj_style = c("rook", "queen"), aliases = NULL, qc = TRUE,
            fileEncoding = "UTF-8", strict = TRUE, source_label = NULL)
}
\arguments{
  \item{x}{CSV 文件路径或 data.frame（原始文件只读，绝不回写）。}
  \item{geo}{地理编码表，至少含 region；可带 population / pop、ses、row、col。}
  \item{mapping}{命名列表，显式指定 date / region / count / population / disease
    对应的原始列名；未指定时按内置中英文别名自动匹配。}
  \item{disease}{原始表无病种列时使用的病种代码。}
  \item{time_step}{时间粒度；auto 按日期间隔推断。}
  \item{n_periods}{周期内期数；NULL 时按粒度给默认值。}
  \item{graph}{INLA .graph 邻接表路径；提供时优先于格网邻接。}
  \item{adj_style}{格网邻接风格：rook 或 queen。}
  \item{aliases}{地区别名映射，传给 \code{normalize_region()}。}
  \item{qc}{是否启用质控。}
  \item{fileEncoding}{CSV 文件编码。}
  \item{strict}{是否对结果执行严格契约校验。}
  \item{source_label}{写入元数据的可读数据源说明。}
}
\value{
\code{epi_contract} 类的列表：data（规范长表，含 year / period）、geo、W、qc、meta。
}
\examples{
d <- data.frame(
  date = as.character(as.Date("2021-01-04") + 0:3),
  region = rep("A", 4), count = c(2, 3, 4, 5),
  population = rep(1e5, 4), disease = rep("HFRS", 4))
core <- read_counts(d, time_step = "week")
core$meta$time_step
}
