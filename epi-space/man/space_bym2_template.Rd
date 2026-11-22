\name{space_bym2_template}
\alias{space_bym2_template}
\title{生成 BYM2 / INLA 模板}
\usage{
space_bym2_template(x, W = NULL, year_value = NULL,
                    count = "count", population = "population",
                    graph_file = "graph.txt", data_file = "bym2_data.csv")
}
\arguments{
\item{x}{契约表或 \code{epiCore::read_counts()} 的返回值。}

\item{W}{权重矩阵；x 是契约时可省略。}

\item{year_value}{取哪一年，默认最新。}

\item{count, population}{计数与人口列名。}

\item{graph_file}{INLA 邻接图输出路径（仅出现在生成的代码里）。}

\item{data_file}{模型数据 CSV 输出路径（仅出现在生成的代码里）。}
}
\value{
列表：\code{data}、\code{graph_code}、\code{code}、\code{checklist} 与说明。
}
\description{
产出 BYM2 需要的数据清单、邻接图代码与 INLA 模型代码，不实际拟合。
}
\details{
INLA 列为 Suggests：不装 INLA 也能生成模板；实际拟合在装好 INLA 的环境执行。
本函数不写任何外部文件，路径只写进返回的代码字符串里。

模板用人口作 offset，空间结构项用 \code{model = "bym2"}；先验参数需按
学科与样本量自行校准。
}
\examples{
d <- space_example()
W <- space_weights(d, "rook")
tpl <- space_bym2_template(d, W = W)
head(tpl$data)
cat(tpl$code)
}
\seealso{
\code{\link{space_counts}}, \code{\link{space_weights}}
}
