# =============================================================
# epiIngest / qc.R — 声明式质控
#
# 三条写死的规则：
#   1. 规则是数据不是代码：qc_rules() 产出可序列化的规则集，
#      存成 JSON 随项目走，换口径改文件、不改包。
#   2. 分级明确：error 一律剔除，warn 默认保留并标记，
#      info 只记录。绝不给「悄悄当错误处理」留隐式行为。
#   3. 逐行留痕：每条命中都记到行号，能追回原始表的哪一行。
# =============================================================

#' 构造质控规则集
#'
#' @param required 必填列名
#' @param unique_key 唯一键列（重复时保留首条，其余按 error 处理）
#' @param range 数值范围，如 list(count = c(0, 1e7))
#' @param date_seq 日期连续性，如 list(by = "month", max_gap = 1)
#' @param region_code 地区码白名单，如 list(allowed = geo$region)
#' @param outlier 异常值，如 list(method = "mad", k = 8)
#' @param cross_field 跨字段一致性，如 list(list(lhs = "count", op = "<=", rhs = "population"))
#' @param name 规则集名称，写进报告便于追溯
qc_rules <- function(required = c("date", "region", "count"),
                     unique_key = NULL, range = NULL, date_seq = NULL,
                     region_code = NULL, outlier = NULL, cross_field = NULL,
                     name = NULL) {
  required <- as.character(unlist(required %||% character(0)))
  if (length(unique_key)) unique_key <- as.character(unlist(unique_key))
  if (!is.null(region_code)) region_code$allowed <- as.character(unlist(region_code$allowed))
  if (!is.null(date_seq)) {
    date_seq$by <- as.character(unlist(date_seq$by %||% "month"))
    date_seq$max_gap <- as.numeric(unlist(date_seq$max_gap %||% 1))
    if (!date_seq$by %in% c("week", "month", "quarter", "year"))
      .epi_stop("date_seq$by 只支持 week / month / quarter / year")
  }
  if (!is.null(outlier)) {
    outlier$method <- as.character(unlist(outlier$method %||% "mad"))
    outlier$k <- as.numeric(unlist(outlier$k %||% 6))
    if (!outlier$method %in% c("mad", "iqr"))
      .epi_stop("outlier$method 只支持 mad / iqr")
  }
  if (!is.null(range)) {
    for (nm in names(range)) {
      lim <- as.numeric(unlist(range[[nm]]))
      if (length(lim) != 2L || any(!is.finite(lim)))
        .epi_stop("range$%s 必须是两个有限数（下界, 上界）", nm)
      range[[nm]] <- lim
    }
  }
  if (!is.null(cross_field)) {
    for (cf in cross_field) {
      if (is.null(cf$lhs) || is.null(cf$rhs) || is.null(cf$op))
        .epi_stop("cross_field 每项必须含 lhs / op / rhs")
      if (!cf$op %in% c("<=", "<", "==", ">=", ">", "!="))
        .epi_stop("cross_field$op 不支持：%s", cf$op)
    }
  }
  structure(
    list(name = name, required = required, unique_key = unique_key, range = range,
         date_seq = date_seq, region_code = region_code,
         outlier = outlier, cross_field = cross_field),
    class = "epi_qc_rules"
  )
}

print.epi_qc_rules <- function(x, ...) {
  cat(sprintf("<epi_qc_rules>%s\n", if (is.null(x$name)) "" else paste0(" ", x$name)))
  cat(sprintf("  required   : %s\n", paste(x$required, collapse = ", ")))
  cat(sprintf("  unique_key : %s\n", paste(x$unique_key %||% "-", collapse = "+")))
  cat(sprintf("  range      : %s\n",
              if (length(x$range)) paste(names(x$range), collapse = ", ") else "-"))
  cat(sprintf("  date_seq   : %s\n",
              if (is.null(x$date_seq)) "-" else
                sprintf("%s, max_gap=%s", x$date_seq$by, x$date_seq$max_gap)))
  cat(sprintf("  region_code: %s\n",
              if (is.null(x$region_code)) "-" else
                sprintf("%d 个白名单地区", length(x$region_code$allowed))))
  cat(sprintf("  outlier    : %s\n",
              if (is.null(x$outlier)) "-" else
                sprintf("%s, k=%s", x$outlier$method, x$outlier$k)))
  cat(sprintf("  cross_field: %d 条\n", length(x$cross_field %||% list())))
  invisible(x)
}

