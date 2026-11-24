# =============================================================
# epiRobust / weights.R — 邻接定义的敏感性
#
# 同一份数据换 rook / queen / kNN 三种邻接，看全局 Moran's I 的方向
# 与显著性会不会翻转。权重构造不依赖 spdep：格网用行列差，kNN 用
# 欧氏距离并做对称化，行标准化后交给与 epiSpace 同口径的置换检验。
# =============================================================

.robust_grid_weights <- function(geo, style = c("rook", "queen"),
                                 row_standardize = TRUE) {
  style <- match.arg(style)
  g <- geo[!duplicated(geo$region), , drop = FALSE]
  g$row <- as.numeric(g$row)
  g$col <- as.numeric(g$col)
  n <- nrow(g)
  dr <- outer(g$row, g$row, "-")
  dc <- outer(g$col, g$col, "-")
  adj <- if (identical(style, "rook")) (abs(dr) + abs(dc) == 1L)
         else (pmax(abs(dr), abs(dc)) == 1L)
  W <- matrix(as.numeric(adj), n, n,
              dimnames = list(as.character(g$region), as.character(g$region)))
  diag(W) <- 0
  if (any(rowSums(W) == 0))
    .epi_stop("构造 %s 权重后出现孤立地区，请检查 geo 的 row / col", style)
  if (row_standardize) W <- sweep(W, 1L, rowSums(W), "/")
  W
}

.robust_knn_weights <- function(geo, k = 4L, row_standardize = TRUE) {
  g <- geo[!duplicated(geo$region), , drop = FALSE]
  g$row <- as.numeric(g$row)
  g$col <- as.numeric(g$col)
  n <- nrow(g)
  if (n < 4L) .epi_stop("kNN 权重至少需要 4 个地区")
  k <- max(1L, min(as.integer(k), n - 1L))
  D <- as.matrix(stats::dist(cbind(g$row, g$col)))
  diag(D) <- Inf
  dn <- list(as.character(g$region), as.character(g$region))
  W0 <- matrix(0, n, n, dimnames = dn)
  for (i in seq_len(n)) {
    idx <- order(D[i, ])[seq_len(k)]
    W0[i, idx] <- 1
  }
  adj <- (W0 > 0) | t(W0 > 0)
  W <- matrix(as.numeric(adj), n, n, dimnames = dn)
  diag(W) <- 0
  if (any(rowSums(W) == 0)) .epi_stop("kNN 权重出现孤立地区")
  if (row_standardize) W <- sweep(W, 1L, rowSums(W), "/")
  W
}

.robust_weights_from <- function(style, geo, k = 4L, W = NULL) {
  switch(style,
    rook   = .robust_grid_weights(geo, "rook", TRUE),
    queen  = .robust_grid_weights(geo, "queen", TRUE),
    knn    = .robust_knn_weights(geo, k, TRUE),
    custom = {
      if (is.null(W)) .epi_stop("style = custom 时必须传 W")
      W
    },
    .epi_stop("未知权重类型：%s", style)
  )
}

#' 邻接定义敏感性
#'
#' 对同一份观测值换 rook / queen / kNN 权重，重算全局 Moran's I 与置换 p，
#' 检查方向或显著性是否随邻接定义翻转。
#'
#' @param x 契约表 data.frame，或 epiCore::read_counts() 的返回值
#' @param styles 权重类型向量，可取 rook / queen / knn / custom
#' @param k kNN 的邻居数
#' @param W 自定义权重矩阵，仅 styles 含 custom 时需要
#' @param year_value 取哪一年；默认最新年份
#' @param n_perm 置换次数
#' @param seed 随机种子；非 NULL 时各权重使用递增种子，结果可复现
#' @param alternative 全局检验方向
#' @param region,count,population,year 契约列名
#' @return 类 `epi_robust_weights` 的列表，含 table / W / values / verdict
#' @export
robust_weights <- function(x, styles = c("rook", "queen", "knn"), k = 4L,
                           W = NULL, year_value = NULL, n_perm = 999L,
                           seed = NULL,
                           alternative = c("two.sided", "greater", "less"),
                           region = "region", count = "count",
                           population = "population", year = "year") {
  alternative <- match.arg(alternative)
  styles <- match.arg(styles, c("rook", "queen", "knn", "custom"),
                      several.ok = TRUE)
  p <- .robust_prepare(x, region, count, population, year)
  vv <- .robust_values(p, year_value)
  v <- vv$values
  regs <- names(v)
  geo <- p$geo
  if (is.null(geo))
    .epi_stop("权重敏感性需要 geo 表（含 region / row / col）")
  geo <- geo[match(regs, geo[[region]]), , drop = FALSE]
  if (anyNA(geo[[region]])) .epi_stop("geo 表缺少部分地区")

  rows <- vector("list", length(styles))
  W_list <- list()
  for (i in seq_along(styles)) {
    st <- styles[i]
    Wi <- .robust_weights_from(st, geo, k, W)
    W_list[[st]] <- Wi
    s <- if (is.null(seed)) NULL else as.integer(seed) + i - 1L
    mo <- .robust_moran_test(v, Wi, n_perm, s, alternative)
    rows[[i]] <- data.frame(
      style = st,
      mean_neighbors = mean(rowSums(Wi > 0)),
      density = sum(Wi > 0) / (nrow(Wi) * (nrow(Wi) - 1L)),
      I = mo$I, p = mo$p, stringsAsFactors = FALSE
    )
  }
  tab <- do.call(rbind, rows)
  signs <- unique(sign(tab$I))
  sig <- !is.na(tab$p) & tab$p < 0.05
  verdict <- if (length(signs) > 1L) {
    "翻转：不同邻接下 Moran's I 符号不一致"
  } else if (length(unique(sig)) > 1L) {
    "部分翻转：显著性结论随邻接定义变化"
  } else {
    "稳定：各邻接下方向与显著性一致"
  }
  structure(
    list(table = tab, W = W_list, values = v, verdict = verdict,
         settings = list(k = k, n_perm = n_perm, seed = seed,
                         alternative = alternative, year = vv$year)),
    class = "epi_robust_weights"
  )
}

#' @export
print.epi_robust_weights <- function(x, ...) {
  cat(sprintf("<epi_robust_weights> %d 种邻接 ｜ %d 地区\n",
              nrow(x$table), length(x$values)))
  for (i in seq_len(nrow(x$table))) {
    r <- x$table[i, ]
    cat(sprintf("  %-7s I = %+.4f ｜ p = %s\n", r$style, r$I, .robust_p(r$p)))
  }
  cat(sprintf("  判定：%s\n", x$verdict))
  invisible(x)
}
