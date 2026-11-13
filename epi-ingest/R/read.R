# =============================================================
# epiIngest / read.R — 读取与数据画像
#
# ingest_read() 只做一件事：把任意来源变成「标准列 + 原始列 + 读取元数据」。
#   $data 只有契约列（date / region / count / population / disease）
#   $raw  原始列原样保留，追溯时能回看提供方给的每一个字段
#   $meta 编码、分隔符、md5、强制转换失败计数——质控与溯源都靠它
# 不做任何剔除：剔除是 qc_apply() 的职责，边界清晰才好审计。
# =============================================================

.align_bind <- function(lst) {
  if (length(lst) == 1L) return(lst[[1L]])
  cols <- unique(unlist(lapply(lst, names), use.names = FALSE))
  lst <- lapply(lst, function(d) {
    for (m in setdiff(cols, names(d))) d[[m]] <- NA
    d[, cols, drop = FALSE]
  })
  types <- lapply(lst, function(d) vapply(d, function(z) class(z)[[1L]], ""))
  for (j in seq_along(cols)) {
    tj <- unique(vapply(types, `[[`, "", j))
    if (length(tj) > 1L)
      for (i in seq_along(lst)) lst[[i]][[cols[j]]] <- as.character(lst[[i]][[cols[j]]])
  }
  do.call(rbind, lst)
}

.to_standard <- function(raw, mapping) {
  map <- as.list(mapping %||% list())
  for (f in names(EPI_INGEST_ALIASES)) {
    if (is.null(map[[f]]) || is.na(map[[f]]))
      map[[f]] <- .epi_pick_col(names(raw), EPI_INGEST_ALIASES[[f]])
  }
  for (f in c("date", "region", "count")) {
    if (is.na(map[[f]]))
      .epi_stop("找不到 %s 列；请用 mapping 显式指定（现有列：%s）",
                f, paste(names(raw), collapse = ", "))
  }
  date_v <- .epi_parse_date(raw[[map$date]])
  cnt <- .epi_to_numeric(raw[[map$count]])
  out <- data.frame(
    date   = date_v,
    region = trimws(as.character(raw[[map$region]])),
    count  = cnt$value,
    stringsAsFactors = FALSE
  )
  pop_failed <- 0L
  if (!is.na(map$population)) {
    p <- .epi_to_numeric(raw[[map$population]])
    out$population <- p$value
    pop_failed <- p$n_failed
  }
  if (!is.na(map$disease)) out$disease <- trimws(as.character(raw[[map$disease]]))

  attr(out, "coerce") <- list(
    count = cnt$n_failed,
    date = sum(is.na(date_v) & !is.na(raw[[map$date]]) &
                 nzchar(trimws(as.character(raw[[map$date]])))),
    population = pop_failed
  )
  attr(out, "mapping") <- map[!vapply(map, function(z) length(z) == 0L || is.na(z[[1L]]), logical(1))]
  out
}

# 内存表的来源描述：不需要 path，也不能走 ingest_source 的路径校验
.epi_mem_source <- function(label = "<data.frame>") {
  structure(list(type = "data.frame", path = NULL, url = NULL, query = NULL, con = NULL,
                 sheet = NULL, layer = NULL, headers = NULL, records_path = NULL,
                 encoding = "UTF-8", sep = NA_character_, skip = 0L,
                 mapping = NULL, label = label),
            class = "epi_source")
}

