# =============================================================
# epiAlert / baseline.R — 基线带
#
# 一条硬规则：评估第 t 期时，只用 t 之前的数据建基线。
# 不这样的话，回溯评估里每个点都在给自己的基线投票，异常会被自己拉平，
# 越远的历史越「看起来正常」——那是自欺。
#
# 四种方法，差别只在「取哪些历史」和「怎么定上界」：
#   seasonal  同地区同周期 ±window 期，log(count+offset) 尺度 mu + k·sd
#   pooled    该地区全部历史，同上
#   moving    最近 window 期，算术均值 + k·sd
#   poisson   同季节窗口，λ = 历史均数，取单侧泊松上分位
# 默认方法按粒度自动选：周/月/季走 seasonal，年走 pooled。
# =============================================================

#' 计算逐期基线带
#'
#' 对每个评估目标（默认数据里的每一期）计算基线与单侧上界。历史只取评估期
#' 之前的观测，因此回溯评估不存在「自己给自己做基线」的问题。
#'
#' @param x 契约表（data.frame，含 date / region / count），或
#'   `epiCore::read_counts()` 的返回值
#' @param method 基线方法：auto（按粒度自动选）/ seasonal / pooled / moving / poisson
#' @param window seasonal 取同期前后各几期，moving 取最近几期
#' @param k 单侧上界系数，默认 1.645（约 95% 单侧）；poisson 下按正态分位换算
#' @param min_obs 最少历史观测数，不足则该期不给基线
#' @param offset 对数变换的连续性校正，默认 0.5
#' @param assess 评估范围：all（每一期）/ latest（最新周期）/ 年份向量
#' @param time_step 时间粒度，NULL 时按日期间隔推断
#' @param n_periods 每年周期数，NULL 时按粒度取 52 / 12 / 4 / 1
#' @return data.frame，每行对应一个评估目标：
#'   region、period、cycle、date、baseline、upper、n_hist、method
alert_baseline <- function(x, method = c("auto", "seasonal", "pooled", "moving", "poisson"),
                           window = 1L, k = 1.645, min_obs = 3L, offset = 0.5,
                           assess = "all", time_step = NULL, n_periods = NULL) {
  method <- match.arg(method)
  window <- as.integer(window)
  min_obs <- as.integer(min_obs)
  if (is.na(window) || window < 1L) .epi_stop("window 至少为 1")
  if (is.na(min_obs) || min_obs < 2L) .epi_stop("min_obs 至少为 2：一个点算不出离散度")
  if (!is.finite(k) || k <= 0) .epi_stop("k 必须是正数")
  if (!is.finite(offset) || offset < 0) .epi_stop("offset 不能为负")

  prep <- .alert_prepare(x, time_step = time_step, n_periods = n_periods)
  d <- prep$data
  if (identical(method, "auto"))
    method <- if (identical(prep$time_step, "year")) "pooled" else "seasonal"

  idx <- .alert_targets(d, assess)
  by_region <- split(seq_len(nrow(d)), d$region)

  out <- data.frame(
    region = d$region[idx], period = d$period[idx], cycle = d$cycle[idx],
    date = d$date[idx], baseline = NA_real_, upper = NA_real_,
    n_hist = 0L, method = method, stringsAsFactors = FALSE
  )

  for (j in seq_along(idx)) {
    i <- idx[j]
    rows <- by_region[[d$region[i]]]
    if (identical(method, "moving")) {
      # 滑动均值是时间序列口径：取紧邻评估期之前最近 window 期
      hist_rows <- utils::tail(rows[rows < i], window)
      z <- d$count[hist_rows]
      if (length(z) < min_obs) next
      mu <- mean(z); sd <- stats::sd(z)
      if (!is.finite(sd)) next
      out$baseline[j] <- mu
      out$upper[j] <- mu + k * sd
      out$n_hist[j] <- length(z)
      next
    }

    # 季节 / 合并 / 泊松都是「跨年同期」口径：只用更早年份的数据。
    # 同一年内的前几期不进基线，否则本期暴发会污染相邻期的上界，
    # 回溯评估越评越平——这正是 surveillance 里最常见的自欺。
    hist_rows <- rows[d$cycle[rows] < d$cycle[i]]
    if (!length(hist_rows)) next
    if (!identical(method, "pooled")) {
      keep <- d$period[hist_rows] %in%
        .alert_wrap((d$period[i] - window):(d$period[i] + window), prep$n_periods)
      hist_rows <- hist_rows[keep]
    }
    z <- d$count[hist_rows]
    if (length(z) < min_obs) next
    out$n_hist[j] <- length(z)

    if (identical(method, "poisson")) {
      lambda <- mean(z)
      out$baseline[j] <- lambda
      out$upper[j] <- stats::qpois(stats::pnorm(k), lambda)
      next
    }

    lz <- log(z + offset)
    mu <- mean(lz); sd <- stats::sd(lz)
    if (!is.finite(sd)) next
    out$baseline[j] <- exp(mu) - offset
    out$upper[j] <- exp(mu + k * sd) - offset
  }

  if (all(is.na(out$upper)))
    .epi_warn("没有一期凑够 %d 个历史观测，基线全部为空：检查窗口设置或缩短 min_obs", min_obs)
  out
}
