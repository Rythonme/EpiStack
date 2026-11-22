# =============================================================
# epiSpace / report.R — 空间分析单
#
# 三种出口：console / CSV / 单文件 HTML。不出 PDF、不引 pandoc。
# =============================================================

#' 输出空间分析单
#'
#' @param x `space_counts()` 的结果
#' @param file 输出路径；NULL 只打印控制台
#' @param format auto（按扩展名）/ console / csv / html
#' @param title 标题
#' @param max_rows HTML 里最多列几条地区
space_report <- function(x, file = NULL,
                         format = c("auto", "console", "csv", "html"),
                         title = NULL, max_rows = 24L) {
  format <- match.arg(format)
  if (!inherits(x, "epi_space")) .epi_stop("x 必须是 space_counts() 的结果")
  if (identical(format, "auto"))
    format <- if (is.null(file)) "console"
              else if (grepl("\\.html?$", file, ignore.case = TRUE)) "html" else "csv"
  title <- title %||% "空间自相关分析单"
  cat_tab <- x$hotspots[order(x$hotspots$p_i), , drop = FALSE]
  h <- table(factor(x$hotspots$category,
                    levels = c("热点", "冷点", "空间离群", "不显著")))

  if (identical(format, "console")) {
    cat(sprintf("%s\n", title))
    cat(sprintf("%d 地区 ｜ 权重 %s ｜ 置换 %d 次 ｜ alpha %.2f\n",
                x$meta$n_regions, x$meta$source, x$settings$n_perm, x$settings$alpha))
    cat(sprintf("全局 Moran's I = %.4f ｜ p = %s\n",
                x$global$I, ifelse(is.na(x$global$p), "NA",
                                   sprintf("%.4f", x$global$p))))
    cat(sprintf("热点 %d ｜ 冷点 %d ｜ 空间离群 %d ｜ 不显著 %d\n",
                h[["热点"]], h[["冷点"]], h[["空间离群"]], h[["不显著"]]))
    if (nrow(cat_tab)) {
      cat("\n按显著性排序（前 10）：\n")
      print(utils::head(cat_tab[, c("region", "value", "I_i", "p_i",
                                    "quadrant", "category")], 10L), row.names = FALSE)
    }
    return(invisible(x))
  }

  if (is.null(file)) .epi_stop("format = \"%s\" 时必须提供 file", format)
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  if (identical(format, "csv")) {
    utils::write.csv(x$hotspots, file, row.names = FALSE, fileEncoding = "UTF-8")
    sum_file <- paste0(sub("\\.csv$", "", file, ignore.case = TRUE), "_summary.csv")
    utils::write.csv(x$summary, sum_file, row.names = FALSE, fileEncoding = "UTF-8")
    cat(sprintf("逐地区结果：%s\n摘要：%s\n", file, sum_file))
    return(invisible(x))
  }

  kpi <- function(v, l, cls = "") sprintf(
    '<div class="kpi %s"><div class="v">%s</div><div class="l">%s</div></div>', cls, v, l)
  show <- utils::head(cat_tab, max_rows)
  html <- paste0(
    '<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8">',
    '<meta name="viewport" content="width=device-width,initial-scale=1">',
    "<title>", .space_escape(title), "</title><style>",
    '*{box-sizing:border-box}body{margin:0;background:#f4f7fb;color:#243447;',
    'font-family:"Microsoft YaHei","PingFang SC",-apple-system,Segoe UI,sans-serif;line-height:1.6}',
    '.wrap{max-width:960px;margin:0 auto;padding:26px 20px 56px}',
    'header{background:linear-gradient(120deg,#1f4e88,#2c7bc9);color:#fff;border-radius:14px;',
    'padding:24px 28px;margin-bottom:16px}header h1{margin:0 0 6px;font-size:23px}',
    'header p{margin:2px 0;opacity:.92;font-size:13px}',
    '.kpis{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin-bottom:16px}',
    '.kpi{background:#fff;border:1px solid #e3e9f0;border-radius:12px;padding:14px 16px}',
    '.kpi .v{font-size:22px;font-weight:700;color:#1f4e88}.kpi .l{font-size:12px;color:#718096}',
    '.kpi.r .v{color:#c0392b}.kpi.g .v{color:#2e9e6b}',
    '.card{background:#fff;border:1px solid #e3e9f0;border-radius:12px;padding:16px 20px;margin-bottom:16px}',
    '.card h2{font-size:16px;margin:0 0 12px}',
    'table{width:100%;border-collapse:collapse;font-size:12.5px}',
    'th,td{padding:7px 9px;border-bottom:1px solid #edf1f6;text-align:left}',
    'th{background:#f7f9fc;color:#5a6a7e;font-weight:600}',
    '.note{font-size:12px;color:#5a6a7e;margin:0}',
    'footer{font-size:11px;color:#8a97a5;text-align:center;margin-top:24px}',
    '@media(max-width:700px){.kpis{grid-template-columns:repeat(2,1fr)}}',
    "</style></head><body><div class=\"wrap\">",
    sprintf("<header><h1>%s</h1><p>%d 个地区 · 权重 %s · 置换 %d 次</p>",
            .space_escape(title), x$meta$n_regions, .space_escape(x$meta$source),
            x$settings$n_perm),
    sprintf("<p>%s · 单文件离线报告</p></header>",
            .space_escape(paste0("epiSpace ", x$meta$version))),
    '<div class="kpis">',
    kpi(.space_fmt(x$global$I, 4L), "全局 Moran's I"),
    kpi(ifelse(is.na(x$global$p), "NA", .space_fmt(x$global$p, 4L)), "置换 p 值"),
    kpi(as.character(h[["热点"]]), "显著热点", "r"),
    kpi(as.character(h[["冷点"]]), "显著冷点", "g"),
    "</div>",
    sprintf('<section class="card"><h2>逐地区 LISA（前 %d 条，按 p 值）</h2><table>',
            min(max_rows, nrow(show))),
    .space_rows_html(show,
      c("region", "value", "I_i", "p_i", "quadrant", "category"),
      c("地区", "观测值", "局部 I", "置换 p", "象限", "类别"),
      list(I_i = function(v) .space_fmt(v, 3L),
           p_i = function(v) .space_fmt(v, 4L),
           value = function(v) .space_fmt(v, 4L))),
    "</table></section>",
    '<section class="card"><h2>方法与边界</h2><p class="note">',
    sprintf("全局 Moran's I = (n / S0) × Σ w_ij z_i z_j / Σ z_i²，z = x − mean(x)；%d 次随机置换给出双侧 p 值。",
            x$settings$n_perm),
    sprintf("局部 LISA 用同一权重，I_i = z_i × Σ_j w_ij z_j / (Σ z_i² / n)；HH 且 p &lt; %.2f 判热点，LL 判冷点，HL/LH 判空间离群。",
            x$settings$alpha),
    "权重需先按邻接结构校验：结构必须对称、不能有孤立地区；行标准化后数值可以不对称。",
    "空间自相关只描述格局，不能替代病因推断；小地区数（n &lt; 20）的置换 p 值分辨率有限。</p></section>",
    "<footer>EpiStack · L3 由 epiSpace 提供 · BYM2 模板可用 space_bym2_template() 生成</footer>",
    "</div></body></html>"
  )
  writeLines(html, file, useBytes = TRUE)
  cat(sprintf("空间分析单：%s\n", file))
  invisible(x)
}
