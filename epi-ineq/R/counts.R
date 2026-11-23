# =============================================================
# epiIneq / counts.R — 一站式入口
#
# 只做编排：数据准备 → 曲线/CI → SII → Gini → 分解 → 可达性 → 汇总。
# 具体算法都在各自文件里，便于单独调用与核对。
# 无坐标时可达性为 NULL，其余指标照常给出（切片只用到 CI 与率比）。
# =============================================================

#' 一站式健康不平等分析
#'
#' @param x data.frame、契约 list 或 epi_contract 对象
#' @param geo 地区元数据（SES 与坐标）；契约对象会自动取
#' @param year_value 指定年份，默认取最新年
#' @param cut 分组阈值（数值或 "median"），默认 0.5
#' @param groups 分解用的分位数分组数，默认 4
#' @param facilities 设施点 data.frame(name, x, y, capacity)；NULL 自动选
#' @param k,d0,beta 设施数、特征距离、距离衰减指数
#' @param population,value,ses,region 列名
#' @return 类 `epi_ineq` 的 list：curve / ci / sii / gini / decompose /
#'   access / groups / core / summary / tot / meta
ineq_counts <- function(x, geo = NULL, year_value = NULL,
                        cut = 0.5, groups = 4L,
                        facilities = NULL, k = 3L, d0 = NULL, beta = 1,
                        population = "population", value = "count",
                        ses = "ses", region = "region") {
  p <- .ineq_prepare(x, region = region, count = value,
                     population = population, ses = ses, geo = geo)
  rr <- .ineq_regions(p, year_value = year_value)
  tot <- rr$tot

  curve <- .ineq_curve_df(tot$ses, tot$population, tot$count, region = tot$region)
  area <- .ineq_area(c(0, curve$cum_pop), c(0, curve$cum_value))
  CI <- 1 - 2 * area
  curve <- structure(list(curve = curve, CI = CI, area = area,
                          meta = list(year = rr$year, n = nrow(tot))),
                     class = "epi_ineq_curve")

  # tot 已经是标准列名（region/count/population/ses/x/y），后续一律按标准名调用
  sii <- tryCatch(
    ineq_sii(tot, population = "population", value = "count",
             ses = "ses", region = "region"),
    error = function(e) NULL)
  gini <- tryCatch(
    ineq_gini(tot, population = "population", value = "count",
              ses = "ses", region = "region"),
    error = function(e) NA_real_)
  dec <- tryCatch(
    ineq_decompose(tot, cut = cut, groups = groups,
                   population = "population", value = "count",
                   ses = "ses", region = "region"),
    error = function(e) NULL)
  grp <- ineq_groups(tot, cut = cut, population = "population",
                     value = "count", ses = "ses", region = "region")
  pair <- .ineq_two_group(grp)

  access <- NULL
  if (all(is.finite(tot$x)) && all(is.finite(tot$y))) {
    access <- tryCatch(
      ineq_access(tot, facilities = facilities, k = k, d0 = d0, beta = beta,
                  population = "population", value = "count",
                  ses = "ses", region = "region"),
      error = function(e) NULL)
  }

  core <- list(
    CI = CI,
    SII = if (!is.null(sii)) sii$sii else NA_real_,
    rate_ratio = pair$rate_ratio,
    gini = gini,
    paf = if (!is.null(dec)) dec$paf else NA_real_,
    between_share = if (!is.null(dec) && is.finite(dec$total) &&
                        abs(dec$total) > 1e-12) dec$between / dec$total else NA_real_,
    access_ratio = if (!is.null(access)) access$ratio_low_high else NA_real_,
    rate_diff = pair$rate_diff,
    low_group = pair$low_group, high_group = pair$high_group
  )
  res <- list(
    curve = curve, ci = CI, sii = sii, gini = gini, decompose = dec,
    access = access, groups = grp, core = core,
    tot = tot, meta = list(year = rr$year, n = nrow(tot),
                           rate_per = 1e5, cut = cut)
  )
  res$summary <- ineq_summary(res)
  structure(res, class = "epi_ineq")
}
