# =============================================================
# epiRobust / utils.R — 内部工具、输入准备与统计基础
#
# 设计底线与 epiSpace 一致：Imports 只有 stats / utils。所有灵敏度计算
# 都可在 base R 中完成，装不装 spdep / sf / INLA 都能跑。
# Moran 与 LISA 的公式刻意与 epiSpace 逐字一致，保证结果可对照。
# =============================================================

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a

.epi_stop <- function(...) stop(sprintf(...), call. = FALSE)

.robust_warn <- function(...) warning(sprintf(...), call. = FALSE)

.robust_version <- function() {
  tryCatch(as.character(utils::packageVersion("epiRobust")),
           error = function(e) "0.0.0-dev")
}

.robust_escape <- function(s) {
  s <- as.character(s)
  s <- gsub("&", "&amp;", s, fixed = TRUE)
  s <- gsub("<", "&lt;", s, fixed = TRUE)
  s <- gsub(">", "&gt;", s, fixed = TRUE)
  gsub("\"", "&quot;", s, fixed = TRUE)
}

.robust_fmt <- function(v, digits = 4L) {
  ifelse(is.na(v), "-", formatC(v, format = "f", digits = digits))
}

.robust_p <- function(v) {
  ifelse(is.na(v), "-", ifelse(v < 0.001, "<0.001", sprintf("%.4f", v)))
}

.robust_rows_html <- function(df, cols, headers, fmt = list()) {
  if (!nrow(df)) return(sprintf('<tr><td colspan="%d">无</td></tr>', length(cols)))
  body <- vapply(seq_len(nrow(df)), function(i) {
    cells <- vapply(seq_along(cols), function(j) {
      v <- df[[cols[j]]][i]
      f <- fmt[[cols[j]]]
      if (is.function(f)) f(v) else .robust_escape(v)
    }, character(1))
    paste0("<tr>", paste0("<td>", cells, "</td>", collapse = ""), "</tr>")
  }, character(1))
  paste0("<thead><tr>", paste0("<th>", headers, "</th>", collapse = ""),
         "</tr></thead><tbody>", paste(body, collapse = ""), "</tbody>")
}

# 与 epiSpace::.space_prepare 同口径：接受 data.frame 或契约 list。
# geo 优先用 x$geo；没有时才从主表的 row / col 推导。
.robust_prepare <- function(x, region = "region", count = "count",
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
  if (anyNA(d[[count]]))
    .epi_stop("%s 列存在缺失或非数值，请先用上游质控处理", count)
  d[[region]] <- as.character(d[[region]])
  if (anyNA(d[[region]])) .epi_stop("%s 列存在缺失", region)

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

  if (is.null(geo) && all(c("row", "col") %in% names(d))) {
    geo <- unique(d[, c(region, "row", "col"), drop = FALSE])
  }
  if (!is.null(geo)) {
    geo <- as.data.frame(geo, stringsAsFactors = FALSE)
    if (!all(c(region, "row", "col") %in% names(geo))) geo <- NULL
  }
  list(data = d, W = W, geo = geo, region = region, count = count,
       population = population, year = year)
}

# 取某一年、各地区的观测值（率优先），可按给定地区顺序对齐。
.robust_values <- function(p, year_value = NULL, regions = NULL) {
  d <- p$data
  if (!is.null(p$year)) {
    if (is.null(year_value)) year_value <- max(d[[p$year]], na.rm = TRUE)
    d <- d[d[[p$year]] == as.integer(year_value), , drop = FALSE]
    if (!nrow(d)) .epi_stop("指定的 %s = %s 在数据中不存在", p$year, year_value)
  }
  cnt <- tapply(d[[p$count]], d[[p$region]], sum)
  if (!is.null(p$population)) {
    pop <- tapply(d[[p$population]], d[[p$region]], function(z) z[1L])
    values <- as.numeric(cnt) / as.numeric(pop)
  } else {
    pop <- rep(NA_real_, length(cnt))
    values <- as.numeric(cnt)
  }
  if (is.null(regions)) regions <- names(cnt)
  ix <- match(regions, names(cnt))
  if (anyNA(ix)) .epi_stop("地区缺少观测：%s",
                           paste(regions[is.na(ix)], collapse = ", "))
  values <- as.numeric(values[ix])
  names(values) <- as.character(regions)
  list(values = values,
       tot = data.frame(region = as.character(regions),
                        count = as.numeric(cnt[ix]),
                        population = as.numeric(pop[ix]),
                        value = values, stringsAsFactors = FALSE),
       year = year_value, rate_is_count = is.null(p$population))
}