#' 读取数据源为标准长表
#'
#' @param x epi_source 对象、文件路径或 data.frame
#' @param ... 传给内部读取函数，暂未使用
ingest_read <- function(x, ...) {
  if (is.data.frame(x)) {
    raw <- as.data.frame(x, stringsAsFactors = FALSE)
    std <- .to_standard(raw, NULL)
    return(structure(
      list(data = std, raw = raw,
           source = .epi_mem_source(),
           meta = list(n_rows = nrow(std), n_files = 0L, files = character(0),
                       encoding = "UTF-8", sep = NA_character_, md5 = character(0),
                       backend = "data.frame", read_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
                       coerce = attr(std, "coerce"), mapping = attr(std, "mapping"))),
      class = "epi_ingest"))
  }

  src <- as_epi_source(x)
  files <- character(0)
  if (src$type %in% c("csv", "tsv", "delim")) {
    files <- .resolve_files(src$path)
    miss <- files[!file.exists(files)]
    if (length(miss)) .epi_stop("文件不存在：%s", paste(miss, collapse = ", "))
  }

  parts <- .epi_read_backend(files, src)
  raw <- .align_bind(lapply(parts, `[[`, "data"))
  if (!nrow(raw)) .epi_stop("读到的表是空的：%s", src$label)
  std <- .to_standard(raw, src$mapping)

  structure(
    list(
      data = std, raw = raw, source = src,
      meta = list(
        n_rows    = nrow(std),
        n_files   = length(parts),
        files     = files,
        encoding  = unique(vapply(parts, `[[`, "", "encoding")),
        sep       = unique(vapply(parts, `[[`, "", "sep")),
        md5       = .epi_md5(files),
        backend   = unique(vapply(parts, `[[`, "", "backend")),
        read_at   = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
        coerce    = attr(std, "coerce"),
        mapping   = attr(std, "mapping")
      )
    ),
    class = "epi_ingest"
  )
}

print.epi_ingest <- function(x, ...) {
  cat(sprintf("<epi_ingest> %d 行 × %d 列 · %s\n",
              nrow(x$data), ncol(x$data), x$source$label))
  cat(sprintf("  编码 %s | 分隔符 %s | 后端 %s\n",
              paste(x$meta$encoding, collapse = "/"),
              paste(ifelse(is.na(x$meta$sep), "-", x$meta$sep), collapse = "/"),
              paste(x$meta$backend, collapse = "/")))
  cf <- unlist(x$meta$coerce)
  if (length(cf) && any(cf > 0))
    cat(sprintf("  强制转换失败：%s\n",
                paste(names(cf)[cf > 0], cf[cf > 0], sep = "=", collapse = ", ")))
  invisible(x)
}

#' 读取前画像
#'
#' 列类型、缺失率、唯一值、日期范围、重复键、无法解析的计数。
#' 给数据提供方看的第一张表，比直接 print(head(df)) 有用得多。
ingest_profile <- function(x, ...) {
  ing <- if (inherits(x, "epi_ingest")) x else ingest_read(x)
  d <- ing$data
  cols <- data.frame(
    column      = names(d),
    class       = vapply(d, function(z) class(z)[[1L]], ""),
    n_missing   = vapply(d, function(z) sum(is.na(z)), integer(1)),
    pct_missing = round(vapply(d, function(z) mean(is.na(z)), 0) * 100, 1),
    n_unique    = vapply(d, function(z) length(unique(z[!is.na(z)])), integer(1)),
    example     = vapply(d, function(z) {
      v <- z[!is.na(z)]
      if (!length(v)) "—" else as.character(v[[1L]])
    }, ""),
    stringsAsFactors = FALSE
  )
  key <- paste(d$date, d$region, sep = "\r")
  structure(
    list(n_rows = nrow(d), n_cols = ncol(d), columns = cols,
         date_range = if (all(is.na(d$date))) as.Date(c(NA, NA)) else range(d$date, na.rm = TRUE),
         duplicate_keys = sum(duplicated(key)),
         n_region = length(unique(d$region[!is.na(d$region)])),
         coerce = ing$meta$coerce,
         encoding = ing$meta$encoding, sep = ing$meta$sep,
         label = ing$source$label),
    class = "epi_ingest_profile"
  )
}

print.epi_ingest_profile <- function(x, ...) {
  cat(sprintf("<epi_ingest_profile> %s\n", x$label))
  cat(sprintf("  %d 行 × %d 列 | 地区 %d 个 | 日期 %s ~ %s | 重复键 %d\n",
              x$n_rows, x$n_cols, x$n_region,
              format(x$date_range[[1L]]), format(x$date_range[[2L]]),
              x$duplicate_keys))
  print(x$columns, row.names = FALSE)
  cf <- unlist(x$coerce)
  if (length(cf) && any(cf > 0))
    cat(sprintf("  无法解析：%s\n", paste(names(cf)[cf > 0], cf[cf > 0], sep = "=", collapse = ", ")))
  invisible(x)
}
