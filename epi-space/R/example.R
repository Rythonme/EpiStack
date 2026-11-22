# =============================================================
# epiSpace / example.R — 自带合成示例与方法表
#
# 4×4 虚构格网、三年观测，东南角注入一片空间聚集的高值。
# 用确定性算式，不调用随机数，不改变调用方的随机数状态。
# =============================================================

#' 合成格网示例
#'
#' @param n_side 格网边长，默认 4（16 个虚构地区）
#' @param years 年份向量
#' @param hotspot 注入高值的地区（默认取右下角）
#' @return 契约列结构的 data.frame：date / region / count / population / disease，
#'   另带 row / col 供构造格网权重
space_example <- function(n_side = 4L, years = 2022:2024, hotspot = NULL) {
  n_side <- as.integer(n_side)
  if (n_side < 3L) .epi_stop("n_side 至少为 3")
  years <- as.integer(years)
  if (!length(years)) .epi_stop("years 不能为空")
  hotspot <- hotspot %||% sprintf("R%02d", n_side^2L)

  g <- expand.grid(col = seq_len(n_side), row = seq_len(n_side),
                   year = years, stringsAsFactors = FALSE)
  g$region <- sprintf("R%02d", (g$row - 1L) * n_side + g$col)
  # 空间梯度：越靠近注入点越高，制造真正的 HH 聚集
  hr <- (n_side - 1L) %% n_side + 1L
  dist <- abs(g$row - hr) + abs(g$col - n_side)
  uplift <- ifelse(g$region == hotspot, 2.4, 1 + 0.35 * (n_side - dist))
  season <- 1 + 0.1 * (match(g$year, years) - 1L)
  jitter <- (((seq_len(nrow(g)) * 17L) %% 5L) - 2L) / 40
  g$count <- as.integer(pmax(1L, round(50 * uplift * season * (1 + jitter))))
  g$population <- 1e5
  g$disease <- "DEMO"
  g$date <- as.Date(sprintf("%d-01-01", g$year))
  out <- g[, c("date", "region", "count", "population", "disease", "row", "col")]
  out <- out[order(out$region, out$date), , drop = FALSE]
  rownames(out) <- NULL
  out
}

#' 方法适用范围
#'
#' @return data.frame(method, scope, note)
space_methods <- function() {
  data.frame(
    method = c("moran", "lisa", "hotspot", "bym2"),
    scope = c("全局", "局部", "地点", "模型"),
    note = c(
      "单指标置换检验；回答「整体有没有聚集」",
      "逐地区四象限 HH / LL / HL / LH；回答「哪里聚集」",
      "LISA 显著 HH 为热点、LL 为冷点；不显著不分类",
      "生成 INLA BYM2 数据与代码模板，本包不拟合"
    ),
    stringsAsFactors = FALSE
  )
}
