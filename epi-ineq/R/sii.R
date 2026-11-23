# =============================================================
# epiIneq / sii.R — 斜率不平等指数（SII）
#
# WHO 推荐的 SII：把每个地区按 SES 排序后的「人口累积中点位置」作为
# 自变量，把率作为因变量做人口加权线性回归，斜率即最弱势端到最优势端
# 的预测率差。对疾病负担而言斜率为负表示弱势地区负担更重。
# =============================================================

#' 斜率不平等指数
#'
#' @param x data.frame、契约 list 或 epi_contract 对象
#' @param population,value,ses,region 列名
#' @param per 率的展示倍数，默认 1e5（每十万人）
#' @param geo 地区元数据；year_value 指定年份
#' @return list(sii, se, p_value, r_squared, intercept, n, per)
ineq_sii <- function(x, population = "population", value = "count",
                     ses = "ses", region = "region", per = 1e5,
                     geo = NULL, year_value = NULL) {
  p <- .ineq_prepare(x, region = region, count = value,
                     population = population, ses = ses, geo = geo)
  tot <- .ineq_regions(p, year_value = year_value)$tot
  if (nrow(tot) < 3L)
    .epi_stop("SII 至少需要 3 个地区，当前只有 %d 个", nrow(tot))

  o <- order(tot$ses)
  pp <- tot$population[o]
  rate <- tot$count[o] / pp * per
  # r 为人口累积中点份额，范围 (0,1)；最弱势 ≈ 0，最优势 ≈ 1
  r <- (cumsum(pp) - pp / 2) / sum(pp)
  fit <- stats::lm(rate ~ r, weights = pp)
  co <- stats::coef(fit)
  if (length(co) < 2L || is.na(co[2L]))
    .epi_stop("无法估计 SII：SES 或率可能为常数")
  se <- tryCatch(sqrt(diag(stats::vcov(fit))[2L]), error = function(e) NA_real_)
  tval <- if (is.finite(se) && se > 0) co[2L] / se else NA_real_
  df <- stats::df.residual(fit)
  pv <- if (is.finite(tval) && df > 0) 2 * stats::pt(-abs(tval), df) else NA_real_
  list(
    sii = unname(co[2L]), se = unname(se), p_value = unname(pv),
    r_squared = unname(summary(fit)$r.squared),
    intercept = unname(co[1L]), n = nrow(tot), per = per,
    direction = if (co[2L] < 0) "负担集中于低 SES" else "负担集中于高 SES"
  )
}
