# =============================================================
# epiCore / region.R — 地区编码规范化与地区码表
# 目标：把「陕西省 / 陕西 / 陕西 」等不同写法收敛到同一个 region 编码，
#       避免上游 CSV 换个写法就让下游 join 静默丢行。
# 说明：不做臆造的行政区划代码表；内置的仅是无争议的行政后缀清理，
#       需要 alias / GB-T 2260 映射时由调用方通过 aliases 参数提供。
# =============================================================

EPI_ADMIN_SUFFIX <- "(维吾尔|壮族|回族|特别行政)?(自治区|省|市|特别行政区)$"

#' 规范化地区名称
#'
#' @param x 字符向量
#' @param strip_suffix 是否去掉省级行政后缀
#' @param aliases 命名字符向量/列表：names 为原始写法，值为目标编码
normalize_region <- function(x, strip_suffix = TRUE, aliases = NULL) {
  x <- as.character(x)
  bom <- intToUtf8(65279L)                       # UTF-8 BOM，Excel 导出常见
  x <- gsub(bom, "", x, fixed = TRUE)
  x <- gsub("[[:space:]]+", "", x)               # 省名内空格也一并去掉
  if (!is.null(aliases)) {
    a <- unlist(aliases, use.names = TRUE)
    hit <- x %in% names(a)
    if (any(hit)) x[hit] <- unname(a[match(x[hit], names(a))])
  }
  if (strip_suffix) x <- sub(EPI_ADMIN_SUFFIX, "", x)
  x
}

#' 生成地区码表
#'
#' 返回 data.frame(region, region_id, label)。region_id 是稳定的内部序号，
#' 顺序与输入一致；label 保留规范化前的原始写法，便于溯源。
epi_region_codes <- function(regions, strip_suffix = TRUE, aliases = NULL) {
  label <- as.character(regions)
  region <- normalize_region(label, strip_suffix = strip_suffix, aliases = aliases)
  if (any(is.na(region)) || any(!nzchar(region)))
    stop("地区编码含空值", call. = FALSE)
  if (anyDuplicated(region))
    stop(sprintf("规范化后地区编码重复: %s",
                 paste(unique(region[duplicated(region)]), collapse = ", ")),
         call. = FALSE)
  data.frame(region = region, region_id = seq_along(region), label = label,
             stringsAsFactors = FALSE)
}
