# =============================================================
# epiAlert / example.R — 自带合成示例，示例与测试都不依赖外部数据
#
# 用确定性算式（非随机数）生成四个虚构地区的周报计数：
# 冬季高、夏季低，最后一年最后一个地区注入一段持续升高。
# 不调用 set.seed()，不改变调用方的随机数状态。
# =============================================================

#' 合成周报示例数据
#'
#' 返回列结构同契约（date / region / count / population / disease）的
#' data.frame，四个虚构地区、三年周报，其中最后一个地区在最后一年末段
#' 出现持续升高。用于示例与自检，不含任何真实观测。
#'
#' @param regions 地区名向量
#' @param years 年份向量
#' @param n_periods 每年周数
#' @param outbreak 注入升高的地区（默认取最后一个地区）
#' @return data.frame
alert_example <- function(regions = c("A 区", "B 区", "C 区", "D 区"),
                          years = 2022:2024, n_periods = 52L,
                          outbreak = NULL) {
  regions <- as.character(regions)
  years <- as.integer(years)
  n_periods <- as.integer(n_periods)
  if (!length(regions) || !length(years)) .epi_stop("regions 与 years 不能为空")
  outbreak <- outbreak %||% utils::tail(regions, 1L)

  grid <- expand.grid(period = seq_len(n_periods), year = years,
                      region = regions, stringsAsFactors = FALSE)
  n <- nrow(grid)
  # 季节形态：以年为周期的余弦，冬季（期首尾）高
  season <- 1 + 0.45 * cos(2 * pi * (grid$period - 1) / n_periods)
  # 地区水平差异
  lvl <- c(1, 0.8, 1.2, 0.9, 1.1)[(match(grid$region, regions) - 1L) %% 5L + 1L]
  # 确定性扰动，避免用随机数
  jitter <- (((seq_len(n) * 37L) %% 7L) - 3L) / 20
  count <- round(40 * lvl * season * (1 + jitter))
  count <- pmax(count, 0L)

  # 末段注入：最后一年最后 6 期翻倍，用于验证分级能给出「告警」
  last_year <- max(years)
  ix <- grid$region == outbreak & grid$year == last_year &
    grid$period > (n_periods - 6L)
  count[ix] <- as.integer(round(count[ix] * 2.2)) + 10L

  date <- as.Date(sprintf("%d-01-01", grid$year)) + (grid$period - 1L) * 7L
  out <- data.frame(
    date = date, region = grid$region, count = count,
    population = 1e6, disease = "DEMO", stringsAsFactors = FALSE
  )
  out <- out[order(out$region, out$date), , drop = FALSE]
  rownames(out) <- NULL
  out
}
