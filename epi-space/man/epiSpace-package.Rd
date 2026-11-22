\name{epiSpace-package}
\alias{epiSpace-package}
\alias{epiSpace}
\docType{package}
\title{空间自相关与热点识别}
\description{
EpiStack 的 L3 层。输入是 \pkg{epiCore} 产出的契约长表与行标准化邻接权重，
输出全局 Moran's I 置换检验、逐地区 LISA 四象限、显著热点 / 冷点 / 空间离群，
以及可选的单文件分析单。

主要入口 \code{\link{space_counts}()}：权重校验 → 全局 → 局部 → 热点 → 摘要。
只想看全局用 \code{\link{space_moran}()}，只想做地点分类用 \code{\link{space_lisa}()}.
}
\details{
统计量在 base R 里算完，\code{Imports} 只有 \pkg{stats} 与 \pkg{utils}。
BYM2 只生成 INLA 的数据与代码模板（\code{\link{space_bym2_template}()}），
本包不拟合贝叶斯模型，也不要求安装 INLA。

权重必须邻接结构对称、无孤立地区；行标准化后数值可以不对称。
真实行政边界的邻接图可由 \code{epiCore::epi_read_graph()} 读入。
}
\seealso{
\code{\link{space_counts}}, \code{\link{space_weights}},
\code{\link{space_moran}}, \code{\link{space_lisa}},
\code{\link{space_hotspot}}, \code{\link{space_bym2_template}}
}
\keyword{package}
