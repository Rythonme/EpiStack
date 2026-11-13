# =============================================================
# epiIngest / utils.R — 内部工具
#
# 设计底线：Imports 只有 utils / stats / tools，Excel、数据库、
# 栅格、哈希全部走 Suggests。断网只装 base R 也必须能读 CSV 并质控。
# =============================================================

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a

.epi_stop <- function(...) stop(sprintf(...), call. = FALSE)

.epi_warn <- function(...) warning(sprintf(...), call. = FALSE)

# 字段名别名：与 epiCore::EPI_FIELD_ALIASES 保持一致，
# 这样 ingest_read() 产出的标准列能原样交给 read_counts() 而不需二次映射。
EPI_INGEST_ALIASES <- list(
  date       = c("date", "日期", "时间", "year", "年", "年份", "month_date", "ym"),
  region     = c("region", "province", "prov", "省", "省份", "地区", "地区名称", "area", "county"),
  count      = c("count", "cases", "cases_est", "发病数", "病例数", "报告数", "n", "value"),
  population = c("population", "pop", "人口", "人口数", "pop_total"),
  disease    = c("disease", "病种", "疾病")
)

.epi_pick_col <- function(nms, candidates) {
  hit <- intersect(candidates, nms)
  if (length(hit)) hit[[1L]] else NA_character_
}

.epi_strip_bom <- function(x) gsub(intToUtf8(65279L), "", x, fixed = TRUE)

.epi_has_bom <- function(path) {
  con <- file(path, "rb")
  on.exit(close(con), add = TRUE)
  b <- readBin(con, "raw", 3L)
  length(b) >= 3L && identical(as.integer(b[1:3]), c(239L, 187L, 191L))
}

# 编码嗅探：先看 BOM，再按字节合法性判断。
# 注意：不能靠「替换字符」判断——GBK 字节流在 UTF-8 解码时可能不产生 U+FFFD。
.epi_detect_encoding <- function(path, deep = TRUE) {
  if (.epi_has_bom(path)) return("UTF-8")
  if (!isTRUE(deep)) return("UTF-8")
  n <- min(file.size(path), 262144L)
  raw <- tryCatch(readBin(path, "raw", n), error = function(e) raw(0))
  if (!length(raw)) return("UTF-8")
  s <- tryCatch(rawToChar(raw), error = function(e) NA_character_)
  if (is.na(s)) return("GBK")
  Encoding(s) <- "bytes"
  if (isTRUE(validUTF8(s))) "UTF-8" else "GBK"
}

# 分隔符嗅探：取前 5 行，按候选分隔符切出的列数稳定性打分。
.epi_detect_sep <- function(path, enc) {
  lines <- tryCatch({
    con <- file(path, "r", encoding = enc)
    on.exit(close(con), add = TRUE)
    suppressWarnings(readLines(con, n = 5L, warn = FALSE))
  }, error = function(e) character(0))
  lines <- lines[nzchar(lines)]
  if (!length(lines)) return(",")
  cands <- c(",", ";", "\t", "|")
  score <- vapply(cands, function(s) {
    cnt <- vapply(lines, function(l) {
      m <- gregexpr(s, l, fixed = TRUE)[[1L]]
      if (identical(m[[1L]], -1L)) 0L else length(m)
    }, integer(1))
    if (!length(cnt) || all(cnt == 0L)) return(-Inf)
    # 列数一致且大于 1 才算有效分隔符
    if (length(unique(cnt)) == 1L) cnt[[1L]] else -Inf
  }, numeric(1))
  if (all(!is.finite(score))) return(",")
  cands[which.max(score)]
}

# 日期解析：兼容 Date / POSIXct / 2021-01-01 / 2021-01 / 2021 / 2021/1/1 / 20210101
.epi_parse_date <- function(v) {
  if (inherits(v, "Date")) return(v)
  if (inherits(v, "POSIXt")) return(as.Date(v))
  v <- trimws(as.character(v))
  v <- gsub("[/.]", "-", v)
  v <- sub("[ T][0-9]{2}:[0-9]{2}(:[0-9]{2})?$", "", v)
  out <- rep(as.Date(NA), length(v))
  y  <- !is.na(v) & grepl("^[0-9]{4}$", v)
  ym <- !is.na(v) & grepl("^[0-9]{4}-[0-9]{1,2}$", v)
  ok <- !is.na(v) & grepl("^[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}$", v)
  d8 <- !is.na(v) & grepl("^[0-9]{8}$", v)
  # 空索引时 paste0(character(0), x) 会回收成 "-01-01"，必须逐个守卫。
  if (any(y))  out[y]  <- as.Date(paste0(v[y], "-01-01"))
  if (any(ym)) out[ym] <- as.Date(paste0(v[ym], "-01"))
  if (any(ok)) out[ok] <- as.Date(v[ok])
  if (any(d8)) out[d8] <- as.Date(paste0(substr(v[d8], 1L, 4L), "-",
                                         substr(v[d8], 5L, 6L), "-",
                                         substr(v[d8], 7L, 8L)))
  out
}

.epi_md5 <- function(path) {
  if (!length(path)) return(character(0))
  unname(tools::md5sum(path))
}

# 数值安全转换：返回 list(value, n_failed)，失败计数用于数据画像，
# 不静默变成 0，也不静默吞掉——由质检规则决定这些行怎么办。
.epi_to_numeric <- function(v) {
  if (is.numeric(v)) return(list(value = v, n_failed = sum(is.na(v) & !is.na(v))))
  s <- trimws(as.character(v))
  blank <- is.na(s) | !nzchar(s)
  out <- suppressWarnings(as.numeric(s))
  list(value = out, n_failed = sum(is.na(out) & !blank))
}

.epi_pkg_version <- function() {
  tryCatch(as.character(utils::packageVersion("epiIngest")),
           error = function(e) "0.0.0-dev")
}

.epi_file_type <- function(path) {
  if (dir.exists(path)) return("delim")          # 目录按分隔符文本批量读取
  ext <- tolower(tools::file_ext(path))
  out <- switch(ext, csv = "csv", tsv = "tsv", txt = "delim", xlsx = "excel", xls = "excel",
                tif = "raster", tiff = "raster", grib = "raster", nc = "raster", delim = "delim")
  if (is.null(out)) NA_character_ else out
}