# 与 epiSpace::.space_moran_stat 完全一致
.robust_moran_stat <- function(v, W) {
  z <- v - mean(v)
  (length(v) / sum(W)) * sum(W * outer(z, z)) / sum(z^2)
}

# 与 epiSpace::.space_lisa_stats 完全一致
.robust_lisa_stats <- function(v, W) {
  z <- v - mean(v)
  lag <- as.vector(W %*% z)
  denom <- sum(z^2) / length(v)
  list(Ii = z * lag / denom, lag = lag, z = z)
}

.robust_quadrant <- function(z, lag) {
  ifelse(z >= 0 & lag >= 0, "HH",
  ifelse(z < 0 & lag < 0, "LL",
  ifelse(z >= 0, "HL", "LH")))
}

.robust_check_v <- function(v) {
  if (any(!is.finite(v))) .epi_stop("观测值含缺失或非有限值")
  if (stats::sd(v) == 0) .epi_stop("观测值全部相同，空间统计量无定义")
  invisible(TRUE)
}

# 置换口径与 epiSpace 一致：p = (1 + #{|I_null| >= |I_obs|}) / (n_perm + 1)
.robust_moran_test <- function(v, W, n_perm = 999L, seed = NULL,
                               alternative = c("two.sided", "greater", "less")) {
  alternative <- match.arg(alternative)
  n_perm <- as.integer(n_perm)
  if (n_perm < 0L) .epi_stop("n_perm 不能为负数")
  .robust_check_v(v)
  I_obs <- .robust_moran_stat(v, W)
  I_null <- numeric(0)
  p_val <- NA_real_
  if (n_perm > 0L) {
    if (!is.null(seed)) set.seed(as.integer(seed))
    I_null <- replicate(n_perm, .robust_moran_stat(sample(v), W))
    p_val <- switch(alternative,
      two.sided = (1 + sum(abs(I_null) >= abs(I_obs))) / (n_perm + 1),
      greater   = (1 + sum(I_null >= I_obs)) / (n_perm + 1),
      less      = (1 + sum(I_null <= I_obs)) / (n_perm + 1)
    )
  }
  list(I = I_obs, p = p_val, I_null = I_null, n_perm = n_perm)
}

# 逐地区置换 p 与四象限，口径与 epiSpace::space_lisa() 一致
.robust_lisa_test <- function(v, W, n_perm = 999L, seed = NULL, alpha = 0.05) {
  n_perm <- as.integer(n_perm)
  if (n_perm < 0L) .epi_stop("n_perm 不能为负数")
  .robust_check_v(v)
  st <- .robust_lisa_stats(v, W)
  p_i <- rep(NA_real_, length(v))
  if (n_perm > 0L) {
    if (!is.null(seed)) set.seed(as.integer(seed))
    null <- replicate(n_perm, .robust_lisa_stats(sample(v), W)$Ii)
    if (is.null(dim(null))) null <- matrix(null, nrow = length(v))
    ext <- abs(null) >= matrix(abs(st$Ii), nrow = length(v), ncol = n_perm)
    p_i <- (1 + rowSums(ext)) / (n_perm + 1)
  }
  quad <- .robust_quadrant(st$z, st$lag)
  sig <- !is.na(p_i) & p_i < alpha
  tab <- data.frame(
    region = rownames(W), value = v, z = st$z, spatial_lag = st$lag,
    I_i = st$Ii, p_i = p_i, quadrant = quad, significant = sig,
    stringsAsFactors = FALSE
  )
  list(table = tab, alpha = alpha, n_perm = n_perm,
       hotspots = sum(sig & quad == "HH"),
       coldspots = sum(sig & quad == "LL"),
       outliers = sum(sig & quad %in% c("HL", "LH")))
}
