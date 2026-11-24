# =============================================================
# epiRobust / example.R — 合成示例与方法表
#
# 6×6 虚构格网（36 地区），三年观测，右下角注入一片空间聚集高值。
# 确定性算式，不调用随机数，不改变调用方的随机数状态。
# =============================================================

#' 合成格网示例
#'
#' @param n_side 格网边长，默认 6（36 个虚构地区）
#' @param years 年份向量
#' @param hotspot 注入高值的地区；默认右下角
#' @return 契约列结构的 data.frame：date / region / count / population /
#'   disease / row / col
#' @export
robust_example <- function(n_side = 6L, years = 2022:2024, hotspot = NULL) {
  n_side <- as.integer(n_side)
  if (n_side < 4L) .epi_stop("n_side 至少为 4（MAUP 聚合需要）")
  years <- as.integer(years)
  if (!length(years)) .epi_stop("years 不能为空")
  hotspot <- hotspot %||% sprintf("R%02d", n_side^2L)

  g <- expand.grid(col = seq_len(n_side), row = seq_len(n_side),
                   year = years, stringsAsFactors = FALSE)
  g$region <- sprintf("R%02d", (g$row - 1L) * n_side + g$col)
  hr <- (n_side - 1L) %% n_side + 1L
  dist <- abs(g$row - hr) + abs(g$col - n_side)
  uplift <- ifelse(g$region == hotspot, 2.6, 1 + 0.35 * (n_side - dist))
  season <- 1 + 0.1 * (match(g$year, years) - 1L)
  jitter <- (((seq_len(nrow(g)) * 13L) %% 7L) - 3L) / 60
  g$count <- as.integer(pmax(1L, round(60 * uplift * season * (1 + jitter))))
  g$population <- 1e5
  g$disease <- "DEMO"
  g$date <- as.Date(sprintf("%d-01-01", g$year))
  out <- g[, c("date", "region", "count", "population", "disease", "row", "col")]
  out <- out[order(out$region, out$date), , drop = FALSE]
  rownames(out) <- NULL
  out
}

#' 稳健性体检项目适用范围
#'
#' @return data.frame(check, threat, note)
#' @export
robust_methods <- function() {
  data.frame(
    check = c("maup", "weights", "conley", "multiplicity"),
    threat = c("尺度与分区", "邻接定义", "空间依赖的推断", "局部检验多重比较"),
    note = c(
      "多种聚合尺度下重算 Moran / 热点，报告结论区间与符号翻转",
      "rook / queen / kNN 权重下重算全局统计量，看结论是否随邻接翻转",
      "多个距离截断的 Conley HAC 标准误，与朴素 SE 对照",
      "LISA 置换 p 的 Bonferroni 与 BH-FDR 校正，看热点是否消失"
    ),
    stringsAsFactors = FALSE
  )
}
