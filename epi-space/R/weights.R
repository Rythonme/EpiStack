# =============================================================
# epiSpace / weights.R — 权重矩阵的校验与构造
#
# 两种来源：直接传入矩阵（来自 epiCore::read_counts()$W 或
# epi_read_graph()），或从含 region / row / col 的格网表构造。
# 行标准化后 W[i,j] 与 W[j,i] 可以不等（度数不同），但邻接结构必须
# 对称；孤立地区会让 ICAR / Moran 的分母出问题，这里直接报错。
# =============================================================

.space_check_weights <- function(W) {
  if (!is.matrix(W) || nrow(W) != ncol(W))
    .epi_stop("W 必须是方阵")
  if (nrow(W) < 3L) .epi_stop("W 至少需要 3 个地区")
  if (is.null(rownames(W)) || is.null(colnames(W)) ||
      !identical(rownames(W), colnames(W)))
    .epi_stop("W 必须有地区名，且 rownames 与 colnames 一致")
  if (anyNA(W) || any(!is.finite(W)))
    .epi_stop("W 含缺失或非有限值")
  if (any(diag(W) != 0)) .epi_stop("W 的对角线必须为 0")
  if (any(W < 0)) .epi_stop("W 不能含负权重")
  structure_ok <- isTRUE(all.equal((W > 0), t(W > 0), check.attributes = FALSE))
  if (!structure_ok)
    .epi_stop("W 的邻接结构不对称（行标准化允许数值不对称，不允许结构不对称）")
  rs <- rowSums(W)
  iso <- rownames(W)[rs == 0]
  if (length(iso)) .epi_stop("存在孤立地区，无法计算空间自相关：%s",
                             paste(iso, collapse = ", "))
  if (any(abs(rs - 1) > 1e-8))
    .space_warn("W 不是行标准化矩阵（行和范围 %.4f–%.4f），计算结果按原权重解释",
              min(rs), max(rs))
  invisible(TRUE)
}

.space_grid_weights <- function(geo, style, row_standardize) {
  if (!is.data.frame(geo) || !all(c("region", "row", "col") %in% names(geo)))
    .epi_stop("从 geo 构造权重需要 region / row / col 三列")
  g <- geo[!duplicated(geo$region), , drop = FALSE]
  n <- nrow(g)
  dr <- outer(g$row, g$row, "-")
  dc <- outer(g$col, g$col, "-")
  adj <- if (identical(style, "rook")) (abs(dr) + abs(dc) == 1L)
         else (pmax(abs(dr), abs(dc)) == 1L)
  W <- matrix(as.numeric(adj), n, n,
              dimnames = list(as.character(g$region), as.character(g$region)))
  diag(W) <- 0
  if (row_standardize) W <- sweep(W, 1L, rowSums(W), "/")
  W
}

.space_warn <- function(...) warning(sprintf(...), call. = FALSE)

#' 校验或构造空间权重矩阵
#'
#' @param x 权重矩阵，或含 region / row / col 的格网地区表
#' @param style 格网邻接方式，rook（共边）或 queen（共边或共点）
#' @param row_standardize 是否行标准化
#' @param regions 可选：按此顺序重排权重矩阵
#' @return 类 `epi_space_weights` 的列表，含 W / regions / n / density
space_weights <- function(x, style = c("rook", "queen"),
                          row_standardize = TRUE, regions = NULL) {
  style <- match.arg(style)
  if (is.matrix(x)) {
    W <- x
    src <- "matrix"
    if (!is.null(regions)) {
      ix <- match(regions, rownames(W))
      if (anyNA(ix))
        .epi_stop("regions 中有地区不在 W 里：%s",
                  paste(regions[is.na(ix)], collapse = ", "))
      W <- W[ix, ix, drop = FALSE]
    }
  } else if (is.data.frame(x)) {
    W <- .space_grid_weights(x, style, row_standardize)
    src <- paste0("grid-", style)
    if (!is.null(regions)) {
      ix <- match(regions, rownames(W))
      if (anyNA(ix))
        .epi_stop("regions 中有地区不在格网表里：%s",
                  paste(regions[is.na(ix)], collapse = ", "))
      W <- W[ix, ix, drop = FALSE]
    }
  } else {
    .epi_stop("x 必须是权重矩阵或含 region / row / col 的数据框")
  }
  dimnames(W) <- list(as.character(rownames(W)), as.character(colnames(W)))
  .space_check_weights(W)
  structure(
    list(
      W = W, regions = rownames(W), n = nrow(W), source = src,
      density = sum(W > 0) / (nrow(W) * (nrow(W) - 1L)),
      rowsum_min = min(rowSums(W)), rowsum_max = max(rowSums(W))
    ),
    class = "epi_space_weights"
  )
}

print.epi_space_weights <- function(x, ...) {
  cat(sprintf("<epi_space_weights> %d 地区 ｜ 来源 %s\n", x$n, x$source))
  cat(sprintf("  邻接密度 %.3f ｜ 行和 %.3f–%.3f\n",
              x$density, x$rowsum_min, x$rowsum_max))
  invisible(x)
}

#' 邻接表
#'
#' @param w `space_weights()` 的结果，或权重矩阵
#' @return data.frame(region, n_neighbors, neighbors)
space_neighbors <- function(w) {
  W <- if (inherits(w, "epi_space_weights")) w$W else as.matrix(w)
  out <- data.frame(
    region = rownames(W),
    n_neighbors = rowSums(W > 0),
    neighbors = vapply(seq_len(nrow(W)), function(i)
      paste(colnames(W)[W[i, ] > 0], collapse = ", "), character(1)),
    stringsAsFactors = FALSE
  )
  out
}
