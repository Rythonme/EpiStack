# =============================================================
# epiRobust / report.R — 单文件离线 HTML 体检报告
#
# 不依赖 rmarkdown / knitr：用 base R 拼一个自包含 HTML，浏览器直接打开。
# 中文用 enc2utf8 + useBytes 写出，meta charset 声明 UTF-8。
# =============================================================

.robust_status_class <- function(v) {
  if (grepl("翻转|警示", v)) "red" else if (grepl("需警惕", v)) "amber" else "green"
}

.robust_flag_rows <- function(x) {
  flagged <- names(x$verdicts)[grepl("翻转|警示|需警惕", x$verdicts)]
  if (!length(flagged)) return("<li>无：四项检查均未出现结论翻转。</li>")
  paste0("<li><b>", .robust_escape(flagged), "</b>：",
         .robust_escape(unname(x$verdicts[flagged])), "</li>",
         collapse = "")
}

#' 生成单文件 HTML 体检报告
#'
#' @param x `robust_check()` 的结果
#' @param file 输出文件路径
#' @return 输出文件路径（不可见）
#' @export
robust_report <- function(x, file = "robust-report.html") {
  if (!inherits(x, "epi_robust"))
    .epi_stop("x 必须是 robust_check() 的结果")

  overview <- data.frame(
    check = names(x$verdicts), verdict = unname(x$verdicts),
    stringsAsFactors = FALSE
  )
  overview_html <- .robust_rows_html(
    overview, c("check", "verdict"), c("检查项", "判定"),
    fmt = list(verdict = function(v) {
      cls <- .robust_status_class(v)
      sprintf('<span class="tag %s">%s</span>', cls, .robust_escape(v))
    })
  )

  maup_html <- .robust_rows_html(
    x$maup$table,
    c("scale", "n_regions", "I", "p", "hotspots", "coldspots", "outliers"),
    c("聚合倍数", "地区数", "Moran's I", "置换 p", "热点", "冷点", "离群"),
    fmt = list(I = .robust_fmt, p = .robust_p)
  )

  wt_html <- .robust_rows_html(
    x$weights$table, c("style", "mean_neighbors", "I", "p"),
    c("邻接定义", "平均邻居数", "Moran's I", "置换 p"),
    fmt = list(mean_neighbors = function(v) sprintf("%.2f", v),
               I = .robust_fmt, p = .robust_p)
  )

  cy_t <- x$conley$table[x$conley$table$term == x$conley$settings$term[1L], , drop = FALSE]
  cy_html <- .robust_rows_html(
    cy_t,
    c("cutoff", "beta", "naive_se", "conley_se", "se_ratio"),
    c("距离截断", "估计值", "朴素 SE", "Conley SE", "放大倍数"),
    fmt = list(beta = .robust_fmt, naive_se = .robust_fmt,
               conley_se = .robust_fmt,
               se_ratio = function(v) sprintf("%.2f", v))
  )

  mu <- x$multiplicity$table
  show_cols <- c("region", "p", "fdr_p", "bonferroni_p")
  show_cols <- show_cols[show_cols %in% names(mu)]
  hdr <- c("地区", "原始 p", "BH-FDR p", "Bonferroni p")[seq_along(show_cols)]
  mu_html <- .robust_rows_html(
    mu, show_cols, hdr,
    fmt = list(p = .robust_p, fdr_p = .robust_p, bonferroni_p = .robust_p)
  )

  flagged_cls <- .robust_status_class(x$overall)
  stamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  html <- c(
    '<!DOCTYPE html>',
    '<html lang="zh-CN"><head><meta charset="UTF-8">',
    '<meta name="viewport" content="width=device-width,initial-scale=1">',
    '<title>空间稳健性体检报告</title>',
    '<style>',
    'body{font-family:-apple-system,"Segoe UI","Microsoft YaHei",sans-serif;',
    'max-width:1000px;margin:36px auto;padding:0 20px;color:#2C2C2A;background:#fff;line-height:1.65}',
    'h1{font-size:22px;font-weight:600;margin:0 0 6px}h2{font-size:16px;font-weight:600;margin:30px 0 10px}',
    '.sub{color:#666;font-size:13px;margin:0 0 20px}',
    '.box{border:1px solid #e2e2e2;border-radius:10px;padding:14px 18px;background:#fafafa}',
    '.tag{display:inline-block;padding:2px 8px;border-radius:10px;font-size:12px}',
    '.tag.green{background:#E1F5EE;color:#0F6E56}.tag.amber{background:#FAEEDA;color:#854F0B}',
    '.tag.red{background:#FCEBEB;color:#A32D2D}',
    'table{border-collapse:collapse;width:100%;font-size:13px}',
    'th,td{border:1px solid #e6e6e6;padding:7px 10px;text-align:left}',
    'th{background:#f5f5f5;font-weight:600}',
    'tr:nth-child(even) td{background:#fcfcfc}',
    'ul{font-size:13px;padding-left:20px}li{margin:4px 0}',
    '.note{font-size:12px;color:#777;margin-top:28px;border-top:1px solid #eee;padding-top:12px}',
    '</style></head><body>',
    '<h1>空间稳健性体检报告</h1>',
    sprintf('<p class="sub">生成时间 %s ｜ %d 地区 ｜ 置换 %d 次 ｜ 种子 %s ｜ 年份 %s ｜ epiRobust %s</p>',
            .robust_escape(stamp), x$settings$n_regions, x$settings$n_perm,
            if (is.null(x$settings$seed)) "未固定" else .robust_escape(x$settings$seed),
            if (is.null(x$settings$year)) "全部" else .robust_escape(x$settings$year),
            .robust_escape(.robust_version())),
    sprintf('<div class="box"><b>总判定</b> <span class="tag %s">%s</span></div>',
            flagged_cls, .robust_escape(x$overall)),
    '<h2>1. 结论总览</h2>',
    sprintf('<table>%s</table>', overview_html),
    '<h2>2. MAUP 尺度敏感性</h2>',
    sprintf('<table>%s</table>', maup_html),
    sprintf('<p class="sub">判定：%s</p>', .robust_escape(x$maup$verdict)),
    '<h2>3. 邻接定义敏感性</h2>',
    sprintf('<table>%s</table>', wt_html),
    sprintf('<p class="sub">判定：%s</p>', .robust_escape(x$weights$verdict)),
    '<h2>4. 空间稳健标准误（Conley HAC）</h2>',
    sprintf('<table>%s</table>', cy_html),
    sprintf('<p class="sub">判定：%s</p>', .robust_escape(x$conley$verdict)),
    '<h2>5. 局部检验多重比较校正</h2>',
    sprintf('<table>%s</table>', mu_html),
    sprintf('<p class="sub">原始显著 %d 个 ｜ 校正后丢失 %d 个 ｜ 判定：%s</p>',
            x$multiplicity$raw_significant, x$multiplicity$lost,
            .robust_escape(x$multiplicity$verdict)),
    '<h2>6. 需要如实报告的警示</h2>',
    sprintf('<ul>%s</ul>', .robust_flag_rows(x)),
    '<div class="note">本报告只反映分析选择对结论的影响，不做病因推断。',
    'MAUP 的尺度与邻接定义由研究者决定，报告结论时应写明所用口径。',
    '置换 p 值在地区数较少时分辨率有限；Conley SE 的距离截断应结合研究尺度解释。</div>',
    '</body></html>'
  )
  writeLines(enc2utf8(html), file, useBytes = TRUE)
  invisible(file)
}
