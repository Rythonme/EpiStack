# =============================================================
# epiAlert / report.R — 预警单输出
#
# 三种出口，对应三种使用场景：
#   console  自己看；
#   CSV      交给业务方或别的系统；
#   HTML     单文件、内联样式、可离线打开，直接附在邮件里。
# 不出 PDF、不引 pandoc：多一个外部工具就多一类跑不起来的机器。
# =============================================================

.alert_escape <- function(s) {
  s <- as.character(s)
  s <- gsub("&", "&amp;", s, fixed = TRUE)
  s <- gsub("<", "&lt;", s, fixed = TRUE)
  s <- gsub(">", "&gt;", s, fixed = TRUE)
  gsub("\"", "&quot;", s, fixed = TRUE)
}

.alert_fmt <- function(v, digits = 1L) {
  ifelse(is.na(v), "-", formatC(v, format = "f", digits = digits))
}

.alert_rows_html <- function(df, cols, headers, fmt = list()) {
  if (!nrow(df)) return(sprintf('<tr><td colspan="%d">无</td></tr>', length(cols)))
  body <- vapply(seq_len(nrow(df)), function(i) {
    cells <- vapply(seq_along(cols), function(j) {
      v <- df[[cols[j]]][i]
      if (inherits(v, "Date")) v <- format(v, "%Y-%m-%d")
      f <- fmt[[cols[j]]]
      if (is.function(f)) f(v) else .alert_escape(v)
    }, character(1))
    paste0("<tr>", paste0("<td>", cells, "</td>", collapse = ""), "</tr>")
  }, character(1))
  paste0("<thead><tr>", paste0("<th>", headers, "</th>", collapse = ""),
         "</tr></thead><tbody>", paste(body, collapse = ""), "</tbody>")
}

