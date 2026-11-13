# =============================================================
# L1 · epiIngest 端到端演示（合成数据，CI 安全）
#
# 做的事：
#   1. 用内置生成器造 31 地区 × 36 月合成计数（无需任何真实数据）
#   2. 在副本上注入 6 类典型脏数据，演示规则命中与单文件质控单
#   3. 用干净数据一站式出契约，并与 epiCore::read_counts() 逐位比对
#   4. 写血缘 JSON 与指标 JSON
#
# 关键断言：ingest_counts() 的结果必须等于 read_counts() 再减去被规则剔除的行。
# 这条断言一旦红，说明 L1 换层动了口径，必须先解释清楚才能继续。
# =============================================================

root <- Sys.getenv("EPISTACK_PROJECT_ROOT", unset = "")
if (!nzchar(root)) {
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  root <- if (length(f)) dirname(dirname(normalizePath(f[1L]))) else getwd()
}
out <- Sys.getenv("EPISTACK_OUT_DIR", unset = file.path(root, "ingest_demo", "output"))
dir.create(out, recursive = TRUE, showWarnings = FALSE)

source(file.path(root, "bootstrap_core.R"), encoding = "UTF-8")
epi_bootstrap_core(file.path(root, "epi-core"))
source(file.path(root, "bootstrap_ingest.R"), encoding = "UTF-8")
epi_bootstrap_ingest(file.path(root, "epi-ingest"))

demo_dir <- file.path(out, "demo")
demo <- new.env(parent = globalenv())
sys.source(file.path(root, "demo", "make_demo_data.R"), envir = demo, keep.source = FALSE)
paths <- demo$epi_make_demo_data(demo_dir)
cat(sprintf("[L1] 合成计数：%s\n", basename(paths$counts)))

# ---- 1. 干净数据：画像 + 契约等价性 ----
ing  <- ingest_read(paths$counts)
prof <- ingest_profile(ing)
geo  <- unique(ing$data[, c("region", "population")])

rules_clean <- ingest_qc_default(geo, outlier_k = 8)
res_clean   <- qc_apply(ing, rules_clean)

core_new <- ingest_counts(paths$counts, rules = rules_clean, geo = geo, time_step = "month")
core_old <- epiCore::read_counts(paths$counts, geo = geo, time_step = "month",
                                 fileEncoding = "UTF-8")

kept <- res_clean$data
key <- function(d) paste(d$date, d$region, sep = "\r")
expect <- core_old$data[key(core_old$data) %in% key(kept), , drop = FALSE]
rownames(expect) <- NULL
eq_data <- isTRUE(all.equal(expect, core_new$data, check.attributes = FALSE))
eq_rows <- nrow(core_new$data) == nrow(core_old$data) - res_clean$dropped

# ---- 2. 脏数据副本：演示 6 类命中 ----
dirty <- ing$data
i_dup <- 5L
dirty <- rbind(dirty, dirty[i_dup, , drop = FALSE])       # 唯一键重复
dirty$count[10] <- NA                                      # 必填空值
dirty$count[20] <- -5                                      # 范围（负数）
dirty$count[30] <- 99999                                   # 范围 + 异常值
dirty$date[40]  <- as.Date("2099-01-01")                   # 未来日期
dirty$region[50] <- "ZZ"                                   # 未知地区编码
f_dirty <- file.path(out, "demo_counts_dirty.csv")
utils::write.csv(dirty, f_dirty, row.names = FALSE, fileEncoding = "UTF-8")

res_dirty <- qc_apply(ingest_read(f_dirty), rules_clean)
qc_report(res_dirty, file.path(out, "质控单.html"),
          title = "L1 质控单 · 合成月度面板（含 6 类注入问题）")
detected <- res_dirty$report$rule

# ---- 3. 血缘与指标 ----
lin <- ingest_lineage(core_new)
ingest_lineage_write(lin, file.path(out, "ingest_lineage.json"))

write_json <- function(x, path) {
  f <- if (exists("epi_json_write", mode = "function")) epi_json_write
       else if (exists(".epi_json_write", mode = "function")) .epi_json_write
       else get(".epi_json_write", envir = asNamespace("epiIngest"))
  f(x, path)
}

metrics <- list(
  generated_at       = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
  rows_read          = prof$n_rows,
  n_regions          = prof$n_region,
  date_range         = format(prof$date_range),
  duplicate_keys     = prof$duplicate_keys,
  rules              = rules_clean$name %||% "custom",
  clean_dropped      = res_clean$dropped,
  contract_rows      = nrow(core_new$data),
  contract_version   = core_new$meta$version,
  equivalence        = eq_data && eq_rows,
  equivalence_detail = list(data_identical = eq_data, rows_consistent = eq_rows),
  dirty_rows         = res_dirty$n_input,
  dirty_detected     = as.list(detected),
  dirty_dropped      = res_dirty$dropped,
  dirty_warn_rows    = res_dirty$n_warn,
  report_bytes       = file.info(file.path(out, "质控单.html"))$size
)
write_json(metrics, file.path(out, "ingest_metrics.json"))

cat(sprintf("[L1] 干净数据 %d 行 / %d 地区 ｜ 剔除 %d 行 ｜ 契约 %d 行\n",
            prof$n_rows, prof$n_region, res_clean$dropped, nrow(core_new$data)))
cat(sprintf("[L1] 与 read_counts() 等价：%s\n", if (eq_data && eq_rows) "是" else "否"))
cat(sprintf("[L1] 注入脏数据 %d 行 ｜ 命中 %d 类规则 ｜ 剔除 %d 行 ｜ warn %d 行\n",
            res_dirty$n_input, length(detected), res_dirty$dropped, res_dirty$n_warn))

if (!eq_data || !eq_rows)
  stop(sprintf("L1 与 epiCore::read_counts() 不等价（data=%s, rows=%s）", eq_data, eq_rows),
       call. = FALSE)
if (length(detected) < 5L)
  stop(sprintf("注入的脏数据没有全部命中，只识别出 %d 类：%s",
               length(detected), paste(detected, collapse = ", ")), call. = FALSE)
