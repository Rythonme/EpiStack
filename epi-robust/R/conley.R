# =============================================================
# epiRobust / conley.R — 空间依赖稳健的标准误
#
# 朴素 SE 把每个地区当独立样本；有空间自相关时会系统性偏小。
# Conley HAC 用距离截断内的成对乘积重估 meat：
#   V = (X'X)^-1 [ sum_i sum_j 1(d_ij<=c) e_i e_j x_i x_j' ] (X'X)^-1
# 多个截断距离一起报，看结论会不会从「显著」变成「不显著」。
# =============================================================

.robust_conley_fit <- function(y, X, D, cutoff) {
  XtX <- crossprod(X)
  XtX_inv <- solve(XtX)
  beta <- as.vector(XtX_inv %*% crossprod(X, y))
  e <- as.vector(y - X %*% beta)
  n <- length(y)
  Wd <- D <= cutoff
  diag(Wd) <- FALSE
  # Bartlett 核 w = 1 - d/c：保证 meat 半正定，避免 0/1 截断在
  # 近全连接时给出负方差（被截断成 0 的假标准误）。
  wk <- ifelse(Wd, 1 - D / cutoff, 0)
  if (!any(wk > 1e-12))
    return(list(beta = beta, se = rep(NA_real_, ncol(X)),
                V = NULL, n_pairs = 0L, degenerate = TRUE))
  meat <- matrix(0, ncol(X), ncol(X))
  for (i in seq_len(n)) {
    j <- which(Wd[i, ])
    if (!length(j)) next
    Sj <- colSums(X[j, , drop = FALSE] * (e[j] * wk[i, j]))
    meat <- meat + outer(e[i] * X[i, ], Sj)
  }
  V <- XtX_inv %*% meat %*% XtX_inv
  list(beta = beta, se = sqrt(pmax(0, diag(V))), V = V,
       n_pairs = sum(Wd) / 2L)
}

#' Conley 空间稳健标准误
#'
#' 在多个距离截断下估计 Conley HAC 标准误，与朴素标准误对照，报告
#' 置信区间是否跨过 0。默认对率做截距回归（即空间稳健的均值估计）；
#' 也可传 design 矩阵做带协变量的回归。
#'
#' @param x 契约表 data.frame，或 epiCore::read_counts() 的返回值
#' @param coords 坐标矩阵；缺省时取 geo 表的 row / col
#' @param cutoffs 距离截断向量，单位为坐标格距
#' @param design 可选的 n×p 设计矩阵；缺省为全 1 截距
#' @param year_value 取哪一年；默认最新年份
#' @param region,count,population,year 契约列名
#' @return 类 `epi_robust_conley` 的列表，含 table / verdict
#' @export
robust_conley <- function(x, coords = NULL, cutoffs = c(1.5, 2, 3, 6),
                          design = NULL, year_value = NULL,
                          region = "region", count = "count",
                          population = "population", year = "year") {
  cutoffs <- as.numeric(cutoffs)
  if (!length(cutoffs) || anyNA(cutoffs) || any(cutoffs <= 0))
    .epi_stop("cutoffs 必须是正数向量")
  p <- .robust_prepare(x, region, count, population, year)
  vv <- .robust_values(p, year_value)
  v <- vv$values
  regs <- names(v)
  n <- length(v)

  if (is.null(coords)) {
    geo <- p$geo
    if (is.null(geo)) .epi_stop("Conley 需要 coords，或 geo 表里的 row / col")
    geo <- geo[match(regs, geo[[region]]), , drop = FALSE]
    if (anyNA(geo[[region]])) .epi_stop("geo 表缺少部分地区")
    coords <- cbind(as.numeric(geo$row), as.numeric(geo$col))
  }
  coords <- as.matrix(coords)
  if (nrow(coords) != n) .epi_stop("coords 行数 %d 与地区数 %d 不一致",
                                   nrow(coords), n)
  rownames(coords) <- regs
  D <- as.matrix(stats::dist(coords))

  X <- if (is.null(design)) matrix(1, n, 1L) else as.matrix(design)
  if (nrow(X) != n) .epi_stop("design 行数 %d 与地区数 %d 不一致", nrow(X), n)
  if (qr(X)$rank < ncol(X)) .epi_stop("design 列不满秩，无法估计")
  if (is.null(colnames(X))) colnames(X) <- paste0("X", seq_len(ncol(X)))

  XtX_inv <- solve(crossprod(X))
  beta0 <- as.vector(XtX_inv %*% crossprod(X, v))
  e0 <- as.vector(v - X %*% beta0)
  sigma2 <- sum(e0^2) / (n - ncol(X))
  naive_se <- sqrt(pmax(0, diag(sigma2 * XtX_inv)))

  rows <- vector("list", length(cutoffs))
  for (i in seq_along(cutoffs)) {
    fit <- .robust_conley_fit(v, X, D, cutoffs[i])
    rows[[i]] <- data.frame(
      term = colnames(X),
      cutoff = cutoffs[i],
      beta = fit$beta,
      naive_se = naive_se,
      conley_se = fit$se,
      se_ratio = fit$se / naive_se,
      naive_lo = fit$beta - 1.96 * naive_se,
      naive_hi = fit$beta + 1.96 * naive_se,
      conley_lo = fit$beta - 1.96 * fit$se,
      conley_hi = fit$beta + 1.96 * fit$se,
      n_pairs = fit$n_pairs,
      stringsAsFactors = FALSE
    )
  }
  tab <- do.call(rbind, rows)
  naive_sig <- (tab$naive_lo > 0) | (tab$naive_hi < 0)
  conley_sig <- (tab$conley_lo > 0) | (tab$conley_hi < 0)
  max_ratio <- max(tab$se_ratio, na.rm = TRUE)
  verdict <- if (any(naive_sig & !conley_sig)) {
    "翻转：朴素 SE 判显著，Conley SE 下不再显著"
  } else if (max_ratio > 1.5) {
    sprintf("需警惕：空间稳健 SE 最大放大到朴素的 %.2f 倍", max_ratio)
  } else {
    "稳定：空间稳健 SE 未改变显著性结论"
  }
  structure(
    list(table = tab, verdict = verdict, values = v, coords = coords,
         settings = list(cutoffs = cutoffs, year = vv$year,
                         term = colnames(X))),
    class = "epi_robust_conley"
  )
}

#' @export
print.epi_robust_conley <- function(x, ...) {
  cat(sprintf("<epi_robust_conley> %d 个截断 ｜ %d 地区\n",
              length(x$settings$cutoffs), length(x$values)))
  t <- x$table[x$table$term == x$settings$term[1L], , drop = FALSE]
  for (i in seq_len(nrow(t))) {
    r <- t[i, ]
    cat(sprintf("  d<=%-4g ｜ beta = %+.4f ｜ naive SE %.4f → Conley %.4f (×%.2f)\n",
                r$cutoff, r$beta, r$naive_se, r$conley_se, r$se_ratio))
  }
  cat(sprintf("  判定：%s\n", x$verdict))
  invisible(x)
}
