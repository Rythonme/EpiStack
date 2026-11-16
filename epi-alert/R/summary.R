# =============================================================
# epiAlert / summary.R — 按地区汇总
#
# 逐期明细是给分析看的，汇总表是给「先看哪里」用的：
# 一个地区的信号条数、最高级别、最大超出倍数、最后一次出现时间。
# =============================================================

.alert_summarise <- function(x) {
  cur <- x$current
  lab <- x$settings$rules$labels
  if (!nrow(cur)) {
    return(data.frame(region = character(0), n_periods = integer(0),
                      n_exceed = integer(0), n_watch = integer(0),
                      n_warn = integer(0), n_alarm = integer(0),
                      peak_level = character(0), max_ratio = numeric(0),
                      last_alert = as.Date(character(0)), stringsAsFactors = FALSE))
  }
  regs <- unique(cur$region)
  rows <- lapply(regs, function(rg) {
    d <- cur[cur$region == rg, , drop = FALSE]
    rk <- match(d$level, lab)
    peak <- lab[max(rk, na.rm = TRUE)]
    hit <- d$level != lab[1L]
    data.frame(
      region = rg,
      n_periods = nrow(d),
      n_exceed = sum(d$exceed, na.rm = TRUE),
      n_watch = sum(d$level == lab[2L]),
      n_warn = sum(d$level == lab[3L]),
      n_alarm = sum(d$level == lab[4L]),
      peak_level = peak,
      max_ratio = if (any(is.finite(d$ratio))) max(d$ratio, na.rm = TRUE) else NA_real_,
      last_alert = if (any(hit)) max(d$date[hit]) else as.Date(NA),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out <- out[order(match(out$peak_level, rev(lab)), -out$n_alarm, -out$max_ratio), , drop = FALSE]
  rownames(out) <- NULL
  out
}

#' 按地区汇总异常信号
#'
#' @param x `alert_counts()` 或 `alert_scan()` 的结果
#' @return data.frame，每个地区一行：评估期数、超限期数、各级条数、
#'   最高级别、最大超出倍数、最后一次出现信号的日期
alert_summary <- function(x) {
  if (!inherits(x, c("epi_alert", "epi_scan")))
    .epi_stop("x 必须是 alert_counts() 或 alert_scan() 的结果")
  .alert_summarise(x)
}