#' 规则集存成 JSON，随项目版本管理
qc_rules_write <- function(rules, path) {
  if (!inherits(rules, "epi_qc_rules")) .epi_stop("rules 必须是 qc_rules() 的返回值")
  obj <- list(
    format_version = "1",
    name = rules$name %||% "qc-rules",
    required = as.list(rules$required),
    unique_key = if (length(rules$unique_key)) as.list(rules$unique_key),
    range = rules$range,
    date_seq = rules$date_seq,
    region_code = rules$region_code,
    outlier = rules$outlier,
    cross_field = rules$cross_field
  )
  obj <- obj[!vapply(obj, is.null, logical(1))]
  .epi_json_write(obj, path)
  invisible(path)
}

#' 从 JSON 读回规则集
qc_rules_read <- function(path) {
  if (!file.exists(path)) .epi_stop("规则文件不存在：%s", path)
  obj <- .epi_json_read(path)
  qc_rules(required = obj$required %||% c("date", "region", "count"),
           unique_key = obj$unique_key,
           range = obj$range,
           date_seq = obj$date_seq,
           region_code = obj$region_code,
           outlier = obj$outlier,
           cross_field = obj$cross_field,
           name = obj$name)
}

#' 包内默认规则集
#'
#' 默认只做「任何数据都该过」的检查：必填、唯一键、非负计数、日期连续、MAD 异常值。
#' 地区白名单与跨字段一致性需要 geo 表，按需传入。
ingest_qc_default <- function(geo = NULL, outlier_k = 8) {
  p <- system.file("rules", "qc_default.json", package = "epiIngest")
  # 源码模式（未安装）时由 bootstrap_ingest.R 指定规则目录
  if (!nzchar(p)) {
    rd <- getOption("epiIngest.rules_dir", "")
    if (nzchar(rd) && file.exists(file.path(rd, "qc_default.json")))
      p <- file.path(rd, "qc_default.json")
  }
  rules <- if (nzchar(p) && file.exists(p)) qc_rules_read(p)
           else qc_rules(date_seq = list(by = "month", max_gap = 1),
                         range = list(count = c(0, 1e7)),
                         outlier = list(method = "mad", k = outlier_k),
                         name = "epi-default-fallback")
  if (!is.null(geo)) {
    allowed <- if (is.data.frame(geo)) as.character(geo$region) else as.character(geo)
    rules$region_code <- list(allowed = allowed)
  }
  if (!is.null(outlier_k)) rules$outlier$k <- as.numeric(outlier_k)
  rules
}

# ---- 全局 warn 策略 --------------------------------------------

#' 设置/读取全局的 warn 处理方式
#'
#' \code{keep}（默认）保留并标记；\code{drop} 直接剔除；\code{error} 一旦命中即报错。
#' 传 NULL 只读取不修改。返回修改前的设置，便于临时切换后还原。
ingest_on_warn <- function(level = NULL) {
  cur <- getOption("epiIngest.on_warn", "keep")
  if (is.null(level)) return(cur)
  level <- as.character(level[[1L]])
  if (!level %in% c("keep", "drop", "error"))
    .epi_stop("on_warn 只支持 keep / drop / error，收到：%s", level)
  old <- cur
  options(epiIngest.on_warn = level)
  invisible(old)
}

.epi_resolve_on_warn <- function(on_warn) {
  if (is.null(on_warn)) return(getOption("epiIngest.on_warn", "keep"))
  on_warn <- as.character(on_warn[[1L]])
  if (!on_warn %in% c("keep", "drop", "error"))
    .epi_stop("on_warn 只支持 keep / drop / error，收到：%s", on_warn)
  on_warn
}

.empty_masks <- function() {
  data.frame(rule = character(0), level = character(0), row = integer(0),
             detail = character(0), stringsAsFactors = FALSE)
}

