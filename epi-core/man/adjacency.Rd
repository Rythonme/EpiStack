\name{adjacency}
\alias{adjacency}
\alias{epi_adjacency}
\alias{epi_read_graph}
\alias{epi_row_standardize}
\alias{epi_adjacency_check}
\title{空间邻接权重矩阵}
\description{
从规则格网或真实行政边界导出统一形态的行标准化邻接矩阵：
带地区名 dimnames、邻接结构对称、无孤立节点。
}
\usage{
epi_adjacency(geo, style = c("rook", "queen"), row_standardize = TRUE)

epi_read_graph(path, regions = NULL, row_standardize = TRUE)

epi_row_standardize(W)

epi_adjacency_check(W)
}
\arguments{
  \item{geo}{含 region、row、col 三列的地理编码表。}
  \item{style}{rook（共享边）或 queen（共享边或角）。}
  \item{row_standardize}{是否按行标准化。}
  \item{path}{INLA .graph 邻接表路径（spdep::nb2INLA 输出格式）。}
  \item{regions}{地区编码向量，顺序必须与图中节点号一致。}
  \item{W}{邻接矩阵。}
}
\value{
前三个函数返回 n x n 数值矩阵；\code{epi_adjacency_check()} 返回含
对称性、孤岛、行和范围与密度的体检列表。
}
\examples{
geo <- data.frame(region = paste0("R", 1:4),
                  row = c(1, 1, 2, 2), col = c(1, 2, 1, 2))
W <- epi_adjacency(geo, "rook")
epi_adjacency_check(W)$symmetric
}
