# =============================================================
# epiIngest / report.R — 质控单输出
#
# 三种出口，对应三种真实场景：
#   console  自己看，边调边改；
#   CSV      发给数据提供方，让他们按行号去改；
#   HTML     单文件、内联样式、可离线打开，附在邮件或报告里。
# 不出 PDF、不引 pandoc：多一个外部工具就多一类跑不起来的机器。
# =============================================================

.epi_html_escape <- function(s) {
  s <- as.character(s)
  s <- gsub("&", "&amp;", s, fixed = TRUE)
  s <- gsub("<", "&lt;", s, fixed = TRUE)
  s <- gsub(">", "&gt;", s, fixed = TRUE)
  s <- gsub("\"", "&quot;", s, fixed = TRUE)
  s
}

.epi_report_dir <- function(path) {
  d <- dirname(path)
  if (nzchar(d)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

#' 输出质控单
#'
#' @param x qc_apply() 的结果，或可直接读取的数据源
#' @param file 输出路径；NULL 只打印到控制台
#' @param format auto（按扩展名） / console / csv / html
#' @param title 报告标题
#' @param max_examples 每种规则在 HTML 里最多列几行样例
qc_report <- function(x, file = NULL, format = c("auto", "console", "csv", "html"),
                      title = NULL, max_examples = 5L) {
  format <- match.arg(format)
  res <- if (inherits(x, "epi_qc")) x else qc_apply(x)
  if (identical(format, "auto"))
    format <- if (is.null(file)) "console"
              else if (grepl("\\.html?$", file, ignore.case = TRUE)) "html" else "csv"

  title <- title %||% sprintf("质控单 · %s", res$source$label)

  if (format == "console") {
    cat(sprintf("%s\n", title))
    cat(sprintf("输入 %d 行，剔除 %d 行，保留 %d 行（warn 策略：%s）\n",
                res$n_input, res$dropped, res$n_output, res$on_warn))
    if (nrow(res$report)) print(res$report, row.names = FALSE)
    else cat("没有规则命中。\n")
    return(invisible(res))
  }

  if (is.null(file)) .epi_stop("format = \"%s\" 时必须提供 file", format)

  if (format == "csv") {
    .epi_report_dir(file)
    utils::write.csv(res$report, file, row.names = FALSE, fileEncoding = "UTF-8")
    rows_file <- sub("\\.csv$", "", file, ignore.case = TRUE)
    rows_file <- paste0(rows_file, "_rows.csv")
    utils::write.csv(res$masks, rows_file, row.names = FALSE, fileEncoding = "UTF-8")
    cat(sprintf("质控单：%s\n逐行明细：%s\n", file, rows_file))
    return(invisible(res))
  }

  # ---- HTML ----
  .epi_report_dir(file)
  src <- res$ingest$data
  ex <- .epi_examples(res, src, max_examples)
  rules_json <- tryCatch(.epi_json_stringify(
    list(name = res$rules$name, required = as.list(res$rules$required),
         unique_key = if (length(res$rules$unique_key)) as.list(res$rules$unique_key),
         range = res$rules$range, date_seq = res$rules$date_seq,
         outlier = res$rules$outlier,
         region_code = if (is.null(res$rules$region_code)) NULL else
           list(n_allowed = length(res$rules$region_code$allowed)),
         cross_field = res$rules$cross_field), pretty = TRUE),
    error = function(e) "（规则集无法序列化）")

  rule_rows <- if (nrow(res$report)) paste0(vapply(seq_len(nrow(res$report)), function(i) {
    r <- res$report[i, ]
    cls <- if (r$level == "error") "lv-error" else if (r$level == "warn") "lv-warn" else "lv-info"
    sprintf("<tr><td><code>%s</code></td><td><span class=\"tag %s\">%s</span></td><td class=\"num\">%d</td><td>%s</td><td class=\"muted\">%s</td></tr>",
            .epi_html_escape(r$rule), cls, .epi_html_escape(r$level),
            r$n_flagged, .epi_html_escape(r$action), .epi_html_escape(r$detail))
  }, ""), collapse = "\n") else
    "<tr><td colspan=\"5\" class=\"muted\">没有规则命中</td></tr>"

  ex_html <- if (length(ex)) paste0(vapply(names(ex), function(nm) {
    d <- ex[[nm]]
    hdr <- paste0("<th>", .epi_html_escape(names(d)), "</th>", collapse = "")
    body <- paste0(vapply(seq_len(nrow(d)), function(i) {
      paste0("<tr>", paste0("<td>", vapply(d[i, ], .epi_html_escape, ""), "</td>",
                            collapse = ""), "</tr>")
    }, ""), collapse = "")
    sprintf("<h3><code>%s</code></h3><table class=\"grid\"><thead><tr>%s</tr></thead><tbody>%s</tbody></table>",
            .epi_html_escape(nm), hdr, body)
  }, ""), collapse = "\n") else "<p class=\"muted\">没有可展示的命中样例。</p>"

  html <- sprintf('<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%s</title>
<style>
:root { --ink:#1f2328; --muted:#6b7280; --line:#e5e7eb; --bg:#ffffff; --soft:#f6f8fa;
        --err:#b42318; --errbg:#fef3f2; --warn:#b54708; --warnbg:#fffaeb; --ok:#067647; }
* { box-sizing: border-box; }
body { margin:0; padding:32px; background:var(--bg); color:var(--ink);
       font:14px/1.65 -apple-system,"Segoe UI","Microsoft YaHei",sans-serif; }
.wrap { max-width: 980px; margin: 0 auto; }
h1 { font-size:20px; margin:0 0 4px; }
h2 { font-size:15px; margin:32px 0 10px; padding-bottom:6px; border-bottom:1px solid var(--line); }
h3 { font-size:13px; margin:18px 0 6px; font-weight:600; }
.muted { color:var(--muted); }
code { font-family: ui-monospace,"Cascadia Mono",Consolas,monospace; font-size:12.5px; }
.sub { color:var(--muted); font-size:12.5px; }
.cards { display:flex; gap:12px; flex-wrap:wrap; margin-top:18px; }
.card { flex:1 1 150px; border:1px solid var(--line); border-radius:8px; padding:12px 14px; background:var(--soft); }
.card .k { font-size:12px; color:var(--muted); }
.card .v { font-size:22px; font-weight:600; margin-top:2px; }
.v.err { color:var(--err); } .v.ok { color:var(--ok); } .v.warn { color:var(--warn); }
table { width:100%%; border-collapse:collapse; font-size:13px; }
table.grid th { text-align:left; font-weight:600; background:var(--soft); }
table.grid th, table.grid td { border:1px solid var(--line); padding:6px 9px; }
td.num { text-align:right; font-variant-numeric: tabular-nums; }
.tag { display:inline-block; padding:1px 7px; border-radius:10px; font-size:11.5px; }
.lv-error { background:var(--errbg); color:var(--err); }
.lv-warn { background:var(--warnbg); color:var(--warn); }
.lv-info { background:var(--soft); color:var(--muted); }
details { margin-top:10px; } summary { cursor:pointer; color:var(--muted); font-size:12.5px; }
pre { background:var(--soft); border:1px solid var(--line); border-radius:6px; padding:10px;
      overflow:auto; font-size:12px; }
footer { margin-top:36px; padding-top:12px; border-top:1px solid var(--line);
         color:var(--muted); font-size:12px; }
</style></head><body><div class="wrap">
<h1>%s</h1>
<div class="sub">数据源 %s · 生成于 %s · epiIngest %s</div>
<div class="cards">
  <div class="card"><div class="k">输入行数</div><div class="v">%d</div></div>
  <div class="card"><div class="k">剔除行数</div><div class="v err">%d</div></div>
  <div class="card"><div class="k">保留行数</div><div class="v ok">%d</div></div>
  <div class="card"><div class="k">warn 命中行</div><div class="v warn">%d</div></div>
</div>
<h2>规则命中汇总</h2>
<table class="grid"><thead><tr><th>规则</th><th>级别</th><th class="num">命中行</th><th>处理</th><th>判据</th></tr></thead>
<tbody>%s</tbody></table>
<h2>命中样例（最多 %d 行/规则）</h2>
%s
<h2>本次使用的规则集</h2>
<details><summary>展开查看（warn 策略：%s）</summary><pre>%s</pre></details>
<footer>epiIngest %s · 由 qc_report() 生成，无外部依赖，可离线打开。</footer>
</div></body></html>',
    .epi_html_escape(title), .epi_html_escape(title),
    .epi_html_escape(res$source$label),
    format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    .epi_pkg_version(),
    res$n_input, res$dropped, res$n_output, res$n_warn,
    rule_rows, as.integer(max_examples), ex_html,
    res$on_warn, .epi_html_escape(rules_json),
    .epi_pkg_version())

  writeLines(enc2utf8(html), file, useBytes = TRUE)
  cat(sprintf("质控报告：%s\n", file))
  invisible(res)
}

# 每种规则取前若干命中行，附上该行的关键字段，方便直接定位
.epi_examples <- function(res, src, k = 5L) {
  m <- res$masks
  if (!nrow(m)) return(list())
  rules <- unique(m$rule)
  out <- list()
  keep_cols <- intersect(c("date", "region", "count", "population", "disease"), names(src))
  for (r in rules) {
    rows <- utils::head(unique(m$row[m$rule == r]), k)
    d <- src[rows, keep_cols, drop = FALSE]
    d <- cbind(data.frame(row = rows), d)
    d$detail <- m$detail[match(paste(r, rows), paste(m$rule, m$row))]
    out[[r]] <- d
  }
  out
}