#' 执行规则集
#'
#' @param x epi_ingest 对象、数据源或 data.frame
#' @param rules qc_rules() 的返回值，或规则 JSON 路径
#' @param on_warn warn 级命中如何处理；NULL 表示用全局设置（见 ingest_on_warn）
qc_apply <- function(x, rules = NULL, on_warn = NULL) {
  if (is.character(rules) && length(rules) == 1L) rules <- qc_rules_read(rules)
  rules <- rules %||% ingest_qc_default()
  if (!inherits(rules, "epi_qc_rules")) .epi_stop("rules 必须是 qc_rules() 的返回值或规则文件路径")
  on_warn <- .epi_resolve_on_warn(on_warn)

  ing <- if (inherits(x, "epi_ingest")) x else ingest_read(x)
  d <- ing$data
  n <- nrow(d)
  fl <- list()

  add <- function(rule, level, idx, detail = "") {
    idx <- which(idx)
    if (!length(idx)) return(invisible(NULL))
    fl[[length(fl) + 1L]] <<- data.frame(rule = rule, level = level,
                                        row = idx, detail = detail,
                                        stringsAsFactors = FALSE)
    invisible(NULL)
  }

  # 1. 必填
  for (col in rules$required) {
    if (!col %in% names(d)) .epi_stop("规则引用了不存在的列：%s", col)
    v <- d[[col]]
    bad <- is.na(v) | (is.character(v) & !nzchar(trimws(v)))
    add(paste0("required:", col), "error", bad, "必填为空")
  }

  # 2. 唯一键：保留首条，其余剔除
  if (length(rules$unique_key)) {
    miss <- setdiff(rules$unique_key, names(d))
    if (length(miss)) .epi_stop("unique_key 引用了不存在的列：%s", paste(miss, collapse = ", "))
    key <- do.call(paste, c(d[rules$unique_key], sep = "\r"))
    add("unique_key", "error", duplicated(key),
        paste0(paste(rules$unique_key, collapse = "+"), "（保留首条）"))
  }

  # 3. 数值范围
  for (col in names(rules$range)) {
    if (!col %in% names(d)) .epi_stop("range 引用了不存在的列：%s", col)
    lim <- rules$range[[col]]
    v <- d[[col]]
    bad <- !is.na(v) & (v < lim[[1L]] | v > lim[[2L]])
    add(paste0("range:", col), "error", bad,
        sprintf("允许区间 [%s, %s]", format(lim[[1L]]), format(lim[[2L]])))
  }

  # 4. 日期：未来日期（error）+ 序列断档（warn）
  if (!is.null(rules$date_seq)) {
    add("date:future", "error", !is.na(d$date) & d$date > Sys.Date(), "晚于今天")
    by <- rules$date_seq$by
    step <- c(week = 7, month = 31, quarter = 92, year = 366)[[by]]
    gap_max <- rules$date_seq$max_gap * step * 1.2
    bad <- logical(n)
    for (r in unique(d$region)) {
      i <- which(d$region == r & !is.na(d$date))
      if (length(i) < 2L) next
      i <- i[order(d$date[i])]
      dd <- as.numeric(diff(d$date[i]))
      hit <- which(dd > gap_max)
      if (length(hit)) bad[i[hit + 1L]] <- TRUE
    }
    add("date:gap", "warn", bad, sprintf("%s 粒度间隔 > %.0f 天", by, gap_max))
  }

  # 5. 地区码白名单
  if (!is.null(rules$region_code)) {
    allowed <- rules$region_code$allowed
    bad <- !is.na(d$region) & nzchar(d$region) & !(d$region %in% allowed)
    add("region_code", "error", bad, sprintf("不在 %d 个白名单地区内", length(allowed)))
  }

  # 6. 异常值
  if (!is.null(rules$outlier)) {
    v <- d$count
    med <- stats::median(v, na.rm = TRUE)
    if (rules$outlier$method == "mad") {
      s <- stats::mad(v, na.rm = TRUE)          # mad() 已乘 1.4826
      if (is.finite(s) && s > 0)
        add("outlier:mad", "warn", !is.na(v) & abs(v - med) / s > rules$outlier$k,
            sprintf("MAD 分数 > %s", rules$outlier$k))
    } else {
      q <- stats::quantile(v, c(0.25, 0.75), na.rm = TRUE)
      iqr <- q[[2L]] - q[[1L]]
      if (is.finite(iqr) && iqr > 0) {
        lo <- q[[1L]] - rules$outlier$k * iqr
        hi <- q[[2L]] + rules$outlier$k * iqr
        add("outlier:iqr", "warn", !is.na(v) & (v < lo | v > hi),
            sprintf("超出 %s 倍 IQR", rules$outlier$k))
      }
    }
  }

  # 7. 跨字段一致性
  for (cf in rules$cross_field %||% list()) {
    miss <- setdiff(c(cf$lhs, cf$rhs), names(d))
    if (length(miss)) .epi_stop("cross_field 引用了不存在的列：%s", paste(miss, collapse = ", "))
    lhs <- d[[cf$lhs]]; rhs <- d[[cf$rhs]]
    bad <- switch(cf$op,
                  "<=" = !is.na(lhs) & !is.na(rhs) & lhs > rhs,
                  "<"  = !is.na(lhs) & !is.na(rhs) & lhs >= rhs,
                  ">=" = !is.na(lhs) & !is.na(rhs) & lhs < rhs,
                  ">"  = !is.na(lhs) & !is.na(rhs) & lhs <= rhs,
                  "==" = !is.na(lhs) & !is.na(rhs) & lhs != rhs,
                  "!=" = !is.na(lhs) & !is.na(rhs) & lhs == rhs)
    add(paste0("cross:", cf$lhs, cf$op, cf$rhs), "error", bad,
        sprintf("%s %s %s", cf$lhs, cf$op, cf$rhs))
  }

  masks <- if (length(fl)) do.call(rbind, fl) else .empty_masks()

  if (on_warn == "error" && any(masks$level == "warn")) {
    w <- unique(masks$rule[masks$level == "warn"])
    .epi_stop("on_warn = \"error\"：warn 级规则命中（%s），已中止；共 %d 行",
              paste(w, collapse = ", "), length(unique(masks$row[masks$level == "warn"])))
  }

  drop_levels <- if (on_warn == "drop") c("error", "warn") else "error"
  drop_rows <- sort(unique(masks$row[masks$level %in% drop_levels]))
  clean <- if (length(drop_rows)) d[-drop_rows, , drop = FALSE] else d
  rownames(clean) <- NULL

  report <- if (nrow(masks)) {
    key <- paste(masks$rule, masks$level, sep = "\r")
    ord <- unique(key)
    agg <- do.call(rbind, lapply(ord, function(k) {
      i <- which(key == k)
      data.frame(rule = masks$rule[i[[1L]]], level = masks$level[i[[1L]]],
                 n_flagged = length(unique(masks$row[i])),
                 detail = masks$detail[i[[1L]]], stringsAsFactors = FALSE)
    }))
    agg$action <- ifelse(agg$level == "error" | on_warn == "drop", "剔除", "保留并标记")
    agg <- agg[order(match(agg$level, c("error", "warn", "info")), -agg$n_flagged), ]
    rownames(agg) <- NULL
    agg[, c("rule", "level", "n_flagged", "action", "detail")]
  } else {
    data.frame(rule = character(0), level = character(0), n_flagged = integer(0),
               action = character(0), detail = character(0), stringsAsFactors = FALSE)
  }

  structure(
    list(data = clean, report = report, masks = masks,
         dropped = length(drop_rows),
         n_error = if (nrow(masks)) length(unique(masks$row[masks$level == "error"])) else 0L,
         n_warn = if (nrow(masks)) length(unique(masks$row[masks$level == "warn"])) else 0L,
         n_input = n, n_output = nrow(clean),
         on_warn = on_warn, rules = rules,
         source = ing$source, read = ing$meta, ingest = ing),
    class = "epi_qc"
  )
}

print.epi_qc <- function(x, ...) {
  cat(sprintf("<epi_qc> 输入 %d 行 · 剔除 %d 行 · 保留 %d 行 · warn 策略 %s\n",
              x$n_input, x$dropped, x$n_output, x$on_warn))
  if (nrow(x$report)) print(x$report, row.names = FALSE) else cat("  没有规则命中。\n")
  invisible(x)
}
