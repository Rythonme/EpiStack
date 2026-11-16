\name{epiAlert-package}
\alias{epiAlert-package}
\alias{epiAlert}
\docType{package}
\title{预警分级：季节性基线与异常信号}
\description{
EpiStack 的 L2 层。输入是 \pkg{epiCore} 产出的契约长表
（\code{date / region / count / population / disease}），输出是逐期基线、
单侧上界、连续超限期数与四级信号。

主要入口 \code{\link{alert_counts}()}：基线 → 超限 → 分级 → 汇总一次算完。
只想看基线用 \code{\link{alert_baseline}()}，只想要逐期判定用
\code{\link{alert_scan}()}。
}
\details{
基线只用评估期之前的历史计算：季节窗口取同地区同周期前后各 \code{window} 期，
且只取更早年份，因此回溯评估时本期不会给自己投票。

分级规则是数据：\code{\link{alert_rules}()} 构造，
\code{\link{alert_rules_write}()} 存成 JSON 随项目版本管理，换口径改文件即可。

依赖只有 \pkg{stats} 与 \pkg{utils}，不装任何建模包也能跑完。
}
\seealso{
\code{\link{alert_counts}}, \code{\link{alert_baseline}},
\code{\link{alert_scan}}, \code{\link{alert_rules}}, \code{\link{alert_methods}}
}
\keyword{package}
