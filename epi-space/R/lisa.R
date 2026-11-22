# =============================================================
# epiSpace / lisa.R — 局部空间自相关（LISA）
#
# I_i = z_i * sum_j w_ij z_j / (sum_i z_i^2 / n)
# 每个地区的置换分布独立计数；显著性用 |I_i| 的双侧置换 p 值。
# 象限按 (z_i, 空间滞后) 的符号分成 HH / LL / HL / LH。
# =============================================================

.space_lisa_stats <- function(v, W) {
  z <- v - mean(v)
  lag <- as.vector(W %*% z)
  denom <- sum(z^2) / length(v)
  list(Ii = z * lag / denom, lag = lag, z = z)
}

#' 局部空间自相关与四象限
#'
#' @param x 数值向量（顺序与 W 的地区名一致），或契约表 / data.frame
#' @param W 权重矩阵；x 是 epiCore 契约时可省略
#' @param value 若 x 是表，指定用哪一列；默认按率（count / population）
#' @param n_perm 置换次数；0 表示只算点估计
#' @param seed 随机种子；非 NULL 时在置换前固定
#' @param alpha 显著性水平，默认 0.05
#' @return 类 `epi_space_lisa` 的列表，含 table（逐地区）
space_lisa <- function(x, W = NULL, value = NULL, n_perm = 999L,
                       seed = NULL, alpha = 0.05) {
  n_perm <- as.integer(n_perm)
  if (n_perm < 0L) .epi_stop("n_perm 不能为负数")
  if (!is.numeric(alpha) || length(alpha) != 1L ||
      alpha <= 0 || alpha >= 1) .epi_stop("alpha 必须在 0 与 1 之间")

  if (is.numeric(x) && length(dim(x)) <= 1L) {
    v <- as.numeric(x)
    names(v) <- names(x)                    # tapply() 结果带名字，保留供地区对齐
    regions <- if (!is.null(W)) rownames(.space_as_weights(W)) else names(v)
  } else {
    p <- .space_prepare(x)
    if (is.null(W)) W <- p$W
    vv <- .space_values(p, W = W)
    v <- vv$values
    regions <- names(v)
  }
  if (is.null(W)) .epi_stop("没有权重矩阵：传 W，或用 epiCore::read_counts() 的返回值")
  W <- .space_as_weights(W)
  if (length(v) != nrow(W))
    .epi_stop("观测值长度 %d 与权重矩阵阶数 %d 不一致", length(v), nrow(W))
  if (!is.null(names(v))) {
    ix <- match(rownames(W), names(v))
    if (anyNA(ix)) .epi_stop("W 中的地区观测值缺失：%s",
                             paste(rownames(W)[is.na(ix)], collapse = ", "))
    v <- as.numeric(v[ix])
  }
  if (any(!is.finite(v))) .epi_stop("观测值含缺失或非有限值")
  if (stats::sd(v) == 0) .epi_stop("观测值全部相同，LISA 无定义")

  st <- .space_lisa_stats(v, W)
  p_i <- rep(NA_real_, length(v))
  if (n_perm > 0L) {
    if (!is.null(seed)) set.seed(as.integer(seed))
    null <- replicate(n_perm, .space_lisa_stats(sample(v), W)$Ii)
    if (is.null(dim(null))) null <- matrix(null, nrow = length(v))
    ext <- abs(null) >= matrix(abs(st$Ii), nrow = length(v), ncol = n_perm)
    p_i <- (1 + rowSums(ext)) / (n_perm + 1)
  }
  quad <- ifelse(st$z >= 0 & st$lag >= 0, "HH",
          ifelse(st$z < 0 & st$lag < 0, "LL",
          ifelse(st$z >= 0, "HL", "LH")))
  tab <- data.frame(
    region = rownames(W), value = v, z = st$z, spatial_lag = st$lag,
    I_i = st$Ii, p_i = p_i, quadrant = quad,
    stringsAsFactors = FALSE
  )
  structure(
    list(table = tab, alpha = alpha, n_perm = n_perm, seed = seed,
         regions = rownames(W)),
    class = "epi_space_lisa"
  )
}

print.epi_space_lisa <- function(x, ...) {
  q <- table(factor(x$table$quadrant, levels = c("HH", "LL", "HL", "LH")))
  cat(sprintf("<epi_space_lisa> %d 地区 ｜ HH %d ｜ LL %d ｜ HL %d ｜ LH %d\n",
              nrow(x$table), q[["HH"]], q[["LL"]], q[["HL"]], q[["LH"]]))
  cat(sprintf("  置换 %d 次 ｜ alpha = %.2f ｜ 种子 %s\n",
              x$n_perm, x$alpha,
              if (is.null(x$seed)) "未固定" else as.character(x$seed)))
  invisible(x)
}
