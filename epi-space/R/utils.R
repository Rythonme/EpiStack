# =============================================================
# epiSpace / utils.R — 内部工具与输入准备
#
# 设计底线：Imports 只有 stats / utils。全局与局部自相关、置换检验、
# 热点分类全在 base R 里算完，不引 spdep / sf / INLA，避免「装不上就
# 整层跑不起来」。需要真实边界时，用 epiCore::epi_read_graph() 读邻接表。
# =============================================================

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a

.epi_stop <- function(...) stop(sprintf(...), call. = FALSE)

.space_version <- function() {
  tryCatch(as.character(utils::packageVersion("epiSpace")),
           error = function(e) "0.0.0-dev")
}

.space_escape <- function(s) {
  s <- as.character(s)
  s <- gsub("&", "&amp;", s, fixed = TRUE)
  s <- gsub("<", "&lt;", s, fixed = TRUE)
  s <- gsub(">", "&gt;", s, fixed = TRUE)
  gsub("\"", "&quot;", s, fixed = TRUE)
}

.space_fmt <- function(v, digits = 3L) {
  ifelse(is.na(v), "-", formatC(v, format = "f", digits = digits))
}

.space_rows_html <- function(df, cols, headers, fmt = list()) {
  if (!nrow(df)) return(sprintf('<tr><td colspan="%d">无</td></tr>', length(cols)))
  body <- vapply(seq_len(nrow(df)), function(i) {
    cells <- vapply(seq_along(cols), function(j) {
      v <- df[[cols[j]]][i]
      f <- fmt[[cols[j]]]
      if (is.function(f)) f(v) else .space_escape(v)
    }, character(1))
    paste0("<tr>", paste0("<td>", cells, "</td>", collapse = ""), "</tr>")
  }, character(1))
  paste0("<thead><tr>", paste0("<th>", headers, "</th>", collapse = ""),
         "</tr></thead><tbody>", paste(body, collapse = ""), "</tbody>")
}

# 统一入口：接受 data.frame、契约 list（含 data / W / geo）或
# epiCore::read_counts() 的 epi_contract 对象。只校验与准备，不改数据。
.space_prepare <- function(x, region = "region", count = "count",
                           population = "population", year = "year") {
  d <- NULL; W <- NULL; geo <- NULL
  if (is.data.frame(x)) {
    d <- x
  } else if (is.list(x) && !is.null(x$data)) {
    d <- as.data.frame(x$data, stringsAsFactors = FALSE)
    W <- x$W
    geo <- x$geo
  } else {
    .epi_stop("x 必须是 data.frame，或 epiCore::read_counts() 的返回值")
  }
  d <- as.data.frame(d, stringsAsFactors = FALSE)
  need <- c(region, count)
  miss <- setdiff(need, names(d))
  if (length(miss))
    .epi_stop("缺少必要列：%s（先用 epiCore::read_counts() 转成契约）",
              paste(miss, collapse = ", "))
  d[[count]] <- suppressWarnings(as.numeric(d[[count]]))
  if (any(is.na(d[[count]])))
    .epi_stop("%s 列存在缺失或非数值，请先用上游质控处理", count)
  d[[region]] <- as.character(d[[region]])
  if (anyNA(d[[region]]))
    .epi_stop("%s 列存在缺失", region)

  if (!is.null(population) && population %in% names(d)) {
    d[[population]] <- suppressWarnings(as.numeric(d[[population]]))
    if (any(!is.finite(d[[population]]) | d[[population]] <= 0))
      .epi_stop("%s 列必须为正数", population)
  } else {
    population <- NULL
  }
  if (!is.null(year) && year %in% names(d)) {
    d[[year]] <- suppressWarnings(as.integer(d[[year]]))
    if (anyNA(d[[year]])) .epi_stop("%s 列存在无法解析的年份", year)
  } else {
    year <- NULL
  }
  list(data = d, W = W, geo = geo, region = region, count = count,
       population = population, year = year)
}

# 从契约表取「某一年、各地区」的观测值，并按 W 的地区顺序对齐。
# 不传 W 时按地区首次出现顺序。返回 rate = count / population；
# 没有 population 列时退化为 count（并在 meta 里说明）。
.space_values <- function(p, year_value = NULL, W = NULL) {
  d <- p$data
  yr <- p$year
  if (is.null(yr) && !is.null(year_value))
    .epi_stop("数据没有年份列，不能指定 year_value = %s", year_value)
  if (!is.null(yr)) {
    if (is.null(year_value)) year_value <- max(d[[yr]], na.rm = TRUE)
    d <- d[d[[yr]] == as.integer(year_value), , drop = FALSE]
    if (!nrow(d))
      .epi_stop("指定的 %s = %s 在数据中不存在", yr, year_value)
  }
  regs <- if (is.null(W)) unique(d[[p$region]]) else rownames(W)
  if (is.null(regs) || !length(regs)) .epi_stop("地区列表为空")

  cnt <- tapply(d[[p$count]], d[[p$region]], sum)
  cnt <- cnt[match(regs, names(cnt))]
  if (anyNA(cnt))
    .epi_stop("W 中的地区在契约表里没有观测：%s",
              paste(regs[is.na(cnt)], collapse = ", "))

  if (!is.null(p$population)) {
    pop <- tapply(d[[p$population]], d[[p$region]], function(z) z[1L])
    pop <- pop[match(regs, names(pop))]
    if (anyNA(pop))
      .epi_stop("W 中的地区缺少人口数：%s", paste(regs[is.na(pop)], collapse = ", "))
    values <- as.numeric(cnt) / as.numeric(pop)
  } else {
    pop <- rep(NA_real_, length(regs))
    values <- as.numeric(cnt)
  }
  names(values) <- regs
  tot <- data.frame(
    region = regs,
    count = as.numeric(cnt),
    population = as.numeric(pop),
    value = values,
    stringsAsFactors = FALSE
  )
  list(values = values, tot = tot, year = year_value,
       rate_is_count = is.null(p$population))
}
