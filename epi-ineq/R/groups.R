# =============================================================
# epiIneq / groups.R — 按 SES 分组与组间率差、率比
#
# cut = 0.5 是切片沿用的口径：SES 低于 0.5 与不低于 0.5 两组。
# cut = "median" 用地区 SES 中位数分组（面板演示的口径）。
# groups = n 则按 SES 分位数切成 n 组，用于分解表。
# =============================================================

#' 按 SES 分组
#'
#' @param x data.frame、契约 list 或 epi_contract 对象
#' @param cut 数值阈值，或 "median"；与 groups 二选一
#' @param groups 按 SES 分位数切成的组数（如 4）
#' @param population,value,ses,region 列名
#' @param geo 地区元数据；year_value 指定年份
#' @return data.frame(group, n, population, count, rate, rate_per_100k,
#'   pop_share, count_share)
ineq_groups <- function(x, cut = 0.5, groups = NULL,
                        population = "population", value = "count",
                        ses = "ses", region = "region", geo = NULL,
                        year_value = NULL) {
  if (!is.null(groups) && !is.null(cut) && !identical(cut, 0.5))
    .epi_stop("cut 与 groups 只能指定一个")
  p <- .ineq_prepare(x, region = region, count = value,
                     population = population, ses = ses, geo = geo)
  tot <- .ineq_regions(p, year_value = year_value)$tot

  if (!is.null(groups)) {
    groups <- as.integer(groups)
    if (groups < 2L || groups > 10L)
      .epi_stop("groups 必须在 2–10 之间")
    q <- stats::quantile(tot$ses, probs = seq(0, 1, length.out = groups + 1L),
                         names = FALSE, type = 7L)
    grp <- cut(tot$ses, breaks = q, labels = FALSE, include.lowest = TRUE)
    grp <- pmin(pmax(grp, 1L), groups)
    lab <- sprintf("Q%d", grp)
  } else {
    thr <- if (is.character(cut) && identical(cut, "median")) {
      stats::median(tot$ses, na.rm = TRUE)
    } else {
      cut <- suppressWarnings(as.numeric(cut))
      if (length(cut) != 1L || !is.finite(cut))
        .epi_stop("cut 必须是数值或 \"median\"")
      cut
    }
    lab <- ifelse(tot$ses < thr, "低 SES", "高 SES")
  }

  key <- data.frame(group = lab, population = tot$population,
                    count = tot$count, stringsAsFactors = FALSE)
  out <- stats::aggregate(cbind(population, count) ~ group, data = key,
                          FUN = sum)
  if (!is.null(groups)) out <- out[order(out$group), , drop = FALSE]
  rownames(out) <- NULL
  out$n <- as.integer(table(factor(key$group, levels = out$group)))
  out$rate <- out$count / out$population
  out$rate_per_100k <- out$rate * 1e5
  out$pop_share <- out$population / sum(out$population)
  out$count_share <- out$count / sum(out$count)
  out <- out[, c("group", "n", "population", "count", "rate", "rate_per_100k",
                 "pop_share", "count_share")]
  # 逐地区标签（按 tot 行顺序），供分解使用
  attr(out, "members") <- lab
  out
}

# 低/高两组的率差、率比与可避免分值
.ineq_two_group <- function(g) {
  if (nrow(g) != 2L)
    .epi_stop("率差与率比需要恰好两组（用 cut 或 groups = 2）")
  lo <- g[g$rate == min(g$rate), , drop = FALSE][1L, ]
  hi <- g[g$rate == max(g$rate), , drop = FALSE][1L, ]
  overall <- sum(g$count) / sum(g$population)
  list(
    rate_diff = hi$rate - lo$rate,
    rate_ratio = if (lo$rate > 0) hi$rate / lo$rate else NA_real_,
    # 疾病负担：若所有组的率都降到最低率，可避免的病例比例
    paf = 1 - lo$rate / overall,
    low_group = lo$group, high_group = hi$group,
    low_rate = lo$rate, high_rate = hi$rate
  )
}
