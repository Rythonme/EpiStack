# =============================================================
# epiIngest / adapters.R — 可选读取后端
#
# 原则：缺包可以少一条路，但不能悄悄少。
# 每个适配器先查依赖，缺了就报「装哪个包、怎么装」，绝不静默降级成空数据。
# =============================================================

.epi_need <- function(pkg, capability) {
  if (requireNamespace(pkg, quietly = TRUE)) return(invisible(TRUE))
  .epi_stop(paste0("读取 %s 需要 %s 包：install.packages(\"%s\")；",
                   "也可先运行 epi_ingest_capabilities() 查看当前可用能力"),
            capability, pkg, pkg)
}

# ---- 分隔符文本 -------------------------------------------------

.read_delim_file <- function(path, src) {
  enc <- if (identical(src$encoding, "auto")) .epi_detect_encoding(path) else src$encoding
  sep <- src$sep %||% if (identical(src$type, "tsv")) "\t" else .epi_detect_sep(path, enc)
  d <- utils::read.csv(path, sep = sep, fileEncoding = enc,
                       stringsAsFactors = FALSE, check.names = FALSE,
                       skip = src$skip,
                       na.strings = c("", "NA", "N/A", "na", "-", "--", "NULL"))
  names(d) <- .epi_strip_bom(names(d))
  names(d) <- trimws(names(d))
  list(data = d, encoding = enc, sep = sep, backend = "base")
}

# ---- Excel ------------------------------------------------------

.read_excel_src <- function(src) {
  .epi_need("readxl", "Excel 工作簿")
  path <- src$path[[1L]]
  if (!file.exists(path)) .epi_stop("文件不存在：%s", path)
  d <- as.data.frame(
    readxl::read_excel(path, sheet = src$sheet %||% 1L, skip = src$skip),
    stringsAsFactors = FALSE
  )
  names(d) <- .epi_strip_bom(names(d))
  list(data = d, encoding = "UTF-8", sep = NA_character_, backend = "readxl")
}

# ---- 数据库 -----------------------------------------------------

.read_db_src <- function(src) {
  .epi_need("DBI", "数据库查询")
  if (!inherits(src$con, "DBIConnection"))
    .epi_stop("con 不是有效的 DBI 连接")
  d <- as.data.frame(DBI::dbGetQuery(src$con, src$query), stringsAsFactors = FALSE)
  list(data = d, encoding = "UTF-8", sep = NA_character_, backend = "DBI")
}

# ---- HTTP 接口 --------------------------------------------------

# base R 就能带请求头下载（libcurl），不必为一次 GET 引入 httr2。
.epi_http_get <- function(url, headers = NULL) {
  tmp <- tempfile(fileext = ".raw")
  on.exit(unlink(tmp), add = TRUE)
  ok <- tryCatch({
    suppressWarnings(utils::download.file(url, tmp, quiet = TRUE, mode = "wb",
                                         headers = headers, method = "libcurl"))
    TRUE
  }, error = function(e) { .epi_stop("HTTP 请求失败：%s", conditionMessage(e)); FALSE })
  if (!isTRUE(ok)) .epi_stop("HTTP 请求失败：%s", url)
  readBin(tmp, "raw", file.size(tmp))
}

.read_api_src <- function(src) {
  raw <- .epi_http_get(src$url, src$headers)
  txt <- rawToChar(raw)
  txt <- sub("^\ufeff", "", txt)
  first <- substr(trimws(txt), 1L, 1L)
  if (first %in% c("{", "[")) {
    obj <- .epi_json_parse(txt)
    recs <- .epi_json_pick(obj, src$records_path)
    if (is.null(src$records_path) && is.list(recs) && !is.null(names(recs))) {
      # 未给路径时，自动找第一个「对象数组」字段
      cand <- names(recs)[vapply(recs, function(z) is.list(z) && is.null(names(z)), logical(1))]
      if (length(cand)) recs <- recs[[cand[[1L]]]]
    }
    list(data = .epi_records_to_df(recs), encoding = "UTF-8",
         sep = NA_character_, backend = "api:json")
  } else {
    sep <- src$sep %||% if (identical(src$type, "tsv")) "\t" else "\t"
    d <- utils::read.csv(text = txt, sep = sep, stringsAsFactors = FALSE,
                         check.names = FALSE, na.strings = c("", "NA", "-"))
    list(data = d, encoding = "UTF-8", sep = sep, backend = "api:text")
  }
}

