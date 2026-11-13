\name{ingest_counts}
\alias{ingest_counts}
\title{从任意数据源产出统一契约}
\description{
一站式入口：读取 → 规则化质控 → 调用 \code{epiCore::read_counts()} 生成
\code{epi_contract}。本函数不复制任何契约逻辑，只调用一次 \code{read_counts()}，
因此与直接用 \code{read_counts()} 的数值结果必然一致；本层新增的行为只有
「按规则剔除行」，剔除行数写入 \code{$ingest$n_dropped}。
}
\usage{
ingest_counts(x, rules = NULL, geo = NULL,
              time_step = c("auto", "week", "month", "quarter", "year"),
              n_periods = NULL, graph = NULL,
              adj_style = c("rook", "queen"),
              disease = "HFRS", mapping = NULL,
              qc = TRUE, strict = TRUE, on_warn = NULL)
}
\arguments{
  \item{x}{\code{epi_source} 对象、文件路径或 data.frame。}
  \item{rules}{\code{\link{qc_rules}} 的返回值或规则文件路径；
    \code{NULL} 表示不做规则质控（等价于直接调用 \code{read_counts}）。}
  \item{geo}{地区码表，至少含 region；可带 population / ses / row / col。}
  \item{time_step}{时间粒度，\code{"auto"} 按日期间隔推断。}
  \item{n_periods}{周期内期数；\code{NULL} 时按粒度给默认值。}
  \item{graph}{INLA \code{.graph} 邻接表路径；提供时优先于格网邻接。}
  \item{adj_style}{格网邻接风格：rook 或 queen。}
  \item{disease}{原始表无病种列时使用的病种代码。}
  \item{mapping}{列名映射；未指定时按中英文别名自动匹配。}
  \item{qc}{是否启用 \pkg{epiCore} 的兜底质控。}
  \item{strict}{是否执行严格契约校验。}
  \item{on_warn}{warn 级命中的处理方式；\code{NULL} 表示用全局设置。}
}
\value{
\code{epi_contract} 对象，额外带 \code{$ingest} 记录来源、规则、逐行留痕与行数变化。
}
\examples{
\dontrun{
geo <- data.frame(region = c("D01", "D02"), population = c(1e5, 1.2e5))
core <- ingest_counts("counts.csv", rules = ingest_qc_default(geo),
                      geo = geo, time_step = "month")
core$ingest$n_dropped
}
}
