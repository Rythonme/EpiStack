# =============================================================
# epiSpace / moran.R — 全局 Moran's I 与置换检验
#
# 统计量与置换抽样刻意保持最简形式，与六层切片此前的手写实现逐位一致：
#   I = (n / S0) * sum_ij w_ij z_i z_j / sum_i z_i^2,  z = x - mean(x)
#   I_null = replicate(n_perm, I(sample(x)))
#   p = (1 + sum(abs(I_null) >= abs(I_obs))) / (n_perm + 1)
# 改公式前先想清楚 golden 基线要不要跟着改。
# =============================================================

.space_moran_stat <- function(v, W) {
  z <- v - mean(v)
  (length(v) / sum(W)) * sum(W * outer(z, z)) / sum(z^2)
}

.space_as_weights <- function(W) {
  if (inherits(W, "epi_space_weights")) return(W$W)
  if (!is.matrix(W)) .epi_stop("W 必须是权重矩阵或 space_weights() 的结果")
  W
}

#' 全局空间自相关：Moran's I 置换检验
#'
#' @param x 数值向量（顺序与 W 的地区名一致），或契约表 / data.frame
#' @param W 权重矩阵；x 是 epiCore 契约时可省略，自动取 `x$W`
#' @param value 若 x 是表，指定用哪一列做自相关；默认优先 population 归一化的率
#' @param n_perm 置换次数；0 表示只算点估计
#' @param seed 随机种子；非 NULL 时函数在置换前 set.seed，保证结果可复现
#' @param alternative 双侧（默认）或 greater / less
#' @return 类 `epi_space_moran` 的列表，含 I / p / I_null / regions
space_moran <- function(x, W = NULL, value = NULL, n_perm = 999L,
                        seed = NULL, alternative = c("two.sided", "greater", "less")) {
  alternative <- match.arg(alternative)
  n_perm <- as.integer(n_perm)
  if (n_perm < 0L) .epi_stop("n_perm 不能为负数")

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
  if (stats::sd(v) == 0) .epi_stop("观测值全部相同，Moran's I 无定义")

  I_obs <- .space_moran_stat(v, W)
  I_null <- numeric(0)
  p_val <- NA_real_
  if (n_perm > 0L) {
    if (!is.null(seed)) set.seed(as.integer(seed))
    I_null <- replicate(n_perm, .space_moran_stat(sample(v), W))
    p_val <- switch(alternative,
      two.sided = (1 + sum(abs(I_null) >= abs(I_obs))) / (n_perm + 1),
      greater   = (1 + sum(I_null >= I_obs)) / (n_perm + 1),
      less      = (1 + sum(I_null <= I_obs)) / (n_perm + 1)
    )
  }
  structure(
    list(I = I_obs, p = p_val, I_null = I_null, n_perm = n_perm,
         alternative = alternative, regions = regions, seed = seed),
    class = "epi_space_moran"
  )
}

print.epi_space_moran <- function(x, ...) {
  cat(sprintf("<epi_space_moran> I = %.4f ｜ p = %s（%s，%d 次置换）\n",
              x$I, ifelse(is.na(x$p), "NA", sprintf("%.4f", x$p)),
              x$alternative, x$n_perm))
  cat(sprintf("  %d 个地区 ｜ 种子 %s\n",
              length(x$regions), if (is.null(x$seed)) "未固定" else as.character(x$seed)))
  invisible(x)
}
