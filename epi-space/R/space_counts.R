# =============================================================
# epiSpace / space_counts.R — 一站式入口（推荐用法）
#
# 契约表 → 全局 Moran → 局部 LISA → 热点分类 → 摘要。
# 与 epiCore 的关系：上游给契约与权重，本层只读、不回写、不改列。
# 切片里的 Moran 统计量与置换口径与 space_moran() 完全一致。
# =============================================================

#' 从契约表产出空间自相关结果
#'
#' @param x 契约表 data.frame，或 `epiCore::read_counts()` 的返回值
#' @param W 权重矩阵；x 是契约时可省略（自动取 `x$W`）
#' @param value 指定用于自相关的列；默认 count / population（无人口列时用 count）
#' @param year_value 取哪一年；默认取数据中最新年份
#' @param n_perm 置换次数，默认 999
#' @param seed 随机种子；非 NULL 时置换可复现
#' @param alpha 显著性水平，默认 0.05
#' @param alternative 全局检验方向：two.sided / greater / less
#' @return 类 `epi_space` 的列表：global / local / hotspots / summary / values / W / settings / meta
space_counts <- function(x, W = NULL, value = NULL, year_value = NULL,
                         n_perm = 999L, seed = NULL, alpha = 0.05,
                         alternative = c("two.sided", "greater", "less"),
                         region = "region", count = "count",
                         population = "population", year = "year") {
  alternative <- match.arg(alternative)
  p <- .space_prepare(x, region = region, count = count,
                      population = population, year = year)
  if (is.null(W)) W <- p$W
  if (is.null(W)) {
    # 没有上游权重时，尝试从契约里的 geo 表构造 rook 格网
    if (!is.null(p$geo)) W <- .space_grid_weights(p$geo, "rook", TRUE)
    else .epi_stop("没有权重矩阵：传 W，或用 epiCore::read_counts() 的返回值")
  }
  ws <- if (inherits(W, "epi_space_weights")) W else space_weights(W)
  vv <- .space_values(p, year_value = year_value, W = ws$W)
  v <- vv$values

  if (!is.null(value)) {
    # value 是契约表里的列名时，按 W 的地区顺序重取
    if (!value %in% names(p$data))
      .epi_stop("value 指定的列不存在：%s", value)
    vv2 <- .space_values(
      utils::modifyList(p, list(count = value, population = NULL)),
      year_value = vv$year, W = ws$W
    )
    v <- vv2$values
    vv$value_column <- value
  }

  mo <- space_moran(v, W = ws$W, n_perm = n_perm, seed = seed,
                    alternative = alternative)
  li <- space_lisa(v, W = ws$W, n_perm = n_perm, seed = seed, alpha = alpha)
  hs <- space_hotspot(li)
  out <- structure(
    list(
      global = mo, local = li$table, hotspots = hs,
      values = vv$tot, W = ws,
      settings = list(n_perm = n_perm, seed = seed, alpha = alpha,
                      alternative = alternative, value = vv$value_column %||% "rate"),
      meta = list(
        package = "epiSpace", version = .space_version(),
        n_regions = nrow(ws$W), year = vv$year,
        rate_is_count = vv$rate_is_count, source = ws$source
      )
    ),
    class = "epi_space"
  )
  out$summary <- space_summary(out)
  out
}

print.epi_space <- function(x, ...) {
  h <- table(factor(x$hotspots$category,
                    levels = c("热点", "冷点", "空间离群", "不显著")))
  cat(sprintf("<epi_space> %s ｜ %d 地区 ｜ 权重来自 %s\n",
              paste0("epiSpace ", x$meta$version), x$meta$n_regions, x$meta$source))
  cat(sprintf("  全局 Moran's I = %.4f ｜ p = %s（%d 次置换）\n",
              x$global$I, ifelse(is.na(x$global$p), "NA",
                                 sprintf("%.4f", x$global$p)), x$settings$n_perm))
  cat(sprintf("  热点 %d ｜ 冷点 %d ｜ 空间离群 %d ｜ 不显著 %d\n",
              h[["热点"]], h[["冷点"]], h[["空间离群"]], h[["不显著"]]))
  invisible(x)
}
