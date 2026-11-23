\name{epiIneq-package}
\alias{epiIneq-package}
\title{Health Inequity Measurement for Surveillance Counts}
\description{
EpiStack 的健康不平等层（L4）。基于统一契约做人口加权集中曲线、
集中指数、斜率不平等指数、SES 分组分解与距离衰减可达性。
}
\details{
本层只读契约表，不改列、不回写。核心入口是 \code{\link{ineq_counts}}；
各指标也可单独调用。全部计算在 base R 中完成，\code{Imports} 只有
\code{stats} 与 \code{utils}，不需要 ineq / spdep / sf。
}
\section{Author}{
EpiStack Authors
}
\section{License}{
MIT + file LICENSE
}
