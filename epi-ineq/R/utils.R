# =============================================================
# epiIneq / utils.R — 内部工具与输入准备
#
# 设计底线：Imports 只有 stats / utils。集中曲线、SII 的加权回归、
# 分解与可达性全在 base R 里算完，不引 ineq / spdep / sf，
# 避免「装不上依赖就整层跑不起来」。
# =============================================================

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a

.epi_stop <- function(...) stop(sprintf(...), call. = FALSE)

.epi_warn <- function(...) warning(sprintf(...), call. = FALSE)

.ineq_version <- function() {
  tryCatch(as.character(utils::packageVersion("epiIneq")),
           error = function(e) "0.0.0-dev")
}

.ineq_escape <- function(s) {
  s <- as.character(s)
  s <- gsub("&", "&amp;", s, fixed = TRUE)
  s <- gsub("<", "&lt;", s, fixed = TRUE)
  s <- gsub(">", "&gt;", s, fixed = TRUE)
  gsub("\"", "&quot;", s, fixed = TRUE)
}

.ineq_fmt <- function(v, digits = 3L) {
  ifelse(is.na(v), "-", formatC(v, format = "f", digits = digits))
}

.ineq_rows_html <- function(df, cols, headers, fmt = list()) {
  if (!nrow(df)) return(sprintf('<tr><td colspan="%d">无</td></tr>', length(cols)))
  body <- vapply(seq_len(nrow(df)), function(i) {
    cells <- vapply(seq_along(cols), function(j) {
      v <- df[[cols[j]]][i]
      f <- fmt[[cols[j]]]
      if (is.function(f)) f(v) else .ineq_escape(v)
    }, character(1))
    paste0("<tr>", paste0("<td>", cells, "</td>", collapse = ""), "</tr>")
  }, character(1))
  paste0("<thead><tr>", paste0("<th>", headers, "</th>", collapse = ""),
         "</tr></thead><tbody>", paste(body, collapse = ""), "</tbody>")
}

# 统一入口：data.frame、契约 list（data / geo）或 epi_contract 对象。
# 只校验与准备，不做任何聚合；聚合在 .ineq_regions()。
.ineq_prepare <- function(x, region = "region", count = "count",
                          population = "population", ses = "ses",
                          year = "year", geo = NULL) {
  d <- NULL
  if (is.data.frame(x)) {
    d <- x
  } else if (is.list(x) && !is.null(x$data)) {
    d <- as.data.frame(x$data, stringsAsFactors = FALSE)
    if (is.null(geo)) geo <- x$geo
  } else {
    .epi_stop("x 必须是 data.frame，或 epiCore::read_counts() 的返回值")
  }
  d <- as.data.frame(d, stringsAsFactors = FALSE)
  miss <- setdiff(c(region, count), names(d))
  if (length(miss))
    .epi_stop("缺少必要列：%s（先用 epiCore::read_counts() 转成契约）",
              paste(miss, collapse = ", "))
  d[[count]] <- suppressWarnings(as.numeric(d[[count]]))
  if (anyNA(d[[count]]) || any(d[[count]] < 0))
    .epi_stop("%s 列存在缺失、非数值或负数，请先用上游质控处理", count)
  d[[region]] <- as.character(d[[region]])
  if (anyNA(d[[region]])) .epi_stop("%s 列存在缺失", region)

  for (nm in c(population, ses)) {
    if (!is.null(nm) && nm %in% names(d)) {
      d[[nm]] <- suppressWarnings(as.numeric(d[[nm]]))
    }
  }
  if (!is.null(population) && population %in% names(d) &&
      any(!is.finite(d[[population]]) | d[[population]] <= 0))
    .epi_stop("%s 列必须为正数", population)

  if (!is.null(year) && year %in% names(d)) {
    d[[year]] <- suppressWarnings(as.integer(d[[year]]))
    if (anyNA(d[[year]])) .epi_stop("%s 列存在无法解析的年份", year)
  } else {
    year <- NULL
  }
  if (!is.null(geo) && !is.data.frame(geo) && is.list(geo))
    geo <- as.data.frame(geo, stringsAsFactors = FALSE)
  list(data = d, geo = geo, region = region, count = count,
       population = population, ses = ses, year = year)
}

# 从地区元数据里找 SES 与坐标。支持 x/y、row/col、lon/lat 三种常见列名。
.ineq_meta <- function(geo, region = "region", ses = "ses") {
  out <- list(ses = NULL, x = NULL, y = NULL)
  if (is.null(geo) || !nrow(geo)) return(out)
  if (!(region %in% names(geo)))
    .epi_stop("geo 缺少 %s 列，无法按地区匹配 SES 与坐标", region)
  if (!is.null(ses) && ses %in% names(geo)) {
    s <- suppressWarnings(as.numeric(geo[[ses]]))
    names(s) <- as.character(geo[[region]])
    out$ses <- s
  }
  xnm <- intersect(c("x", "row", "lon", "long", "longitude"), names(geo))[1L]
  ynm <- intersect(c("y", "col", "lat", "latitude"), names(geo))[1L]
  if (!is.na(xnm) && !is.na(ynm)) {
    xx <- suppressWarnings(as.numeric(geo[[xnm]]))
    yy <- suppressWarnings(as.numeric(geo[[ynm]]))
    if (all(is.finite(xx)) && all(is.finite(yy))) {
      names(xx) <- names(yy) <- as.character(geo[[region]])
      out$x <- xx
      out$y <- yy
    }
  }
  out
}

