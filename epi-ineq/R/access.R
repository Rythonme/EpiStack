# =============================================================
# epiIneq / access.R — 距离衰减可达性
#
# 两步法：先按人口选 k 个地区作设施点（也可显式给定 facilities），
# 再用 A_i = Σ_f cap_f / (1 + (d_if / d0)^beta) 算每个地区的可达性，
# 最后按人口加权汇总，并比较 SES 低/高两组。距离用坐标的欧氏距离，
# 坐标单位由调用方决定（格网步数、公里均可）。
# =============================================================

#' 距离衰减可达性
#'
#' @param x data.frame、契约 list 或 epi_contract 对象（地区需带坐标）
#' @param facilities data.frame(name, x, y, capacity)；NULL 表示自动选
#' @param k 自动选取的设施点数（按人口降序）
#' @param d0 特征距离；NULL 取所有地区-设施距离的中位数
#' @param beta 距离衰减指数，默认 1
#' @param population,value,ses,region 列名
#' @param geo 地区元数据（可从中补坐标）；year_value 指定年份
#' @return list(regions, facilities, overall, ratio_low_high, d0, beta, meta)
ineq_access <- function(x, facilities = NULL, k = 3L, d0 = NULL, beta = 1,
                        population = "population", value = "count",
                        ses = "ses", region = "region", geo = NULL,
                        year_value = NULL) {
  p <- .ineq_prepare(x, region = region, count = value,
                     population = population, ses = ses, geo = geo)
  tot <- .ineq_regions(p, year_value = year_value)$tot
  if (any(!is.finite(tot$x)) || any(!is.finite(tot$y)))
    .epi_stop("可达性需要每个地区有坐标（x/y、row/col 或 lon/lat）")

  beta <- suppressWarnings(as.numeric(beta))
  if (length(beta) != 1L || !is.finite(beta) || beta <= 0)
    .epi_stop("beta 必须为正数")

  if (is.null(facilities)) {
    k <- as.integer(k)
    if (k < 1L || k > nrow(tot)) k <- min(3L, nrow(tot))
    ord <- order(-tot$population)
    sel <- ord[seq_len(k)]
    facilities <- data.frame(
      name = tot$region[sel], x = tot$x[sel], y = tot$y[sel],
      capacity = tot$population[sel] / sum(tot$population[sel]),
      stringsAsFactors = FALSE
    )
  } else {
    facilities <- as.data.frame(facilities, stringsAsFactors = FALSE)
    need <- c("name", "x", "y")
    miss <- setdiff(need, names(facilities))
    if (length(miss)) .epi_stop("facilities 缺少列：%s", paste(miss, collapse = ", "))
    facilities$x <- suppressWarnings(as.numeric(facilities$x))
    facilities$y <- suppressWarnings(as.numeric(facilities$y))
    if (any(!is.finite(facilities$x)) || any(!is.finite(facilities$y)))
      .epi_stop("facilities 的坐标必须为数值")
    if (!"capacity" %in% names(facilities)) facilities$capacity <- 1
    facilities$capacity <- suppressWarnings(as.numeric(facilities$capacity))
    if (any(!is.finite(facilities$capacity)))
      .epi_stop("facilities 的 capacity 必须为数值")
  }

  # 地区 × 设施的欧氏距离矩阵（dist() 只能算同一组点之间的距离）
  d <- sqrt(outer(tot$x, facilities$x, "-")^2 +
              outer(tot$y, facilities$y, "-")^2)
  if (is.null(d0)) d0 <- stats::median(d)
  d0 <- suppressWarnings(as.numeric(d0))
  if (length(d0) != 1L || !is.finite(d0) || d0 <= 0) d0 <- 1
  w <- vapply(seq_len(nrow(facilities)), function(j)
    facilities$capacity[j] / (1 + (d[, j] / d0)^beta), numeric(nrow(tot)))
  access <- rowSums(w)

  regions <- data.frame(
    region = tot$region, ses = tot$ses, x = tot$x, y = tot$y,
    population = tot$population, access = access,
    stringsAsFactors = FALSE
  )
  overall <- stats::weighted.mean(access, tot$population)
  thr <- stats::median(tot$ses, na.rm = TRUE)
  low <- regions$ses < thr
  a_low <- if (any(low)) stats::weighted.mean(access[low], tot$population[low]) else NA_real_
  a_high <- if (any(!low)) stats::weighted.mean(access[!low], tot$population[!low]) else NA_real_
  list(
    regions = regions, facilities = facilities,
    overall = overall,
    access_low = a_low, access_high = a_high,
    ratio_low_high = if (is.finite(a_high) && a_high > 0) a_low / a_high else NA_real_,
    d0 = d0, beta = beta,
    meta = list(n = nrow(tot), n_facilities = nrow(facilities), year = year_value)
  )
}
