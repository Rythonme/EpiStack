# =============================================================
# epiRobust / maup.R — 可修改面元单元问题（MAUP）
#
# 把细格网按整数倍聚合成粗格网（尺度效应），再在同一尺度下换邻接
# 定义（分区效应的一部分），看 Moran's I 与热点数是否稳定。
# 只聚合 count / population，不回写原始数据；聚合后的率 = 总计数 / 总人口。
# =============================================================

.robust_aggregate <- function(vv, geo, scale, region) {
  g <- geo[match(names(vv$values), geo[[region]]), , drop = FALSE]
  g$newrow <- ceiling(as.numeric(g$row) / scale)
  g$newcol <- ceiling(as.numeric(g$col) / scale)
  g$newregion <- sprintf("A%02d-%02d", g$newrow, g$newcol)
  cnt <- tapply(vv$tot$count, g$newregion, sum)
  pop <- tapply(vv$tot$population, g$newregion,
                function(z) if (anyNA(z)) NA_real_ else sum(z))
  values <- if (all(!is.na(pop))) as.numeric(cnt) / as.numeric(pop) else as.numeric(cnt)
  names(values) <- names(cnt)
  newgeo <- unique(data.frame(
    region = g$newregion, row = g$newrow, col = g$newcol,
    stringsAsFactors = FALSE
  ))
  list(values = values, geo = newgeo,
       count = as.numeric(cnt), population = as.numeric(pop))
}

#' MAUP 尺度敏感性
#'
#' 在多个聚合尺度下重算全局 Moran's I 与 LISA 热点，报告结论区间、
#' 符号是否翻转、显著热点是否消失。
#'
#' @param x 契约表 data.frame，或 epiCore::read_counts() 的返回值
#' @param scales 聚合倍数向量，1 表示原始格网
#' @param style 各尺度下使用的邻接：rook / queen / knn
#' @param k kNN 邻居数
#' @param year_value 取哪一年；默认最新年份
#' @param n_perm 置换次数
#' @param seed 随机种子；非 NULL 时各尺度使用递增种子，结果可复现
#' @param alpha 局部检验显著性水平
#' @param region,count,population,year 契约列名
#' @return 类 `epi_robust_maup` 的列表，含 table / details / verdict
#' @export
robust_maup <- function(x, scales = c(1L, 2L, 3L),
                        style = c("rook", "queen", "knn"), k = 4L,
                        year_value = NULL, n_perm = 999L, seed = NULL,
                        alpha = 0.05, region = "region", count = "count",
                        population = "population", year = "year") {
  style <- match.arg(style)
  scales <- as.integer(scales)
  if (!length(scales) || anyNA(scales) || any(scales < 1L))
    .epi_stop("scales 必须是正整数向量")
  p <- .robust_prepare(x, region, count, population, year)
  vv <- .robust_values(p, year_value)
  v <- vv$values
  regs <- names(v)
  geo <- p$geo
  if (is.null(geo))
    .epi_stop("MAUP 体检需要 geo 表（含 region / row / col）")
  geo <- geo[match(regs, geo[[region]]), , drop = FALSE]
  if (anyNA(geo[[region]])) .epi_stop("geo 表缺少部分地区")

  rows <- vector("list", length(scales))
  details <- list()
  for (i in seq_along(scales)) {
    s <- scales[i]
    if (s == 1L) {
      agg_v <- v
      agg_geo <- geo
    } else {
      agg <- .robust_aggregate(vv, geo, s, region)
      agg_v <- agg$values
      agg_geo <- agg$geo
    }
    Wi <- .robust_weights_from(style, agg_geo, k, NULL)
    s_seed <- if (is.null(seed)) NULL else as.integer(seed) + i - 1L
    mo <- .robust_moran_test(agg_v, Wi, n_perm, s_seed)
    li <- .robust_lisa_test(agg_v, Wi, n_perm, s_seed, alpha)
    rows[[i]] <- data.frame(
      scale = s, n_regions = length(agg_v),
      I = mo$I, p = mo$p,
      hotspots = li$hotspots, coldspots = li$coldspots,
      outliers = li$outliers, stringsAsFactors = FALSE
    )
    details[[as.character(s)]] <- list(values = agg_v, W = Wi, lisa = li$table)
  }
  tab <- do.call(rbind, rows)
  signs <- unique(sign(tab$I))
  sig_hot <- tab$hotspots > 0L
  verdict <- if (length(signs) > 1L) {
    "翻转：聚合尺度改变 Moran's I 符号"
  } else if (length(unique(sig_hot)) > 1L) {
    "部分翻转：热点存在性随聚合尺度变化"
  } else {
    "稳定：方向与热点存在性在各尺度一致"
  }
  structure(
    list(table = tab, details = details, verdict = verdict,
         settings = list(style = style, k = k, n_perm = n_perm,
                         seed = seed, alpha = alpha, year = vv$year,
                         scales = scales)),
    class = "epi_robust_maup"
  )
}

#' @export
print.epi_robust_maup <- function(x, ...) {
  cat(sprintf("<epi_robust_maup> %d 个尺度 ｜ 邻接 %s\n",
              nrow(x$table), x$settings$style))
  for (i in seq_len(nrow(x$table))) {
    r <- x$table[i, ]
    cat(sprintf("  %d×  → %2d 地区 ｜ I = %+.4f ｜ p = %s ｜ 热点 %d\n",
                r$scale, r$n_regions, r$I, .robust_p(r$p), r$hotspots))
  }
  cat(sprintf("  判定：%s\n", x$verdict))
  invisible(x)
}