# 聚合到「一个地区一行」。多年数据默认取最新年；也可用 year_value 指定。
# 返回列：region / count / population / rate / ses / x / y，地区顺序不变。
.ineq_regions <- function(p, year_value = NULL) {
  d <- p$data
  yr <- p$year
  if (!is.null(yr)) {
    if (is.null(year_value)) year_value <- max(d[[yr]], na.rm = TRUE)
    d <- d[d[[yr]] == as.integer(year_value), , drop = FALSE]
    if (!nrow(d))
      .epi_stop("指定的 %s = %s 在数据中不存在", yr, year_value)
  }
  regs <- unique(d[[p$region]])
  cnt <- tapply(d[[p$count]], d[[p$region]], sum)
  cnt <- as.numeric(cnt[match(regs, names(cnt))])

  pop <- NULL
  if (!is.null(p$population) && p$population %in% names(d)) {
    pop <- tapply(d[[p$population]], d[[p$region]], function(z) z[1L])
    pop <- as.numeric(pop[match(regs, names(pop))])
  }
  if (is.null(pop) || anyNA(pop) || any(pop <= 0))
    .epi_stop("每个地区必须有正的人口分母（%s 列）", p$population)

  meta <- .ineq_meta(p$geo, p$region, p$ses)
  ses <- rep(NA_real_, length(regs))
  if (!is.null(p$ses) && p$ses %in% names(d)) {
    sv <- tapply(d[[p$ses]], d[[p$region]], function(z) z[1L])
    ses <- as.numeric(sv[match(regs, names(sv))])
  }
  if (!is.null(meta$ses)) {
    mv <- meta$ses[match(regs, names(meta$ses))]
    use <- is.na(ses) & is.finite(mv)
    ses[use] <- mv[use]
  }
  if (anyNA(ses))
    .epi_stop("以下地区缺少 SES：%s",
              paste(regs[is.na(ses)], collapse = ", "))

  xx <- if (!is.null(meta$x)) as.numeric(meta$x[match(regs, names(meta$x))]) else rep(NA_real_, length(regs))
  yy <- if (!is.null(meta$y)) as.numeric(meta$y[match(regs, names(meta$y))]) else rep(NA_real_, length(regs))
  # 契约表自身也可能带坐标列（如 ineq_example() 的 x / y），优先取
  for (nm in c("x", "row", "lon", "long", "longitude")) {
    if (nm %in% names(d) && anyNA(xx)) {
      v <- tapply(suppressWarnings(as.numeric(d[[nm]])), d[[p$region]], function(z) z[1L])
      xx <- as.numeric(v[match(regs, names(v))])
    }
  }
  for (nm in c("y", "col", "lat", "latitude")) {
    if (nm %in% names(d) && anyNA(yy)) {
      v <- tapply(suppressWarnings(as.numeric(d[[nm]])), d[[p$region]], function(z) z[1L])
      yy <- as.numeric(v[match(regs, names(v))])
    }
  }

  tot <- data.frame(
    region = regs, count = cnt, population = pop,
    rate = cnt / pop, ses = ses, x = xx, y = yy,
    stringsAsFactors = FALSE
  )
  list(tot = tot, year = year_value)
}

# 用 SES 与一个数值向量算加权集中曲线。曲线点与旧切片同口径：
# 按 SES 升序，横轴为人口累积份额，纵轴为结局累积份额。
.ineq_curve_df <- function(ses, population, value, region = NULL) {
  o <- order(ses)
  pp <- population[o]
  yy <- value[o]
  cp <- c(0, cumsum(pp) / sum(pp))
  cy <- c(0, cumsum(yy) / sum(yy))
  rn <- names(ses)
  if (is.null(rn)) rn <- region
  if (is.null(rn)) rn <- seq_along(ses)
  data.frame(
    region = rn[o],
    ses = ses[o], population = pp, value = yy,
    cum_pop = cp[-1L], cum_value = cy[-1L],
    stringsAsFactors = FALSE
  )
}

# 梯形面积（与旧切片逐位一致）
.ineq_area <- function(cp, cy) {
  sum((cp[-1L] - cp[-length(cp)]) * (cy[-1L] + cy[-length(cy)]) / 2)
}

# 允许传 curve、或 tot + 列名；统一返回曲线数据框
.as_curve <- function(x, region = "region", population = "population",
                      value = "count", ses = "ses") {
  if (inherits(x, "epi_ineq_curve")) return(x$curve)
  if (is.data.frame(x) && all(c("cum_pop", "cum_value") %in% names(x))) {
    if (!all(c("ses", population, value) %in% names(x)))
      return(x)
    d <- x
  } else {
    d <- .ineq_regions(.ineq_prepare(x, region = region, count = value,
                                     population = population, ses = ses))$tot
  }
  rg <- d$region
  if (is.null(rg)) rg <- names(d$ses)
  .ineq_curve_df(d$ses, d[[population]], d[[value]], region = rg)
}

#' @export
print.epi_ineq <- function(x, ...) {
  cat(sprintf("epiIneq 分析结果 ｜ %d 地区 ｜ 契约口径 %s\n",
              x$meta$n %||% NA_integer_, x$meta$year %||% "最新"))
  if (!is.null(x$core)) {
    cat(sprintf("  CI = %.4f ｜ SII = %.4f ｜ 低/高 SES 率比 = %.2f\n",
                x$core$CI, x$core$SII, x$core$rate_ratio))
  }
  invisible(x)
}

#' @export
print.epi_ineq_curve <- function(x, ...) {
  cat(sprintf("集中曲线 ｜ %d 点 ｜ CI = %.4f\n", nrow(x$curve), x$CI))
  print(utils::head(x$curve, 6L), row.names = FALSE)
  invisible(x)
}