#' 输出预警单
#'
#' @param x `alert_counts()` 的结果
#' @param file 输出路径；NULL 只打印到控制台
#' @param format auto（按扩展名）/ console / csv / html
#' @param title 报告标题
#' @param max_rows HTML 里最多列几条信号
alert_report <- function(x, file = NULL, format = c("auto", "console", "csv", "html"),
                         title = NULL, max_rows = 24L) {
  format <- match.arg(format)
  if (!inherits(x, "epi_alert")) .epi_stop("x 必须是 alert_counts() 的结果")
  if (identical(format, "auto"))
    format <- if (is.null(file)) "console"
              else if (grepl("\\.html?$", file, ignore.case = TRUE)) "html" else "csv"

  s <- x$settings
  lab <- s$rules$labels
  title <- title %||% "预警单"
  cnt <- vapply(lab, function(l) sum(x$current$level == l), integer(1))

  if (identical(format, "console")) {
    cat(sprintf("%s\n", title))
    cat(sprintf("粒度 %s ｜ 方法 %s ｜ 参数 window=%d, k=%.3f, min_obs=%d\n",
                s$time_step, s$method, s$window, s$k, s$min_obs))
    cat(sprintf("评估 %d 期 × %d 地区 ｜ 基线不足 %d 期\n",
                x$meta$n_targets, x$meta$n_regions, x$meta$n_band_missing))
    cat(sprintf("%s\n", paste(sprintf("%s %d", lab, cnt), collapse = " ｜ ")))
    if (nrow(x$alerts)) {
      cat("\n信号清单（前 10 条）：\n")
      print(utils::head(x$alerts, 10L), row.names = FALSE)
    } else {
      cat("没有信号。\n")
    }
    return(invisible(x))
  }

  if (is.null(file)) .epi_stop("format = \"%s\" 时必须提供 file", format)
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)

  if (identical(format, "csv")) {
    utils::write.csv(x$alerts, file, row.names = FALSE, fileEncoding = "UTF-8")
    regions_file <- paste0(sub("\\.csv$", "", file, ignore.case = TRUE), "_regions.csv")
    utils::write.csv(x$summary, regions_file, row.names = FALSE, fileEncoding = "UTF-8")
    cat(sprintf("信号清单：%s\n地区汇总：%s\n", file, regions_file))
    return(invisible(x))
  }

  kpi <- function(v, l, cls = "") sprintf(
    '<div class="kpi %s"><div class="v">%s</div><div class="l">%s</div></div>', cls, v, l)
  level_cell <- function(i, cls) sprintf(
    '<div class="lv %s"><b>%d</b><span>%s</span></div>', cls, cnt[[i]], lab[[i]])

  sig <- utils::head(x$alerts, max_rows)
  reg <- utils::head(x$summary, 12L)

  html <- paste0(
    '<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8">',
    '<meta name="viewport" content="width=device-width,initial-scale=1">',
    "<title>", .alert_escape(title), "</title><style>",
    '*{box-sizing:border-box}body{margin:0;background:#f4f7fb;color:#243447;',
    'font-family:"Microsoft YaHei","PingFang SC",-apple-system,Segoe UI,sans-serif;line-height:1.6}',
    '.wrap{max-width:960px;margin:0 auto;padding:26px 20px 56px}',
    'header{background:linear-gradient(120deg,#1f4e88,#2c7bc9);color:#fff;border-radius:14px;',
    'padding:24px 28px;margin-bottom:16px}header h1{margin:0 0 6px;font-size:23px}',
    'header p{margin:2px 0;opacity:.92;font-size:13px}',
    '.kpis{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin-bottom:16px}',
    '.kpi{background:#fff;border:1px solid #e3e9f0;border-radius:12px;padding:14px 16px}',
    '.kpi .v{font-size:22px;font-weight:700;color:#1f4e88}.kpi .l{font-size:12px;color:#718096}',
    '.kpi.o .v{color:#e67e22}.kpi.r .v{color:#c0392b}',
    '.lvrow{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;margin-bottom:16px}',
    '.lv{background:#fff;border:1px solid #e3e9f0;border-radius:10px;padding:12px 14px;',
    'display:flex;align-items:baseline;gap:8px}.lv b{font-size:20px;color:#1f4e88}',
    '.lv span{font-size:12px;color:#718096}.lv.warn b{color:#e67e22}.lv.alarm b{color:#c0392b}',
    '.card{background:#fff;border:1px solid #e3e9f0;border-radius:12px;padding:16px 20px;margin-bottom:16px}',
    '.card h2{font-size:16px;margin:0 0 12px}',
    'table{width:100%;border-collapse:collapse;font-size:12.5px}',
    'th,td{padding:7px 9px;border-bottom:1px solid #edf1f6;text-align:left}',
    'th{background:#f7f9fc;color:#5a6a7e;font-weight:600}',
    '.note{font-size:12px;color:#5a6a7e;margin:0}',
    'footer{font-size:11px;color:#8a97a5;text-align:center;margin-top:24px}',
    '@media(max-width:700px){.kpis,.lvrow{grid-template-columns:repeat(2,1fr)}}',
    "</style></head><body><div class=\"wrap\">",
    sprintf("<header><h1>%s</h1><p>时间粒度 %s · 基线方法 %s · 评估范围 %s</p>",
            .alert_escape(title), .alert_escape(s$time_step), .alert_escape(s$method),
            .alert_escape(if (is.character(s$assess)) s$assess
                          else paste(range(s$assess), collapse = "-"))),
    sprintf("<p>%s · 单文件离线报告</p></header>", .alert_escape(paste0("epiAlert ", x$meta$version))),
    '<div class="kpis">',
    kpi(x$meta$n_targets, "评估期数"), kpi(nrow(x$alerts), "异常信号", "o"),
    kpi(cnt[[4L]], "告警", "r"), kpi(x$meta$n_band_missing, "基线不足期数"),
    "</div>",
    '<div class="lvrow">', level_cell(1L, ""), level_cell(2L, ""),
    level_cell(3L, "warn"), level_cell(4L, "alarm"), "</div>",
    '<section class="card"><h2>按地区汇总</h2><table>',
    .alert_rows_html(reg,
      c("region", "n_periods", "n_exceed", "n_warn", "n_alarm", "peak_level",
        "max_ratio", "last_alert"),
      c("地区", "评估期数", "超限", "预警", "告警", "最高级别", "最大倍数", "最后信号"),
      list(max_ratio = function(v) .alert_fmt(v, 2L))),
    "</table></section>",
    sprintf('<section class="card"><h2>信号清单（前 %d 条）</h2><table>', min(max_rows, nrow(sig))),
    .alert_rows_html(sig,
      c("date", "region", "count", "baseline", "upper", "ratio", "run_len", "level"),
      c("日期", "地区", "报告数", "基线", "上界", "超出倍数", "连续超限", "级别"),
      list(baseline = function(v) .alert_fmt(v, 1L),
           upper = function(v) .alert_fmt(v, 1L),
           ratio = function(v) .alert_fmt(v, 2L))),
    "</table></section>",
    '<section class="card"><h2>方法与参数</h2><p class="note">',
    sprintf("基线与上界只用评估期之前的历史计算，不参与自身基线；上界 = exp(μ + %.3fσ) − %.1f，",
            s$k, s$offset),
    sprintf("μ、σ 为 log(count + %.1f) 的同季节窗口均值与标准差（window = ±%d 期）。",
            s$offset, s$window),
    sprintf("分级：连续 ≥%g 期判%s；连续 ≥%g 期或超 %.2f 倍判%s；连续 ≥%g 期或超 %.2f 倍判%s。",
            s$rules$watch, lab[2L], s$rules$warn_run, s$rules$warn_ratio, lab[3L],
            s$rules$alarm_run, s$rules$alarm_ratio, lab[4L]),
    "阈值需按病种与当地报告制度校准，结果不可直接作为公共卫生决策依据。</p></section>",
    "<footer>EpiStack · L2 由 epiAlert 提供 · 阈值可用 alert_rules_write() 存成 JSON 随项目走</footer>",
    "</div></body></html>"
  )
  writeLines(html, file, useBytes = TRUE)
  cat(sprintf("预警单：%s\n", file))
  invisible(x)
}
