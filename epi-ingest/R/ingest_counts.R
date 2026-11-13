# =============================================================
# epiIngest / ingest_counts.R — 一站式入口（推荐用法）
#
# 源 → 读取 → 规则化质控 → 交给 epiCore::read_counts() 生成契约。
#
# 关键设计：本函数不复制任何契约逻辑，只调用一次 read_counts()。
# 所以「新 L1 与旧 L1 数值一致」不是靠测试保证，而是结构上不可能不一致；
# 本层新增的行为只有一条——按规则剔除行，且剔除行数写进 $ingest$dropped。
# =============================================================

#' 从任意数据源产出统一契约
#'
#' @param x epi_source 对象、文件路径或 data.frame
#' @param rules 质控规则；NULL 表示不做规则质控（等价于直接用 read_counts）
#' @param geo 地区码表，至少含 region
#' @param time_step 时间粒度，auto 时按间隔推断
#' @param graph INLA .graph 邻接表路径
#' @param disease 原始表无病种列时使用的病种代码
#' @param mapping 列名映射，未指定时按中英文别名自动匹配
#' @param qc 是否启用 epiCore 的兜底质控（建议保留）
#' @param strict 是否执行严格契约校验
#' @param on_warn warn 级命中的处理方式；NULL 用全局设置
ingest_counts <- function(x, rules = NULL, geo = NULL,
                          time_step = c("auto", "week", "month", "quarter", "year"),
                          n_periods = NULL, graph = NULL,
                          adj_style = c("rook", "queen"),
                          disease = "HFRS", mapping = NULL,
                          qc = TRUE, strict = TRUE, on_warn = NULL) {
  if (!requireNamespace("epiCore", quietly = TRUE))
    .epi_stop(paste0("ingest_counts() 需要 epiCore 生成契约：\n",
                     "  install.packages(\"https://github.com/Rythonme/EpiStack/",
                     "releases/download/v0.1.1/epiCore_0.1.0.tar.gz\", repos = NULL, type = \"source\")"))
  time_step <- match.arg(time_step)
  adj_style <- match.arg(adj_style)
  ing <- if (inherits(x, "epi_ingest")) x else ingest_read(x)

  if (is.null(rules)) {
    res <- list(
      data = ing$data,
      report = data.frame(rule = character(0), level = character(0),
                          n_flagged = integer(0), action = character(0),
                          detail = character(0), stringsAsFactors = FALSE),
      masks = .empty_masks(), dropped = 0L, n_error = 0L, n_warn = 0L,
      n_input = nrow(ing$data), n_output = nrow(ing$data),
      on_warn = .epi_resolve_on_warn(on_warn), rules = NULL
    )
  } else {
    res <- qc_apply(ing, rules, on_warn = on_warn)
  }

  core <- epiCore::read_counts(
    res$data, geo = geo, mapping = mapping, disease = disease,
    time_step = time_step, n_periods = n_periods, graph = graph,
    adj_style = adj_style, qc = qc, strict = strict,
    source_label = ing$source$label
  )
  core$ingest <- list(
    source = ing$source, read = ing$meta, meta = ing$meta,
    rules = res$rules, report = res$report, masks = res$masks,
    on_warn = res$on_warn,
    n_input = res$n_input, n_dropped = res$dropped, n_output = res$n_output,
    n_error_rows = res$n_error, n_warn_rows = res$n_warn
  )
  core
}
