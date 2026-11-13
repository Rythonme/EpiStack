# =============================================================
# epiIngest / source.R — 数据源声明
#
# 一个 epi_source 就是「这份数据从哪来、怎么读」的可序列化描述。
# 声明与读取分开的好处：同一份读取配置可以存进项目文件、
# 在报告里复述，也可以只声明不读（先做能力检查）。
# =============================================================

#' 声明一个数据源
#'
#' @param type 源类型：csv / tsv / delim / excel / db / api / raster
#' @param path 文件或目录路径；目录会读取其中所有 csv/tsv/txt 并纵向合并
#' @param url  HTTP 地址（type = "api"）
#' @param query SQL 查询语句（type = "db"）
#' @param con  DBI 连接对象（type = "db"）
#' @param sheet Excel 工作表名或序号（type = "excel"）
#' @param layer 栅格图层名（type = "raster"）
#' @param headers 命名字符向量，附加 HTTP 请求头
#' @param records_path JSON 响应中记录数组的点路径，如 "result.records"
#' @param encoding "auto" 或显式编码（UTF-8 / GBK / GB18030 ...）
#' @param sep 分隔符；NULL 时按内容嗅探
#' @param skip 跳过开头行数
#' @param mapping 列名映射，如 list(date = "日期", region = "省份", count = "发病数")
#' @param label 可读的数据源名称，默认取文件名
ingest_source <- function(type = c("csv", "tsv", "delim", "excel", "db", "api", "raster"),
                          path = NULL, url = NULL, query = NULL, con = NULL,
                          sheet = NULL, layer = NULL, headers = NULL,
                          records_path = NULL,
                          encoding = "auto", sep = NULL, skip = 0L,
                          mapping = NULL, label = NULL) {
  type <- match.arg(type)

  need <- list(db = "query", api = "url")
  if (type %in% names(need)) {
    if (is.null(get(need[[type]])))
      .epi_stop("%s 源必须提供 %s", type, need[[type]])
  } else if (is.null(path)) {
    .epi_stop("%s 源必须提供 path", type)
  }
  if (type == "db" && is.null(con))
    .epi_stop("db 源必须提供 DBI 连接对象 con")
  if (type == "db" && !inherits(con, "DBIConnection"))
    .epi_stop("con 不是有效的 DBI 连接（收到 %s）", class(con)[[1L]])

  default_label <- basename(path %||% url %||% paste0("query:", substr(query %||% "", 1L, 40L)))

  structure(
    list(type = type, path = path, url = url, query = query, con = con,
         sheet = sheet, layer = layer, headers = headers,
         records_path = records_path,
         encoding = encoding, sep = sep, skip = as.integer(skip),
         mapping = mapping, label = label %||% default_label),
    class = "epi_source"
  )
}

print.epi_source <- function(x, ...) {
  cat(sprintf("<epi_source> %s\n", x$type))
  cat(sprintf("  label    : %s\n", x$label))
  if (!is.null(x$path))
    cat(sprintf("  path     : %s%s\n", paste(utils::head(x$path, 3L), collapse = ", "),
                if (length(x$path) > 3L) sprintf(" (+%d)", length(x$path) - 3L) else ""))
  if (!is.null(x$url))     cat(sprintf("  url      : %s\n", x$url))
  if (!is.null(x$query))   cat(sprintf("  query    : %s\n", substr(gsub("\\s+", " ", x$query), 1L, 70L)))
  if (!is.null(x$sheet))   cat(sprintf("  sheet    : %s\n", x$sheet))
  if (!is.null(x$mapping)) cat(sprintf("  mapping  : %s\n",
                                       paste(names(x$mapping), unlist(x$mapping), sep = "=", collapse = ", ")))
  invisible(x)
}

# 允许 ingest_read("x.csv") 这类简写：按扩展名推断类型。
as_epi_source <- function(x) {
  if (inherits(x, "epi_source")) return(x)
  if (is.character(x) && length(x) >= 1L && all(nzchar(x))) {
    types <- vapply(x, function(p) .epi_file_type(p), "", USE.NAMES = FALSE)
    if (any(is.na(types)) || any(!types %in% c("csv", "tsv", "delim")))
      .epi_stop("无法从扩展名推断文件类型；请显式使用 ingest_source()")
    t <- if (length(unique(types)) == 1L) unique(types) else "delim"
    return(ingest_source(t, path = x))
  }
  .epi_stop("x 必须是 epi_source 或文件路径")
}

# 目录 -> 文件列表；向量 -> 原样；单文件 -> 原样
.resolve_files <- function(p) {
  if (length(p) > 1L) return(p)
  if (dir.exists(p)) {
    f <- list.files(p, pattern = "\\.(csv|tsv|txt)$", full.names = TRUE, ignore.case = TRUE)
    if (!length(f)) .epi_stop("目录中没有 csv/tsv/txt 文件：%s", p)
    return(sort(f))
  }
  p
}
