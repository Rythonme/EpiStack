# =============================================================
# epiSpace / summary.R — 结果摘要
# =============================================================

#' 空间分析摘要
#'
#' @param x `space_counts()` 的结果
#' @return data.frame(metric, value)，便于写进 manifest 或报告
space_summary <- function(x) {
  if (!inherits(x, "epi_space")) .epi_stop("x 必须是 space_counts() 的结果")
  h <- table(factor(x$hotspots$category,
                    levels = c("热点", "冷点", "空间离群", "不显著")))
  data.frame(
    metric = c("regions", "year", "moran_I", "moran_p", "n_perm",
               "hotspots", "coldspots", "spatial_outliers", "significant"),
    value = c(
      as.character(x$meta$n_regions),
      if (is.null(x$meta$year)) "NA" else as.character(x$meta$year),
      .space_fmt(x$global$I, 4L),
      if (is.na(x$global$p)) "NA" else .space_fmt(x$global$p, 4L),
      as.character(x$settings$n_perm),
      as.character(h[["热点"]]), as.character(h[["冷点"]]),
      as.character(h[["空间离群"]]), as.character(sum(h[names(h) != "不显著"]))
    ),
    stringsAsFactors = FALSE
  )
}
