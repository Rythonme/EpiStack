# =============================================================
# epiIneq / curve.R — 人口加权集中曲线、集中指数与 Gini
#
# 口径与契约层一致：一个地区一行，count 为期间合计，population 为分母。
# 曲线按 SES 升序；CI = 1 - 2×曲线下面积（梯形法），负值表示负担集中于
# 低 SES 地区。Gini 把排序键换成率本身，回答「分布有多不均」，不看 SES。
# =============================================================

#' 人口加权集中曲线
#'
#' @param x data.frame、契约 list 或 epi_contract 对象
#' @param region,count,population,ses 列名
#' @param year_value 指定年份；默认取最新年
#' @param geo 地区元数据（SES 与坐标可从此补）
#' @return 类 `epi_ineq_curve` 的 list：curve / CI / area / meta
ineq_curve <- function(x, region = "region", count = "count",
                       population = "population", ses = "ses",
                       year_value = NULL, geo = NULL) {
  p <- .ineq_prepare(x, region = region, count = count,
                     population = population, ses = ses, geo = geo)
  rr <- .ineq_regions(p, year_value = year_value)
  tot <- rr$tot
  curve <- .ineq_curve_df(tot$ses, tot$population, tot$count,
                          region = tot$region)
  area <- .ineq_area(c(0, curve$cum_pop), c(0, curve$cum_value))
  CI <- 1 - 2 * area
  structure(list(curve = curve, CI = CI, area = area,
                 meta = list(year = rr$year, n = nrow(tot))),
            class = "epi_ineq_curve")
}

#' 集中指数
#'
#' 接受集中曲线、`ineq_curve()` 的返回值，或一个地区一行的 data.frame。
#' 返回单个数值；CI < 0 表示疾病负担集中在低 SES 一侧。
ineq_ci <- function(x, population = "population", value = "count",
                    ses = "ses", region = "region") {
  if (inherits(x, "epi_ineq_curve")) return(x$CI)
  if (is.data.frame(x) && all(c("cum_pop", "cum_value") %in% names(x))) {
    return(1 - 2 * .ineq_area(c(0, x$cum_pop), c(0, x$cum_value)))
  }
  if (!is.data.frame(x) || !all(c(population, value, ses) %in% names(x)))
    .epi_stop("需要含 %s / %s / %s 的 data.frame，或集中曲线",
              ses, population, value)
  rg <- x[[region]]
  if (is.null(rg)) rg <- seq_len(nrow(x))
  cv <- .ineq_curve_df(x[[ses]], x[[population]], x[[value]], region = rg)
  1 - 2 * .ineq_area(c(0, cv$cum_pop), c(0, cv$cum_value))
}

#' Gini 系数（按率排序，不按 SES）
#'
#' 与 CI 的区别：Gini 看的是「病例集中在少数地区」的程度，
#' 不区分这种集中是否沿社会经济梯度。人口加权，梯形法。
ineq_gini <- function(x, population = "population", value = "count",
                      ses = "ses", region = "region", geo = NULL,
                      year_value = NULL) {
  p <- .ineq_prepare(x, region = region, count = value,
                     population = population, ses = ses, geo = geo)
  tot <- .ineq_regions(p, year_value = year_value)$tot
  cv <- .ineq_curve_df(tot$rate, tot$population, tot$count,
                       region = tot$region)
  1 - 2 * .ineq_area(c(0, cv$cum_pop), c(0, cv$cum_value))
}
