\name{space_neighbors}
\alias{space_neighbors}
\title{邻接表}
\usage{
space_neighbors(w)
}
\arguments{
\item{w}{\code{space_weights()} 的结果，或权重矩阵。}
}
\value{
data.frame(region, n_neighbors, neighbors)。
}
\description{
把权重矩阵摊成「每个地区有哪些邻居」的清单。
}
\examples{
d <- space_example()
w <- space_weights(d, "rook")
head(space_neighbors(w))
}
\seealso{
\code{\link{space_weights}}
}
