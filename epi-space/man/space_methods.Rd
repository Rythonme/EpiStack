\name{space_methods}
\alias{space_methods}
\title{方法适用范围}
\usage{
space_methods()
}
\value{
data.frame(method, scope, note)。
}
\description{
一句话列出本层四种方法各自的适用范围。
}
\details{
moran 是全局置换检验，lisa 是逐地区四象限，hotspot 是显著地点分类，
bym2 是 INLA 模板（本包不拟合）。
}
\examples{
space_methods()
}
\seealso{
\code{\link{space_moran}}, \code{\link{space_lisa}},
\code{\link{space_hotspot}}, \code{\link{space_bym2_template}}
}
