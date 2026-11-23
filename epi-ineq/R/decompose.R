# =============================================================
# epiIneq / decompose.R — 集中指数的组间/组内分解与组间率差
#
# 分解采用常用的两块近似：把组内率拉平到组均值后重算整体 CI 作为
# 「组间」部分；组内曲线 CI 按 w_g = 人口份额×病例份额 加权求和作为
# 「组内」部分；余量单列，不硬塞进某一块。离散分组时余量通常很小。
# 组间率差/率比/可避免分值另用 SES < 0.5 的两组口径给出。
# =============================================================

#' SES 分组分解
#'
#' @param x data.frame、契约 list 或 epi_contract 对象
#' @param groups 分位数分组数，默认 4
#' @param cut 若给定则按该阈值分两组（与 groups 互斥）
#' @param population,value,ses,region 列名
#' @param geo 地区元数据；year_value 指定年份
#' @return list(groups, total, between, within, residual, rate_diff,
#'   rate_ratio, paf, weights)
ineq_decompose <- function(x, groups = 4L, cut = NULL,
                           population = "population", value = "count",
                           ses = "ses", region = "region", geo = NULL,
                           year_value = NULL) {
  p <- .ineq_prepare(x, region = region, count = value,
                     population = population, ses = ses, geo = geo)
  tot <- .ineq_regions(p, year_value = year_value)$tot
  if (nrow(tot) < 4L)
    .epi_stop("分解至少需要 4 个地区，当前只有 %d 个", nrow(tot))

  args <- list(x = tot, population = population, value = value,
               ses = ses, region = region)
  if (is.null(cut)) args$groups <- groups else args$cut <- cut
  g <- do.call(ineq_groups, args)
  members <- attr(g, "members")
  if (is.null(members)) members <- rep(g$group[1L], nrow(tot))

  total <- ineq_ci(tot, population = population, value = value,
                   ses = ses, region = region)
  # 组间：把每个地区的率替换为所在组的平均率，再算一次整体 CI
  flat <- tot
  flat$count <- tot$population * g$rate[match(members, g$group)]
  between <- ineq_ci(flat, population = population, value = value,
                     ses = ses, region = region)

  within <- 0
  wrow <- numeric(nrow(g))
  for (j in seq_len(nrow(g))) {
    idx <- which(members == g$group[j])
    if (length(idx) < 2L) next
    ci_g <- ineq_ci(tot[idx, , drop = FALSE], population = population,
                    value = value, ses = ses, region = region)
    w <- g$pop_share[j] * g$count_share[j]
    wrow[j] <- w
    within <- within + w * ci_g
  }
  residual <- total - between - within

  two <- ineq_groups(tot, cut = 0.5, population = population,
                     value = value, ses = ses, region = region)
  pair <- .ineq_two_group(two)
  list(
    groups = g,
    total = total, between = between, within = within,
    residual = residual,
    rate_diff = pair$rate_diff, rate_ratio = pair$rate_ratio,
    paf = pair$paf,
    low_group = pair$low_group, high_group = pair$high_group,
    weights = wrow,
    meta = list(n = nrow(tot), year = year_value,
                n_groups = nrow(g), per = 1e5)
  )
}
