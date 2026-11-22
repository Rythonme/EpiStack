# =============================================================
# L3 · epiSpace 端到端演示（合成数据）
#
# 做的事：
#   1. 内置 4×4 格网合成计数，经 L0 契约转成统一输入
#   2. 用 space_counts() 一次算出全局 Moran、局部 LISA 与热点
#   3. 断言：注入的空间聚集被识别为热点，格局落在注入角落
#   4. 产出单文件分析单、逐地区 CSV、指标 JSON 与 BYM2 模板
#
# 注意：主仓切片 vertical_slice 的 Moran 沿用历史地区顺序（与 golden 对齐）；
# 本演示用 space_counts() 的地区对齐口径，是新代码推荐的用法。
# =============================================================

root <- Sys.getenv("EPISTACK_PROJECT_ROOT", unset = "")
if (!nzchar(root)) {
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  root <- if (length(f)) dirname(dirname(normalizePath(f[1L]))) else getwd()
}
out <- Sys.getenv("EPISTACK_OUT_DIR", unset = file.path(root, "space_demo", "output"))
dir.create(out, recursive = TRUE, showWarnings = FALSE)

source(file.path(root, "bootstrap_core.R"), encoding = "UTF-8")
core_mode <- epi_bootstrap_core(file.path(root, "epi-core"))
source(file.path(root, "bootstrap_space.R"), encoding = "UTF-8")
space_mode <- epi_bootstrap_space(file.path(root, "epi-space"))

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
d <- space_example()
geo <- unique(d[, c("region", "row", "col")])
geo$pop <- 1e5
core <- read_counts(d, geo = geo, time_step = "year")
cat(sprintf("[L3] 契约 %d 行 / %d 地区 / 粒度 %s（%s）\n",
            nrow(core$data), nrow(core$geo), core$meta$time_step, core_mode))

# ---- 2. 全局 + 局部 + 热点 ----
x <- space_counts(core, seed = 20261111L)
hs <- x$hotspots
hot <- hs[hs$category == "热点", , drop = FALSE]
hit <- "R16" %in% hot$region
grid <- geo[match(hot$region, geo$region), , drop = FALSE]
corner <- all(grid$row >= 3L & grid$col >= 3L)
global_ok <- x$global$I > 0 && !is.na(x$global$p) && x$global$p < 0.05

# ---- 3. 产物 ----
html <- file.path(out, "空间分析单.html")
space_report(x, html, title = "L3 空间分析单 · 合成格网（注入角落聚集）")
space_report(x, file.path(out, "lisa_regions.csv"), format = "csv")
tpl <- space_bym2_template(core)
writeLines(c(tpl$graph_code, "", "# ---- INLA 模型 ----", "", tpl$code),
           file.path(out, "bym2_template.R"), useBytes = TRUE)

metrics <- list(
  generated_at    = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
  contract_rows   = nrow(core$data),
  n_regions       = x$meta$n_regions,
  year            = if (is.null(x$meta$year)) "NA" else as.character(x$meta$year),
  moran_I         = round(x$global$I, 6),
  moran_p         = round(x$global$p, 6),
  n_perm          = x$settings$n_perm,
  n_hotspots      = nrow(hot),
  n_coldspots     = sum(hs$category == "冷点"),
  n_outliers      = sum(hs$category == "空间离群"),
  injected_hit    = hit,
  hotspots_in_corner = corner,
  report_bytes    = file.info(html)$size,
  space_mode      = space_mode
)
json_write(metrics, file.path(out, "space_metrics.json"))

cat(sprintf("[L3] 全局 Moran's I = %.4f ｜ p = %.4f（%d 次置换）\n",
            x$global$I, x$global$p, x$settings$n_perm))
cat(sprintf("[L3] 热点 %d ｜ 冷点 %d ｜ 空间离群 %d ｜ 注入角落命中：%s\n",
            nrow(hot), sum(hs$category == "冷点"),
            sum(hs$category == "空间离群"), hit))
cat(sprintf("[L3] 热点全部落在注入角落：%s ｜ 全局显著：%s\n", corner, global_ok))

if (!hit) stop("注入的空间聚集没有被识别为热点", call. = FALSE)
if (!corner) stop("热点没有落在注入角落，空间对齐可能有问题", call. = FALSE)
if (!global_ok) stop("全局 Moran 检验未达到显著", call. = FALSE)
