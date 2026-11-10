# =============================================================
# epiCore / period.R — 时间粒度与季节周期映射
# 同一份契约可以承载周报、月报、年报：只改 time_step，不改上下游接口。
# =============================================================

#' 把日期映射到季节周期序号（1..n_periods）
#'
#' week  : 按 day-of-year 均分 n_periods（默认 52）
#' month : 自然月 1..12
#' quarter: 自然季度 1..4
#' year  : 返回年序号（1 = 最早年份），用于年际趋势，不代表季节周期
epi_period <- function(date, n_periods = 52L,
                       time_step = c("week", "month", "quarter", "year"),
                       origin = NULL) {
  d <- tryCatch(as.Date(date), error = function(e) rep(as.Date(NA), length(date)))
  time_step <- match.arg(time_step)
  n_periods <- as.integer(n_periods)
  if (is.na(n_periods) || n_periods < 1L) stop("n_periods 必须为正整数", call. = FALSE)

  switch(time_step,
    week = {
      yd <- as.integer(format(d, "%j"))
      pmin(pmax(1L + floor((yd - 1L) / (365.25 / n_periods)), 1L), n_periods)
    },
    month = {
      m <- as.integer(format(d, "%m"))
      if (n_periods == 12L) m else pmin(pmax(1L + floor((m - 1L) * n_periods / 12L), 1L), n_periods)
    },
    quarter = ((as.integer(format(d, "%m")) - 1L) %/% 3L) + 1L,
    year = {
      y <- as.integer(format(d, "%Y"))
      base <- if (is.null(origin)) min(y, na.rm = TRUE) else as.integer(origin)
      y - base + 1L
    }
  )
}

#' 周期环形回绕（历史同期 ±1 期跨年时用到）
epi_wrap_period <- function(w, n_periods) ((w - 1L) %% n_periods) + 1L

#' 周期序号的可读标签
epi_period_label <- function(p, time_step = "month") {
  switch(time_step,
    week    = sprintf("W%02d", p),
    month   = sprintf("%d月", p),
    quarter = sprintf("Q%d", p),
    year    = sprintf("Y%02d", p),
    as.character(p))
}
