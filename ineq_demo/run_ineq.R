# =============================================================
# L4 · epiIneq 端到端演示（合成数据）
#
# 做的事：
#   1. 内置 4×4 虚构格网（SES 左低右高、率左高右低），经 L0 契约转成统一输入
#   2. 用 ineq_counts() 一次算出集中曲线/CI、SII、Gini、分解与距离衰减可达性
#   3. 断言：CI < 0、SII < 0、低/高 SES 率比 > 1（弱势负担更重）且口径一致
#   4. 产出单文件不平等分析单、分组/曲线 CSV、指标 JSON 与方法表
#
# 说明：主仓切片与面板的 CI/率比沿用各自历史分组口径（cut=0.5 / median），
#       本演示用包默认口径，是新代码推荐的用法；两者在同一份数据上逐位一致。
# =============================================================

root <- Sys.getenv("EPISTACK_PROJECT_ROOT", unset = "")
if (!nzchar(root)) {
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  root <- if (length(f)) dirname(dirname(normalizePath(f[1L]))) else getwd()
}
out <- Sys.getenv("EPISTACK_OUT_DIR", unset = file.path(root, "ineq_demo", "output"))
dir.create(out, recursive = TRUE, showWarnings = FALSE)

source(file.path(root, "bootstrap_core.R"), encoding = "UTF-8")
core_mode <- epi_bootstrap_core(file.path(root, "epi-core"))
source(file.path(root, "bootstrap_ineq.R"), encoding = "UTF-8")
ineq_mode <- epi_bootstrap_ineq(file.path(root, "epi-ineq"))

json_write <- function(x, path) {
  atom <- function(v) {
    if (is.null(v) || length(v) == 0L) return("null")
    if (is.character(v)) return(paste0("\"", gsub("\"", "\\\\\"", v), "\""))
    if (is.logical(v)) return(ifelse(v, "true", "false"))
    if (is.numeric(v)) return(format(v, scientific = FALSE, trim = TRUE))
    paste0("\"", as.character(v), "\"")
  }
  lines <- vapply(names(x), function(nm) {
    v <- x[[nm]]
    if (is.list(v))
      sprintf("  \"%s\": {%s}", nm,
              paste(sprintf("\"%s\": %s", names(v), vapply(v, atom, character(1))),
                    collapse = ", "))
    else sprintf("  \"%s\": %s", nm, atom(v))
  }, character(1))
  writeLines(c("{", paste(lines, collapse = ",\n"), "}"), path, useBytes = TRUE)
}

# ---- 1. 合成格网 → 契约 ----
d <- ineq_example()
# read_counts() 只保留契约列，SES 与坐标放 geo（每地区取一个代表值）
geo <- unique(d[, c("region", "x", "y")])
geo$ses <- d$ses[match(geo$region, d$region)]
core <- read_counts(d, geo = geo, time_step = "year")
cat(sprintf("[L4] 契约 %d 行 / %d 地区 / 粒度 %s（%s）\n",
            nrow(core$data), nrow(core$geo), core$meta$time_step, core_mode))

# ---- 2. 一站式不平等分析 ----
x <- ineq_counts(core)
ci <- x$ci
sii <- x$core$SII
ratio <- x$core$rate_ratio
gini <- x$gini
# 方向一致才叫证据：CI、SII 均为负且率比 > 1，说明负担偏向低 SES
consistent <- ci < 0 && is.finite(sii) && sii < 0 && is.finite(ratio) && ratio > 1
# 集中曲线与 CI 手算一致
area_manual <- sum((x$curve$curve$cum_pop - c(0, head(x$curve$curve$cum_pop, -1L))) *
                   (x$curve$curve$cum_value + c(0, head(x$curve$curve$cum_value, -1L))) / 2)
curve_ok <- abs(ci - (1 - 2 * area_manual)) < 1e-9

# ---- 3. 产物 ----
html <- file.path(out, "不平等分析单.html")
ineq_report(x, "html", file = html)
ineq_report(x, "csv", file = file.path(out, "ineq_groups.csv"))
write.csv(ineq_methods(), file.path(out, "ineq_methods.csv"),
          row.names = FALSE, fileEncoding = "UTF-8")

metrics <- list(
  generated_at    = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
  contract_rows   = nrow(core$data),
  n_regions       = x$meta$n,
  year            = if (is.null(x$meta$year)) "NA" else as.character(x$meta$year),
  ci              = round(ci, 6),
  sii             = round(sii, 6),
  rate_ratio      = round(ratio, 6),
  gini            = round(gini, 6),
  paf             = round(x$core$paf, 6),
  between_share   = round(x$core$between_share, 6),
  access_ratio    = round(x$core$access_ratio, 6),
  n_summary       = nrow(x$summary),
  direction_consistent = consistent,
  curve_ci_matches     = curve_ok,
  report_bytes    = file.info(html)$size,
  ineq_mode       = ineq_mode
)
json_write(metrics, file.path(out, "ineq_metrics.json"))

cat(sprintf("[L4] CI = %.4f ｜ SII = %.4f ｜ 低/高 SES 率比 = %.2f ｜ Gini = %.3f\n",
            ci, sii, ratio, gini))
cat(sprintf("[L4] 弱势负担方向一致：%s ｜ 曲线/CI 自洽：%s\n", consistent, curve_ok))

if (!consistent) stop("CI / SII / 率比方向不一致，请检查 SES 与率的注入", call. = FALSE)
if (!curve_ok) stop("集中曲线与 CI 手算不一致", call. = FALSE)
