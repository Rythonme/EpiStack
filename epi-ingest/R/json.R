# =============================================================
# epiIngest / json.R — 极简 JSON 读写（base R，零依赖）
#
# 用途有两个，都要求「只装 base R 也能跑」：
#   1. 质控规则集存成 JSON 随项目走（换口径改文件，不改包）；
#   2. API 适配器解析常见结构的 JSON 响应，避免为读一个数组装 jsonlite。
# 只覆盖对象 / 数组 / 字符串 / 数值 / 布尔 / null 的标准子集。
# =============================================================

.epi_json_parse <- function(txt) {
  s <- paste(txt, collapse = "\n")
  ch <- strsplit(s, "", fixed = TRUE)[[1L]]
  n  <- length(ch)
  pos <- 1L

  peek <- function() if (pos <= n) ch[pos] else ""
  skip_ws <- function() {
    while (pos <= n && ch[pos] %in% c(" ", "\t", "\r", "\n")) pos <<- pos + 1L
  }
  parse_string <- function() {
    pos <<- pos + 1L
    out <- character(0)
    while (pos <= n) {
      c1 <- ch[pos]
      if (c1 == "\"") { pos <<- pos + 1L; break }
      if (c1 == "\\") {
        pos <<- pos + 1L
        e <- ch[pos]
        out <- c(out, switch(e,
                             "\"" = "\"", "\\" = "\\", "/" = "/",
                             "b" = "\b", "f" = "\f", "n" = "\n",
                             "r" = "\r", "t" = "\t", e))
      } else {
        out <- c(out, c1)
      }
      pos <<- pos + 1L
    }
    paste0(out, collapse = "")
  }
  parse_number <- function() {
    st <- pos
    while (pos <= n && grepl("[-+0-9.eE]", ch[pos])) pos <<- pos + 1L
    as.numeric(paste0(ch[st:(pos - 1L)], collapse = ""))
  }
  parse_value <- function() {
    skip_ws()
    c1 <- peek()
    if (c1 == "{") return(parse_object())
    if (c1 == "[") return(parse_array())
    if (c1 == "\"") return(parse_string())
    if (c1 == "t") { pos <<- pos + 4L; return(TRUE) }
    if (c1 == "f") { pos <<- pos + 5L; return(FALSE) }
    if (c1 == "n") { pos <<- pos + 4L; return(NULL) }
    parse_number()
  }
  parse_object <- function() {
    pos <<- pos + 1L
    res <- list()
    repeat {
      skip_ws()
      if (peek() == "}") { pos <<- pos + 1L; break }
      key <- parse_string()
      skip_ws()
      pos <<- pos + 1L
      res[key] <- list(parse_value())   # 用 [<- list() 才能存住 null
      skip_ws()
      if (peek() == ",") pos <<- pos + 1L
    }
    res
  }
  parse_array <- function() {
    pos <<- pos + 1L
    res <- list()
    repeat {
      skip_ws()
      if (peek() == "]") { pos <<- pos + 1L; break }
      res[[length(res) + 1L]] <- parse_value()
      skip_ws()
      if (peek() == ",") pos <<- pos + 1L
    }
    res
  }
  parse_value()
}

.epi_json_stringify <- function(x, pretty = TRUE) {
  esc_str <- function(s) {
    cc <- strsplit(as.character(s), "", fixed = TRUE)[[1L]]
    cc <- vapply(cc, function(z) switch(z,
                                        "\\" = "\\\\", "\"" = "\\\"",
                                        "\n" = "\\n", "\r" = "\\r",
                                        "\t" = "\\t", z), character(1))
    paste0("\"", paste0(cc, collapse = ""), "\"")
  }
  ser <- function(v, lv) {
    if (is.null(v)) return("null")
    if (is.list(v)) {
      nm <- names(v)
      is_obj <- !is.null(nm) && all(nzchar(nm))
      if (length(v) == 0L) return(if (is_obj) "{}" else "[]")
      items <- vapply(seq_along(v), function(i) {
        val <- ser(v[[i]], lv + 1L)
        if (is_obj) paste0(esc_str(nm[i]), ": ", val) else val
      }, character(1))
      op <- if (is_obj) "{" else "["; cl <- if (is_obj) "}" else "]"
      if (!pretty) return(paste0(op, paste(items, collapse = ","), cl))
      pad <- strrep("  ", lv + 1L); pad_end <- strrep("  ", lv)
      return(paste0(op, "\n", paste0(pad, items, collapse = ",\n"), "\n", pad_end, cl))
    }
    if (length(v) == 0L) return("[]")
    if (length(v) > 1L)
      return(paste0("[", paste(vapply(v, ser, character(1), lv = lv), collapse = ", "), "]"))
    if (is.na(v)) return("null")
    if (is.logical(v)) return(if (isTRUE(v)) "true" else "false")
    if (is.numeric(v)) return(format(v, digits = 15, scientific = FALSE, trim = TRUE))
    esc_str(v)
  }
  ser(x, 0L)
}

.epi_json_read <- function(path) {
  if (!file.exists(path)) .epi_stop("文件不存在：%s", path)
  .epi_json_parse(readLines(path, warn = FALSE, encoding = "UTF-8"))
}

.epi_json_write <- function(x, path, pretty = TRUE) {
  d <- dirname(path)
  if (nzchar(d)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
  writeLines(enc2utf8(.epi_json_stringify(x, pretty)), path, useBytes = TRUE)
  invisible(path)
}

# 点路径取数：records_path = "result.records"
.epi_json_pick <- function(x, path) {
  if (is.null(path) || !nzchar(path)) return(x)
  for (k in strsplit(path, ".", fixed = TRUE)[[1L]]) {
    if (!is.list(x) || is.null(x[[k]])) .epi_stop("JSON 中找不到路径：%s", path)
    x <- x[[k]]
  }
  x
}

# list of flat records -> data.frame，保持首次出现顺序，缺失补 NA
.epi_records_to_df <- function(recs) {
  if (!is.list(recs) || !length(recs)) .epi_stop("JSON 记录数组为空")
  if (!is.null(names(recs))) recs <- list(recs)          # 单对象
  cols <- unique(unlist(lapply(recs, names), use.names = FALSE))
  out <- lapply(cols, function(cn) {
    v <- lapply(recs, function(r) {
      z <- r[[cn]]
      if (is.null(z) || length(z) == 0L) NA
      else if (is.list(z)) paste(unlist(z), collapse = ";")
      else z[[1L]]
    })
    v <- unlist(v, use.names = FALSE)
    if (is.character(v) || all(is.na(v))) v else suppressWarnings(as.numeric(v))
  })
  names(out) <- cols
  as.data.frame(out, stringsAsFactors = FALSE, check.names = FALSE)
}
