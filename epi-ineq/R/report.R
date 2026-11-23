# =============================================================
# epiIneq / report.R — 控制台、CSV 与单文件 HTML
# HTML 不引用外部资源，可直接发出或离线打开。
# =============================================================

#' 输出分析结果
#'
#' @param x ineq_counts() 的返回值
#' @param output "console" / "csv" / "html"
#' @param file html 输出路径；csv 输出主表路径（同目录另写 groups/curve）
#' @param dir csv 输出目录（output = "csv" 时与 file 二选一）
#' @return 不可见地返回输出路径（console 为 NULL）
ineq_report <- function(x, output = c("console", "csv", "html"),
                        file = NULL, dir = NULL) {
  output <- match.arg(output)
  if (!inherits(x, "epi_ineq")) .epi_stop("x 必须是 ineq_counts() 的返回值")

  if (identical(output, "console")) {
    cat(sprintf("健康不平等 ｜ %d 地区 ｜ 年份 %s\n",
                x$meta$n, as.character(x$meta$year)))
    print(x$summary, row.names = FALSE)
    if (!is.null(x$decompose)) {
      cat("\n分解：总 CI %.4f = 组间 %.4f + 组内 %.4f + 余量 %.4f\n",
          x$decompose$total, x$decompose$between,
          x$decompose$within, x$decompose$residual)
    }
    if (!is.null(x$access))
      cat(sprintf("可达性：总体 %.3f，低/高 SES 比 %.3f\n",
                  x$access$overall, x$access$ratio_low_high))
    return(invisible(NULL))
  }

  if (identical(output, "csv")) {
    if (!is.null(dir)) {
      if (!dir.exists(dir)) dir.create(dir, recursive = TRUE, showWarnings = FALSE)
      f_sum <- file.path(dir, "ineq_summary.csv")
      f_grp <- file.path(dir, "ineq_groups.csv")
      f_curve <- file.path(dir, "ineq_curve.csv")
    } else {
      if (is.null(file)) .epi_stop("csv 输出需要 file 或 dir")
      if (!dir.exists(dirname(file))) dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
      f_sum <- file
      f_grp <- sub("\\.csv$", "_groups.csv", file)
      f_curve <- sub("\\.csv$", "_curve.csv", file)
    }
    utils::write.csv(x$summary, f_sum, row.names = FALSE, fileEncoding = "UTF-8")
    utils::write.csv(x$groups, f_grp, row.names = FALSE, fileEncoding = "UTF-8")
    utils::write.csv(x$curve$curve, f_curve, row.names = FALSE, fileEncoding = "UTF-8")
    return(invisible(c(f_sum, f_grp, f_curve)))
  }

  if (is.null(file)) .epi_stop("html 输出需要 file 路径")
  if (!grepl("\\.html?$", file, ignore.case = TRUE))
    .epi_stop("html 输出文件必须以 .html 或 .htm 结尾")
  if (!dir.exists(dirname(file))) dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  cv <- x$curve$curve
  W <- 800L; H <- 300L; L <- 56L; R <- 20L; T <- 20L; B <- 42L
  px <- function(v) L + v * (W - L - R)
  py <- function(v) T + (1 - v) * (H - T - B)
  xs <- paste(sprintf("%.1f", px(cv$cum_pop)), collapse = " ")
  ys <- paste(sprintf("%.1f", py(cv$cum_value)), collapse = " ")
  diag <- sprintf("%.1f,%.1f %.1f,%.1f", px(0), py(0), px(1), py(1))
  svg <- sprintf(paste0(
    '<svg viewBox="0 0 %d %d" width="100%%" role="img" aria-label="集中曲线">',
    '<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="#cbd5e1" stroke-dasharray="5 4"/>',
    '<polyline points="%s" fill="none" stroke="#1f4e88" stroke-width="2.5"/>',
    '<text x="%d" y="%d" font-size="11" fill="#718096">人口累积份额 →</text>',
    '<text x="6" y="%d" font-size="11" fill="#718096">病例累积份额</text>',
    '</svg>'),
    W, H, px(0), py(0), px(1), py(1),
    paste(paste0(xs, ",", ys), collapse = " "),
    W - 140L, H - 8L, T + 10L)

  kpis <- sprintf(
    '<div class="kpis"><div class="kpi"><div class="v">%.3f</div><div class="l">集中指数 CI</div></div><div class="kpi"><div class="v">%.2f</div><div class="l">SII（每十万人）</div></div><div class="kpi"><div class="v">%.2f</div><div class="l">低/高 SES 率比</div></div><div class="kpi"><div class="v">%.3f</div><div class="l">Gini</div></div></div>',
    x$core$CI, x$core$SII, x$core$rate_ratio, x$core$gini)

  dec_html <- if (is.null(x$decompose)) "<p>分解不可用。</p>" else {
    d <- x$decompose
    sprintf(paste0(
      '<table><tbody>',
      '<tr><th>总 CI</th><td>%.4f</td></tr>',
      '<tr><th>组间部分</th><td>%.4f</td></tr>',
      '<tr><th>组内部分</th><td>%.4f</td></tr>',
      '<tr><th>余量</th><td>%.4f</td></tr>',
      '<tr><th>可避免分值 PAF</th><td>%.4f</td></tr>',
      '</tbody></table>'),
      d$total, d$between, d$within, d$residual, d$paf)
  }
  grp_html <- .ineq_rows_html(
    x$groups,
    c("group", "n", "population", "count", "rate_per_100k", "pop_share", "count_share"),
    c("组", "地区数", "人口", "病例", "率/十万人", "人口份额", "病例份额"),
    list(population = function(v) .ineq_fmt(v, 0L),
         count = function(v) .ineq_fmt(v, 0L),
         rate_per_100k = function(v) .ineq_fmt(v, 1L),
         pop_share = function(v) .ineq_fmt(v, 3L),
         count_share = function(v) .ineq_fmt(v, 3L)))
  sum_html <- .ineq_rows_html(
    x$summary, c("metric", "value", "note"), c("指标", "值", "解释"),
    list(value = function(v) .ineq_fmt(v, 4L)))
  acc_html <- if (is.null(x$access)) "<p>本数据没有坐标，未计算可达性。</p>" else {
    a <- x$access
    sprintf(paste0(
      '<table><tbody><tr><th>设施点</th><td>%s</td></tr>',
      '<tr><th>特征距离 d0</th><td>%.2f</td></tr>',
      '<tr><th>衰减指数 beta</th><td>%.2f</td></tr>',
      '<tr><th>人口加权可达性</th><td>%.3f</td></tr>',
      '<tr><th>低/高 SES 可达性比</th><td>%.3f</td></tr>',
      '</tbody></table>'),
      .ineq_escape(paste(a$facilities$name, collapse = "、")),
      a$d0, a$beta, a$overall, a$ratio_low_high)
  }

  css <- paste0(
    '*{box-sizing:border-box}body{margin:0;background:#f4f7fb;color:#243447;',
    'font-family:"Microsoft YaHei","PingFang SC",-apple-system,Segoe UI,sans-serif;line-height:1.6}',
    '.wrap{max-width:960px;margin:0 auto;padding:26px 20px 56px}',
    'header{background:linear-gradient(120deg,#1f4e88,#2c7bc9);color:#fff;',
    'border-radius:14px;padding:24px 28px;margin-bottom:16px}',
    'header h1{margin:0 0 6px;font-size:24px}',
    '.kpis{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin-bottom:16px}',
    '.kpi{background:#fff;border:1px solid #e3e9f0;border-radius:12px;padding:14px 16px}',
    '.kpi .v{font-size:22px;font-weight:700;color:#1f4e88}.kpi .l{font-size:12px;color:#718096}',
    '.card{background:#fff;border:1px solid #e3e9f0;border-radius:12px;padding:16px 20px;margin-bottom:16px}',
    '.card h2{font-size:16px;margin:0 0 12px}',
    'table{width:100%;border-collapse:collapse;font-size:12px}',
    'th,td{padding:7px 9px;border-bottom:1px solid #edf1f6;text-align:left}',
    'th{background:#f7f9fc;color:#5a6a7e;font-weight:600}',
    '.note{font-size:12px;color:#718096}footer{font-size:11px;color:#94a3b8;text-align:center;margin-top:24px}')

  html <- sprintf(paste0(
    '<!doctype html><html lang="zh-CN"><head><meta charset="utf-8">',
    '<meta name="viewport" content="width=device-width,initial-scale=1">',
    '<title>健康不平等分析单</title><style>%s</style></head><body><div class="wrap">',
    '<header><h1>健康不平等分析单</h1><p>人口加权集中曲线 · 斜率不平等指数 · SES 分解 · 可达性</p></header>',
    '%s',
    '<section class="card"><h2>关键指标</h2>%s',
    '<p class="note">CI 与 SII 为负表示负担集中于低 SES 地区；率比 &gt; 1 同向。</p></section>',
    '<section class="card"><h2>人口加权集中曲线</h2>%s',
    '<p class="note">虚线为完全平等线；实线在其上方表示同一人口份额累积了更多病例。</p></section>',
    '<section class="card"><h2>SES 分组</h2><table>%s</table></section>',
    '<section class="card"><h2>集中指数分解</h2>%s</section>',
    '<section class="card"><h2>可达性</h2>%s</section>',
    '<footer>EpiStack · L4 由 epiIneq v%s 提供 · 单文件离线报告 · 合成数据</footer>',
    '</div></body></html>'),
    css, kpis, sum_html, svg, grp_html, dec_html, acc_html, .ineq_version())

  writeLines(html, file, useBytes = TRUE)
  invisible(file)
}
