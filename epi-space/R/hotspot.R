# =============================================================
# epiSpace / hotspot.R — 显著热点、冷点与空间离群
#
# 只在 LISA 显著时给类别：HH 且 p<alpha 为热点，LL 为冷点，
# HL/LH 为空间离群。不显著一律「不显著」——不把噪声当地点。
# =============================================================

#' 由 LISA 结果标注热点 / 冷点
#'
#' @param lisa `space_lisa()` 的结果，或含 quadrant / p_i 的 data.frame
#' @param alpha 显著性水平；NULL 时沿用 lisa 里的值
#' @return data.frame：原列加 `significant` 与 `category`
space_hotspot <- function(lisa, alpha = NULL) {
  if (inherits(lisa, "epi_space_lisa")) {
    d <- lisa$table
    if (is.null(alpha)) alpha <- lisa$alpha
  } else if (is.data.frame(lisa)) {
    d <- lisa
    if (is.null(alpha)) alpha <- 0.05
  } else {
    .epi_stop("lisa 必须是 space_lisa() 的结果或逐地区 data.frame")
  }
  need <- c("quadrant", "p_i")
  miss <- setdiff(need, names(d))
  if (length(miss)) .epi_stop("lisa 缺少列：%s", paste(miss, collapse = ", "))
  if (!is.numeric(alpha) || length(alpha) != 1L || alpha <= 0 || alpha >= 1)
    .epi_stop("alpha 必须在 0 与 1 之间")

  sig <- !is.na(d$p_i) & d$p_i < alpha
  cat <- rep("不显著", nrow(d))
  cat[sig & d$quadrant == "HH"] <- "热点"
  cat[sig & d$quadrant == "LL"] <- "冷点"
  cat[sig & d$quadrant %in% c("HL", "LH")] <- "空间离群"
  d$significant <- sig
  d$category <- cat
  d[order(match(d$category, c("热点", "冷点", "空间离群", "不显著")), d$p_i), , drop = FALSE]
}
