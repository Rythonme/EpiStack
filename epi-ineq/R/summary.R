# =============================================================
# epiIneq / summary.R — 关键指标汇总
# =============================================================

#' 关键指标汇总
#'
#' @param x epi_counts 结果，或含 core 的 list
#' @return data.frame(metric, value, note)
ineq_summary <- function(x) {
  if (is.data.frame(x) && all(c("metric", "value") %in% names(x))) return(x)
  core <- if (inherits(x, "epi_ineq")) x$core else x$core
  if (is.null(core)) .epi_stop("需要 ineq_counts() 的返回值")
  rows <- list(
    list(metric = "集中指数 CI", value = core$CI,
         note = "负值 = 负担集中于低 SES 地区"),
    list(metric = "斜率不平等指数 SII", value = core$SII,
         note = "加权回归斜率，每十万人的率差；负值同向"),
    list(metric = "低/高 SES 率比", value = core$rate_ratio,
         note = "低 SES 组率 ÷ 高 SES 组率，>1 表示弱势负担更重"),
    list(metric = "Gini 系数", value = core$gini,
         note = "按率排序的不平等，不区分 SES 梯度"),
    list(metric = "可避免分值 PAF", value = core$paf,
         note = "所有组降到最低负担组率时可避免的病例比例"),
    list(metric = "组间 CI / 总 CI", value = core$between_share,
         note = "分解中组间部分占比"),
    list(metric = "可达性低/高比", value = core$access_ratio,
         note = "人口加权可达性，低 SES 组 ÷ 高 SES 组")
  )
  out <- data.frame(
    metric = vapply(rows, function(z) z$metric, character(1)),
    value = vapply(rows, function(z) as.numeric(z$value %||% NA_real_), numeric(1)),
    note = vapply(rows, function(z) z$note, character(1)),
    stringsAsFactors = FALSE
  )
  out[!is.na(out$value), , drop = FALSE]
}
