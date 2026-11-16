# =============================================================
# epiAlert / scan.R — 超限判定与分级
#
# 判定只有一步：本期计数是否超过同期基线的单侧上界。
# 分级把「连续几期」和「超出多少倍」两条线并起来看：
# 单期跳高多半是报告波动，连着几期都高才是信得过的问题。
# 年度数据没有「连续期」的概念（一期就是一年），只按超出倍数分级。
# =============================================================

#' 扫描异常信号并分级
#'
#' @inheritParams alert_baseline
#' @param rules 分级规则，见 `alert_rules()`
#' @return 列表，含：
#'   `band`（基线带）、`current`（逐期判定明细）、`alerts`（非正常行）、
#'   `settings`（生效参数）
alert_scan <- function(x, method = c("auto", "seasonal", "pooled", "moving", "poisson"),
                       window = 1L, k = 1.645, min_obs = 3L, offset = 0.5,
                       assess = "all", rules = alert_default_rules(),
                       time_step = NULL, n_periods = NULL) {
  method <- match.arg(method)
  if (!inherits(rules, "epi_alert_rules"))
    rules <- alert_rules()

  band <- alert_baseline(x, method = method, window = window, k = k,
                         min_obs = min_obs, offset = offset, assess = assess,
                         time_step = time_step, n_periods = n_periods)
  method_used <- unique(band$method)[[1L]]
  prep <- .alert_prepare(x, time_step = time_step, n_periods = n_periods)
  d <- prep$data
  idx <- .alert_targets(d, assess)

  cur <- cbind(
    d[idx, intersect(c("date", "region", "count", "population", "disease",
                       "cycle", "period"), names(d)), drop = FALSE],
    band[, c("baseline", "upper", "n_hist"), drop = FALSE]
  )
  cur$exceed <- !is.na(cur$upper) & cur$count > cur$upper
  # 超出倍数：分母用上界本身，上界为 0 或缺失时记 0（与既往报表口径一致）
  cur$ratio <- ifelse(!is.na(cur$upper) & cur$upper > 0,
                      cur$count / pmax(cur$upper, 1), 0)

  # 连续超限期数：同地区按日期累计，超限段内每期都记该段的长度
  cur$run_len <- 0L
  for (rg in unique(cur$region)) {
    ix <- which(cur$region == rg)
    if (!length(ix)) next
    if (identical(prep$time_step, "year")) {
      cur$run_len[ix] <- as.integer(cur$exceed[ix])   # 年度：一期即一年，不累计
      next
    }
    rr <- rle(cur$exceed[ix])
    lens <- integer(length(ix)); pos <- 1L
    for (j in seq_along(rr$lengths)) {
      if (rr$values[j]) lens[pos:(pos + rr$lengths[j] - 1L)] <- rr$lengths[j]
      pos <- pos + rr$lengths[j]
    }
    cur$run_len[ix] <- lens
  }

  lab <- rules$labels
  cur$level <- lab[1L]
  cur$level[cur$run_len >= rules$watch] <- lab[2L]
  cur$level[cur$run_len >= rules$warn_run | cur$ratio >= rules$warn_ratio] <- lab[3L]
  cur$level[cur$run_len >= rules$alarm_run | cur$ratio >= rules$alarm_ratio] <- lab[4L]

  alerts <- cur[cur$level != lab[1L], , drop = FALSE]
  if (nrow(alerts)) {
    alerts <- alerts[order(match(alerts$level, rev(lab[2:4])), -alerts$count), , drop = FALSE]
  }
  rownames(cur) <- NULL
  rownames(alerts) <- NULL

  structure(
    list(
      band = band, current = cur,
      alerts = alerts[, intersect(c("date", "region", "count", "baseline", "upper",
                                    "ratio", "run_len", "level"), names(alerts)),
                      drop = FALSE],
      settings = list(
        method = method_used, window = as.integer(window), k = as.numeric(k),
        min_obs = as.integer(min_obs), offset = as.numeric(offset),
        assess = assess, time_step = prep$time_step, n_periods = prep$n_periods,
        rules = rules
      )
    ),
    class = "epi_scan"
  )
}

print.epi_scan <- function(x, ...) {
  s <- x$settings
  cat(sprintf("<epi_scan> %s ｜ %s ｜ 评估范围 %s\n",
              s$method, s$time_step,
              if (is.character(s$assess)) s$assess else paste(range(s$assess), collapse = "-")))
  cat(sprintf("  基线 %d 行（有上界 %d 行）｜ 评估 %d 期 ｜ 异常 %d 条\n",
              nrow(x$band), sum(!is.na(x$band$upper)), nrow(x$current), nrow(x$alerts)))
  invisible(x)
}
