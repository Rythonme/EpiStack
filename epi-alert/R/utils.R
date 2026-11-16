# =============================================================
# epiAlert / utils.R — 内部工具
#
# 设计底线：Imports 只有 stats / utils。基线、分级、汇总全在 base R 里算完，
# 不引 zoo / forecast / surveillance，避免「装不上就整层跑不起来」。
# 周期编号与 epiCore::epi_period() 同口径，换包不换数。
# =============================================================

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a

.epi_stop <- function(...) stop(sprintf(...), call. = FALSE)

.epi_warn <- function(...) warning(sprintf(...), call. = FALSE)

.alert_version <- function() {
  tryCatch(as.character(utils::packageVersion("epiAlert")),
           error = function(e) "0.0.0-dev")
}

# 周期环形回绕：历史同期 ±w 期跨年时用（与 epiCore::epi_wrap_period 一致）
.alert_wrap <- function(w, n) ((w - 1L) %% n) + 1L

# 周期编号：与 epiCore::epi_period() 完全一致。
# 年度数据一律映射到 period = 1，季节窗口失去意义，走 pooled 基线。
.alert_period <- function(date, time_step, n_periods) {
  d <- as.Date(date)
  switch(time_step,
    week = {
      yd <- as.integer(format(d, "%j"))
      pmin(pmax(1L + floor((yd - 1L) / (365.25 / n_periods)), 1L), n_periods)
    },
    month = {
      m <- as.integer(format(d, "%m"))
      if (n_periods == 12L) m
      else pmin(pmax(1L + floor((m - 1L) * n_periods / 12L), 1L), n_periods)
    },
    quarter = ((as.integer(format(d, "%m")) - 1L) %/% 3L) + 1L,
    year = rep(1L, length(d))
  )
}

# 粒度推断：按相邻日期的中位间隔判断。日数据会被当作周，请先自行汇总。
.alert_infer_step <- function(date) {
  d <- sort(unique(as.Date(date)))
  d <- d[!is.na(d)]
  if (length(d) < 2L) return("year")
  gap <- as.numeric(stats::median(diff(d)))
  if (gap <= 10) "week" else if (gap <= 40) "month" else if (gap <= 120) "quarter" else "year"
}

.alert_n_periods <- function(time_step) {
  switch(time_step, week = 52L, month = 12L, quarter = 4L, year = 1L)
}

# 统一入口：接受 data.frame 或 epiCore::read_counts() 的返回值。
# 只做结构与排序准备，不替使用者补数据——缺列直接报出来。
.alert_prepare <- function(x, time_step = NULL, n_periods = NULL) {
  if (inherits(x, "epi_contract")) {
    d <- x$data
    if (is.null(time_step)) time_step <- x$meta$time_step
    if (is.null(n_periods)) n_periods <- x$meta$n_periods
  } else if (is.data.frame(x)) {
    d <- x
  } else {
    .epi_stop("x 必须是契约表 data.frame，或 epiCore::read_counts() 的返回值")
  }
  d <- as.data.frame(d, stringsAsFactors = FALSE)
  miss <- setdiff(c("date", "region", "count"), names(d))
  if (length(miss))
    .epi_stop("缺少必要列：%s（先用 epiCore::read_counts() 把原始表转成契约）",
              paste(miss, collapse = ", "))
  d$date <- tryCatch(as.Date(d$date), error = function(e) rep(as.Date(NA), nrow(d)))
  d$count <- suppressWarnings(as.numeric(d$count))
  if (all(is.na(d$date)))
    .epi_stop("date 列无法解析为日期")
  if (any(is.na(d$date)) || any(is.na(d$region)))
    .epi_stop("date / region 存在缺失，请先用 epiCore::read_counts() 过质控")
  if (any(is.na(d$count)))
    .epi_stop("count 存在缺失或非数值，请先用 epiCore::read_counts() 过质控")

  if (is.null(time_step) || identical(time_step, "auto"))
    time_step <- .alert_infer_step(d$date)
  if (!time_step %in% c("week", "month", "quarter", "year"))
    .epi_stop("time_step 只支持 week / month / quarter / year")
  n_periods <- as.integer(n_periods %||% .alert_n_periods(time_step))

  d$cycle <- as.integer(format(d$date, "%Y"))
  d$period <- if (identical(time_step, "year")) rep(1L, nrow(d))
              else .alert_period(d$date, time_step, n_periods)
  d <- d[order(d$region, d$date), , drop = FALSE]
  rownames(d) <- NULL

  list(data = d, time_step = time_step, n_periods = n_periods)
}

# 评估范围：all（每一期都回溯评估）/ latest（只评最新周期）/ 年份向量
.alert_targets <- function(d, assess) {
  if (is.null(assess) || identical(assess, "all")) return(seq_len(nrow(d)))
  if (identical(assess, "latest")) {
    cy <- max(d$cycle, na.rm = TRUE)
    return(which(d$cycle == cy))
  }
  if (is.numeric(assess)) {
    idx <- which(d$cycle %in% as.integer(assess))
    if (!length(idx)) .epi_stop("assess 指定的年份在数据里不存在：%s",
                                paste(assess, collapse = ", "))
    return(idx)
  }
  .epi_stop("assess 只支持 \"all\"、\"latest\" 或年份向量")
}