# ---- 统一读取分派 -----------------------------------------------

.epi_read_backend <- function(files, src) {
  switch(src$type,
         csv = , tsv = , delim = lapply(files, .read_delim_file, src = src),
         excel = list(.read_excel_src(src)),
         db    = list(.read_db_src(src)),
         api   = list(.read_api_src(src)),
         raster = .epi_stop("栅格源请用 ingest_zonal() 提取协变量，不要直接读表"),
         .epi_stop("不支持的源类型：%s", src$type))
}

# ---- 栅格 zonal 统计 -------------------------------------------

#' 从栅格提取面单元协变量（zonal statistics）
#'
#' 典型用途：把气温、NDVI、PM2.5 等栅格按月提取到地区，作为下游模型的协变量。
#' 需要 terra；缺包时明确报错而非返回空表。
#'
#' @param path 栅格文件路径（GeoTIFF / NetCDF 等）或 SpatRaster
#' @param polygons 面数据：sf / SpatVector / 含 region + 几何列的数据框
#' @param region_col 面数据中的地区编码列名，默认 "region"
#' @param stats 统计量，可多选：mean / sum / min / max / sd
#' @param names_prefix 输出列名前缀，默认 "cov"
#' @param layer 栅格图层名或序号
ingest_zonal <- function(path, polygons, region_col = "region",
                         stats = c("mean"), names_prefix = "cov", layer = NULL) {
  .epi_need("terra", "栅格 zonal 统计")
  r <- if (inherits(path, "SpatRaster")) path else terra::rast(path)
  if (!is.null(layer)) r <- r[[layer]]
  v <- if (inherits(polygons, "SpatVector")) polygons else terra::vect(polygons)
  # SpatVector 的 [[ 只返回首元素，必须先转属性表
  regs <- if (inherits(polygons, "SpatVector")) as.data.frame(polygons)[[region_col]]
          else polygons[[region_col]]
  if (is.null(regs)) .epi_stop("面数据中找不到地区列：%s", region_col)
  if (terra::nrow(v) != length(regs))
    .epi_stop("面数据行数（%d）与地区编码长度（%d）不一致；请检查是否含无效几何",
              terra::nrow(v), length(regs))
  if (!all(stats %in% c("mean", "sum", "min", "max", "sd")))
    .epi_stop("stats 只支持 mean / sum / min / max / sd")

  out <- data.frame(region = as.character(regs), stringsAsFactors = FALSE)
  for (st in stats) {
    e <- terra::extract(r, v, fun = st, na.rm = TRUE, ID = FALSE)
    nm <- names(e)
    for (j in seq_along(nm)) {
      col <- paste0(names_prefix, "_", st)
      if (length(nm) > 1L) col <- paste0(col, "_", nm[[j]])
      out[[col]] <- e[[j]]
    }
  }
  out
}

# ---- 能力自检 ---------------------------------------------------

#' 列出当前环境可用的读取能力
#'
#' 返回 data.frame，available 列为 TRUE/FALSE。缺包时给出 install 提示，
#' 让「为什么这条源读不了」一眼可见，而不是靠猜。
epi_ingest_capabilities <- function() {
  spec <- data.frame(
    capability = c("delimited", "excel", "database", "http_api", "raster_zonal",
                   "hash_sha256", "contract"),
    requires   = c("base R", "readxl", "DBI", "base R", "terra", "openssl | digest", "epiCore"),
    stringsAsFactors = FALSE
  )
  avail <- c(
    TRUE,
    requireNamespace("readxl", quietly = TRUE),
    requireNamespace("DBI", quietly = TRUE),
    capabilities("libcurl") || .Platform$OS.type == "unix",
    requireNamespace("terra", quietly = TRUE),
    requireNamespace("openssl", quietly = TRUE) || requireNamespace("digest", quietly = TRUE),
    requireNamespace("epiCore", quietly = TRUE)
  )
  spec$available <- avail
  spec$note <- ifelse(avail, "可用", paste0("install.packages(\"",
                                            sub(" \\|.*", "", spec$requires), "\")"))
  spec
}
