# =============================================================
# epiIneq / example.R — 自带合成示例与方法表
#
# 4×4 虚构格网，SES 由左到右递增，率由左到右递减（弱势负担更重）。
# 全部由确定性算式生成，不调用随机数，不改变调用方的随机数状态。
# =============================================================

#' 合成面板示例
#'
#' @param n_side 格网边长，默认 4（16 个虚构地区）
#' @param years 年份向量
#' @return 契约列结构 + ses / x / y 的 data.frame
ineq_example <- function(n_side = 4L, years = 2022:2024) {
  n_side <- as.integer(n_side)
  if (n_side < 3L) .epi_stop("n_side 至少为 3")
  years <- as.integer(years)
  if (!length(years)) .epi_stop("years 不能为空")

  g <- expand.grid(col = seq_len(n_side), row = seq_len(n_side),
                   year = years, stringsAsFactors = FALSE)
  g$region <- sprintf("R%02d", (g$row - 1L) * n_side + g$col)
  jitter <- (((seq_len(nrow(g)) * 13L) %% 5L) - 2L) / 100
  g$ses <- pmin(0.95, pmax(0.05,
    0.12 + 0.72 * (g$col - 1) / (n_side - 1) + jitter))
  g$population <- 5e4 + 1.2e4 * ((g$row + g$col) %% 3)
  g$rate <- 120 * (1.65 - g$ses) * (1 + 0.06 * (match(g$year, years) - 1L))
  g$count <- as.integer(pmax(1L, round(g$population * g$rate / 1e5)))
  g$disease <- "DEMO"
  g$date <- as.Date(sprintf("%d-01-01", g$year))
  g$x <- as.numeric(g$col)
  g$y <- as.numeric(g$row)
  out <- g[, c("date", "region", "count", "population", "disease",
               "ses", "x", "y")]
  out <- out[order(out$region, out$date), , drop = FALSE]
  rownames(out) <- NULL
  out
}

#' 方法适用范围
#'
#' @return data.frame(method, scope, note)
ineq_methods <- function() {
  data.frame(
    method = c("concentration", "sii", "decompose", "access", "gini"),
    scope = c("梯度", "梯度", "分解", "可达性", "分布"),
    note = c(
      "人口加权集中曲线：CI = 1 - 2×曲线下面积，负值表示负担集中于低 SES",
      "SES 人口累积中点位置对率的人口加权回归，斜率为两端的预测率差",
      "把组内率拉平得组间部分，组内曲线按人口×病例份额加权；余量单列",
      "设施点距离衰减 A_i = Σ cap_f/(1+(d_if/d0)^beta)，人口加权汇总",
      "按率排序的集中曲线；不区分这种不均是否沿 SES 梯度"
    ),
    stringsAsFactors = FALSE
  )
}
