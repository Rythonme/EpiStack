# =============================================================
# epiIngest / lineage.R — 数据血缘
#
# 「这份表是怎么来的、被删了几行、用的哪版规则」必须能一条命令答出来。
# 血缘不是日志：它随产物一起走，写进 JSON，进入报告和复现代码。
# =============================================================

.epi_hash_string <- function(s) {
  f <- tempfile()
  on.exit(unlink(f), add = TRUE)
  writeLines(enc2utf8(paste(s, collapse = "\n")), f, useBytes = TRUE)
  substr(unname(tools::md5sum(f)), 1L, 12L)
}

.epi_rules_hash <- function(rules) {
  obj <- list(required = as.list(rules$required %||% character(0)),
              unique_key = if (length(rules$unique_key)) as.list(rules$unique_key),
              range = rules$range, date_seq = rules$date_seq,
              region_code = if (is.null(rules$region_code)) NULL else
                list(n = length(rules$region_code$allowed),
                     hash = .epi_hash_string(sort(rules$region_code$allowed))),
              outlier = rules$outlier, cross_field = rules$cross_field)
  .epi_hash_string(.epi_json_stringify(obj, pretty = FALSE))
}

#' 汇总一次读取 + 质控的血缘
#'
#' @param x epi_ingest / epi_qc / epi_contract（含 $ingest）
#' @param file 若非 NULL，把血缘写入 JSON
ingest_lineage <- function(x, file = NULL) {
  ing <- if (inherits(x, "epi_ingest")) x
         else if (inherits(x, "epi_qc")) x$ingest
         else if (inherits(x, "epi_contract")) x$ingest
         else if (is.data.frame(x) || is.character(x)) ingest_read(x)
         else .epi_stop("x 必须是 epi_ingest、epi_qc、epi_contract、数据源或 data.frame")
  if (is.null(ing) || is.null(ing$meta))
    .epi_stop("该对象不含读取信息，无法生成血缘（契约需由 ingest_counts() 生成）")

  m <- ing$meta
  files <- if (length(m$files)) {
    data.frame(
      file     = basename(m$files),
      md5      = if (length(m$md5)) m$md5 else NA_character_,
      encoding = if (length(m$encoding)) rep_len(m$encoding, length(m$files)) else NA_character_,
      sep      = if (length(m$sep)) rep_len(m$sep, length(m$files)) else NA_character_,
      stringsAsFactors = FALSE
    )
  } else {
    data.frame(file = "<in-memory>", md5 = NA_character_,
               encoding = paste(m$encoding, collapse = "/"),
               sep = NA_character_, stringsAsFactors = FALSE)
  }

  qc <- NULL
  if (inherits(x, "epi_qc")) {
    qc <- list(rules_name = x$rules$name %||% "custom",
               rules_hash = .epi_rules_hash(x$rules),
               on_warn = x$on_warn,
               n_input = x$n_input, n_dropped = x$dropped, n_output = x$n_output,
               n_error_rows = x$n_error, n_warn_rows = x$n_warn,
               rules = if (nrow(x$report)) x$report[, c("rule", "level", "n_flagged", "action")] else NULL)
  } else if (inherits(x, "epi_contract") && !is.null(x$ingest)) {
    r <- x$ingest$rules
    qc <- list(rules_name = if (is.null(r)) "none" else (r$name %||% "custom"),
               rules_hash = if (is.null(r)) NA_character_ else .epi_rules_hash(r),
               on_warn = x$ingest$on_warn %||% "keep",
               n_input = x$ingest$n_input, n_dropped = x$ingest$n_dropped,
               n_output = x$ingest$n_output,
               n_error_rows = x$ingest$n_error_rows %||% 0L,
               n_warn_rows = x$ingest$n_warn_rows %||% 0L,
               rules = if (nrow(x$ingest$report)) x$ingest$report[, c("rule", "level", "n_flagged", "action")] else NULL)
  }

  contract <- if (inherits(x, "epi_contract"))
    list(version = x$meta$version, time_step = x$meta$time_step,
         n_clean = x$meta$n_clean, n_regions = length(unique(x$data$region))) else NULL

  structure(
    list(
      run = list(package = "epiIngest",
                 version = as.character(.epi_pkg_version()),
                 created_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
                 r_version = paste(R.version$major, R.version$minor, sep = "."),
                 platform = R.version$platform),
      source = list(label = ing$source$label, type = ing$source$type,
                    backend = paste(m$backend, collapse = "/"),
                    read_at = m$read_at),
      files = files,
      qc = qc,
      contract = contract
    ),
    class = "epi_lineage"
  )
}

print.epi_lineage <- function(x, ...) {
  cat("<epi_lineage>\n")
  cat(sprintf("  来源    : %s (%s, %s)\n", x$source$label, x$source$type, x$source$backend))
  cat(sprintf("  文件    : %d 个 · %d 行\n", nrow(x$files), sum(!is.na(x$files$md5))))
  if (!is.null(x$qc))
    cat(sprintf("  质控    : 输入 %d → 保留 %d（剔除 %d）· 规则 %s · warn 策略 %s\n",
                x$qc$n_input, x$qc$n_output, x$qc$n_dropped,
                x$qc$rules_hash %||% "-", x$qc$on_warn %||% "-"))
  if (!is.null(x$contract))
    cat(sprintf("  契约    : v%s · %s 粒度 · %d 行 · %d 个地区\n",
                x$contract$version, x$contract$time_step, x$contract$n_clean, x$contract$n_regions))
  invisible(x)
}

#' 把血缘写成 JSON（随产物一起归档）
ingest_lineage_write <- function(x, path) {
  lin <- if (inherits(x, "epi_lineage")) x else ingest_lineage(x)
  .epi_json_write(unclass(lin), path)
  invisible(path)
}
