# =============================================================
# EpiStack · L3.5 epiRobust 稳健性体检（合成数据）
#
# 做的事：
#   1. 36 个虚构地区格网（6×6，三年面板），不触碰任何真实观测数据
#   2. 四项体检：MAUP 多尺度、邻接定义、Conley 空间稳健 SE、多重比较
#   3. 断言：四项结论齐全、Moran 有限、SE 放大比 >= 1、报告非空
#   4. 产出单文件 HTML 体检单、四张 CSV 明细、指标 JSON
#
# 本 stage 由 pipeline.R 编排，只新增产物，不改动 L0–L4 既有输出与 golden。
# =============================================================

root <- Sys.getenv("EPISTACK_PROJECT_ROOT", unset = "")
if (!nzchar(root)) {
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  root <- if (length(f)) dirname(dirname(normalizePath(f[1L]))) else getwd()
}
out <- Sys.getenv("EPISTACK_OUT_DIR", unset = file.path(root, "robust_demo", "output"))
dir.create(out, recursive = TRUE, showWarnings = FALSE)

source(file.path(root, "R", "epi_json.R"), encoding = "UTF-8")
source(file.path(root, "bootstrap_core.R"), encoding = "UTF-8")
core_mode <- epi_bootstrap_core(file.path(root, "epi-core"), verbose = FALSE)
source(file.path(root, "bootstrap_robust.R"), encoding = "UTF-8")
robust_mode <- epi_bootstrap_robust(file.path(root, "epi-robust"))

# ---- 1. 合成数据 ----
d <- robust_example(n_side = 6L, years = 2022:2024)
cat(sprintf("[L3.5] 合成数据 %d 行 ｜ %d 个虚构地区（%s）\n",
            nrow(d), length(unique(d$region)), robust_mode))

# ---- 2. 一键体检 ----
res <- robust_check(
  d,
  scales  = c(1L, 2L, 3L),
  styles  = c("rook", "queen", "knn"),
  cutoffs = c(1.5, 2, 3, 6),
  n_perm  = 199L,
  seed    = 20261124L
)
print(res)

# ---- 3. 产物 ----
html <- file.path(out, "稳健性体检报告.html")
robust_report(res, html)
write.csv(res$maup$table, file.path(out, "maup_summary.csv"),
          row.names = FALSE, fileEncoding = "UTF-8")
write.csv(res$weights$table, file.path(out, "weights_summary.csv"),
          row.names = FALSE, fileEncoding = "UTF-8")
write.csv(res$conley$table, file.path(out, "conley_summary.csv"),
          row.names = FALSE, fileEncoding = "UTF-8")
write.csv(res$multiplicity$table, file.path(out, "multiplicity_regions.csv"),
          row.names = FALSE, fileEncoding = "UTF-8")

I_by_scale <- res$maup$table$I
max_se_ratio <- suppressWarnings(max(res$conley$table$se_ratio, na.rm = TRUE))
if (!is.finite(max_se_ratio)) max_se_ratio <- NA_real_
metrics <- list(
  generated_at        = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
  contract_rows       = nrow(d),
  n_regions           = res$settings$n_regions,
  scales              = paste(res$maup$settings$scales, collapse = ","),
  styles              = paste(res$weights$settings$styles, collapse = ","),
  cutoffs             = paste(res$conley$settings$cutoffs, collapse = ","),
  n_perm              = res$settings$n_perm,
  seed                = res$settings$seed,
  moran_by_scale      = round(I_by_scale, 6),
  sign_flip           = any(diff(sign(I_by_scale)) != 0L),
  raw_significant     = res$multiplicity$raw_significant,
  lost_after_correct  = res$multiplicity$lost,
  max_se_ratio        = round(max_se_ratio, 6),
  verdicts            = unname(res$verdicts),
  overall             = res$overall,
  report_bytes        = file.info(html)$size,
  core_mode           = core_mode,
  robust_mode         = robust_mode
)
epi_json_write(metrics, file.path(out, "robust_metrics.json"))

# ---- 4. 不变量断言（不依赖具体数值，避免脆弱基线） ----
stopifnot(length(res$verdicts) == 4L)
stopifnot(all(is.finite(I_by_scale)))
stopifnot(res$multiplicity$lost >= 0L)
stopifnot(is.na(max_se_ratio) || max_se_ratio >= 1)
stopifnot(file.exists(html) && file.info(html)$size > 5000)

cat(sprintf("[L3.5] Moran 各尺度 = %s ｜ 符号翻转 = %s\n",
            paste(sprintf("%.4f", I_by_scale), collapse = " → "),
            if (isTRUE(metrics$sign_flip)) "是" else "否"))
cat(sprintf("[L3.5] 原始显著 %d 个，校正后丢失 %d 个 ｜ SE 最大放大 %.2f 倍\n",
            res$multiplicity$raw_significant, res$multiplicity$lost, max_se_ratio))
cat(sprintf("[L3.5] 报告：%s\n", html))
