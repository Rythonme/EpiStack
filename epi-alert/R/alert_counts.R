# =============================================================
# epiAlert / alert_counts.R — 一站式入口（推荐用法）
#
# 契约表 → 基线 → 超限 → 分级 → 汇总。
# 与 epiCore::read_counts() 的关系：上游产出契约，本函数只读契约，
# 不回写、不改列，换层不影响上下游。
# =============================================================

#' 从契约表产出预警结果
#'
#' @inheritParams alert_baseline
#' @param rules 分级规则，见 `alert_rules()`
#' @return 列表，类 `epi_alert`：
#'   `band` 基线带、`current` 逐期明细、`alerts` 异常清单、
#'   `summary` 按地区汇总、`settings` 生效参数、`meta` 输入规模与版本
alert_counts <- function(x, method = c("auto", "seasonal", "pooled", "moving", "poisson"),
                         window = 1L, k = 1.645, min_obs = 3L, offset = 0.5,
                         assess = "all", rules = alert_default_rules(),
                         time_step = NULL, n_periods = NULL) {
  method <- match.arg(method)
  sc <- alert_scan(x, method = method, window = window, k = k, min_obs = min_obs,
                   offset = offset, assess = assess, rules = rules,
                   time_step = time_step, n_periods = n_periods)
  structure(
    list(
      band = sc$band, current = sc$current, alerts = sc$alerts,
      summary = .alert_summarise(sc), settings = sc$settings,
      meta = list(
        package = "epiAlert", version = .alert_version(),
        time_step = sc$settings$time_step,
        n_regions = length(unique(sc$current$region)),
        n_targets = nrow(sc$current),
        n_alerts = nrow(sc$alerts),
        n_band_missing = sum(is.na(sc$band$upper))
      )
    ),
    class = "epi_alert"
  )
}

print.epi_alert <- function(x, ...) {
  s <- x$settings
  lab <- s$rules$labels
  cat(sprintf("<epi_alert> %s ｜ 粒度 %s ｜ 方法 %s\n",
              paste0("epiAlert ", x$meta$version), s$time_step, s$method))
  cat(sprintf("  参数：window=%d, k=%.3f, offset=%.1f, min_obs=%d ｜ 评估 %d 期 × %d 地区\n",
              s$window, s$k, s$offset, s$min_obs, x$meta$n_targets, x$meta$n_regions))
  cat(sprintf("  %s %d ｜ %s %d ｜ %s %d ｜ 基线不足 %d 期\n",
              lab[2L], sum(x$current$level == lab[2L]),
              lab[3L], sum(x$current$level == lab[3L]),
              lab[4L], sum(x$current$level == lab[4L]),
              x$meta$n_band_missing))
  invisible(x)
}
