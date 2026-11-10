# =============================================================
# EpiStack · 端到端集成冒烟测试 + 契约 golden-file（W2）
#
# 用法：
#   Rscript tests/smoke_e2e.R              # 重跑六层链路，与 golden 基线逐项比对
#   Rscript tests/smoke_e2e.R --update    # 重新生成基线（须人工审阅 diff 后提交）
#
# 设计要点：
#   1. 链路在同一 R 会话里 source 执行，避免 Windows 中文路径经命令行
#      传给子进程时乱码；不引入 targets / testthat / jsonlite，纯 base R。
#   2. golden 分两部分：链路结果（固定种子的关键指标）+ 契约探针
#      （read_counts() 直接产出的字段/质控/权重），保证「换层不炸契约」。
#   3. 任何一条断言失败即 exit 1，供 CI 与每晚定时任务直接判定。
# =============================================================

args <- commandArgs(trailingOnly = TRUE)
do_update <- "--update" %in% args

a0 <- commandArgs(trailingOnly = FALSE)
f0 <- sub("^--file=", "", a0[grep("^--file=", a0)])
root <- Sys.getenv("EPISTACK_PROJECT_ROOT", unset = "")
if (!nzchar(root))
  root <- if (length(f0)) dirname(dirname(normalizePath(f0[1L]))) else getwd()

source(file.path(root, "R", "epi_json.R"), encoding = "UTF-8")
source(file.path(root, "bootstrap_core.R"), encoding = "UTF-8")
core_mode <- epi_bootstrap_core(file.path(root, "epi-core"), verbose = FALSE)

out_dir <- file.path(root, "tests", "_smoke_out")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
golden_path <- file.path(root, "tests", "golden", "vertical_slice_v0.1.0.json")

n_pass <- 0L; n_fail <- 0L
check <- function(ok, label, detail = "") {
  ok <- isTRUE(ok)
  if (ok) n_pass <<- n_pass + 1L else n_fail <<- n_fail + 1L
  cat(sprintf("  [%s] %s%s\n", if (ok) "PASS" else "FAIL", label,
              if (nzchar(detail)) paste0("  — ", detail) else ""))
}
get_path <- function(x, p) {
  for (k in strsplit(p, ".", fixed = TRUE)[[1L]]) {
    x <- if (is.list(x) && !is.null(x[[k]])) x[[k]] else return(NULL)
  }
  x
}

# ---------------- 1 · 重跑六层链路（固定种子 20261110） ----------------
cat("== 1. 重跑六层链路 ==\n")
Sys.setenv(EPISTACK_PROJECT_ROOT = root, EPISTACK_OUT_DIR = out_dir)
t0 <- Sys.time()
run_env <- new.env(parent = globalenv())
source(file.path(root, "vertical_slice", "run_e2e.R"),
       encoding = "UTF-8", local = run_env)
cat(sprintf("  链路耗时 %.2f 秒\n", as.numeric(difftime(Sys.time(), t0, units = "secs"))))

manifest_path <- file.path(out_dir, "run_manifest.json")
report_path   <- file.path(out_dir, "端到端演示报告.html")
alerts_path   <- file.path(out_dir, "alerts.csv")
check(file.exists(manifest_path), "L6 manifest 已生成")
stopifnot(file.exists(manifest_path))
m <- epi_json_read(manifest_path)

alerts <- utils::read.csv(alerts_path, fileEncoding = "UTF-8", stringsAsFactors = FALSE)
html <- paste(readLines(report_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

# ---------------- 2 · 契约探针（直接调用正式包） ----------------
cat("== 2. 契约探针 ==\n")
probe_raw <- data.frame(
  date = as.character(rep(as.Date("2021-01-04") + 7L * 0:6, 2L)),
  region = rep(c("陕西省", "广东省"), each = 7L),
  cases_est = c(3, 5, 4, 9, 7, 6, NA, 8, 9, 7, 11, 10, 8, 12),
  pop = rep(c(39500000, 127000000), each = 7L),
  stringsAsFactors = FALSE
)
probe_raw <- rbind(probe_raw, probe_raw[1L, ])      # 1 条重复 + 1 条缺失
probe_geo <- data.frame(region = c("陕西", "广东"),
                        population = c(39500000, 127000000),
                        row = c(1L, 1L), col = c(1L, 2L), ses = c(0.42, 0.78))
probe <- read_counts(probe_raw, geo = probe_geo, time_step = "week",
                     mapping = list(date = "date", region = "region",
                                    count = "cases_est", population = "pop"))

schema <- epi_json_read(file.path(root, "epi-core", "inst", "contract", "schema.json"))

observed <- list(
  # 链路结果
  "seed"                  = get_path(m, "seed"),
  "core.version"          = get_path(m, "core.version"),
  "inputs.rows"           = get_path(m, "inputs.rows"),
  "inputs.regions"        = get_path(m, "inputs.regions"),
  "qc.dropped"            = get_path(m, "qc.dropped"),
  "qc.duplicate"          = get_path(m, "qc.duplicate"),
  "qc.missing"            = get_path(m, "qc.missing"),
  "results.n_records"     = get_path(m, "results.n_records"),
  "results.n_alerts"      = get_path(m, "results.n_alerts"),
  "results.moran_I"       = get_path(m, "results.moran_I"),
  "results.moran_p"       = get_path(m, "results.moran_p"),
  "results.CI"            = get_path(m, "results.CI"),
  "results.rate_ratio"    = get_path(m, "results.rate_ratio"),
  # 契约探针
  "contract.version"      = epi_schema()$version,
  "contract.fields"       = paste(EPI_REQUIRED_FIELDS, collapse = ","),
  "probe.n_raw"           = probe$meta$n_raw,
  "probe.n_clean"         = probe$meta$n_clean,
  "probe.dropped"         = probe$qc$dropped,
  "probe.time_step"       = probe$meta$time_step,
  "probe.n_periods"       = probe$meta$n_periods,
  "probe.validate"        = as.integer(isTRUE(validate_contract(probe))),
  "probe.W_nrow"          = nrow(probe$W),
  "probe.W_ncol"          = ncol(probe$W),
  "probe.W_rowsum_min"    = min(rowSums(probe$W)),
  "probe.W_rowsum_max"    = max(rowSums(probe$W)),
  "probe.region_first"    = probe$geo$region[1L],
  "probe.schema_version"  = if (!is.null(schema$schema_version)) schema$schema_version else "n/a"
)

# ---------------- 3 · 结构性断言（不随算法替换而放宽） ----------------
cat("== 3. 结构性断言 ==\n")
check(identical(get_path(m, "contract"), "date, region, count, population, disease"),
      "契约字段串一致", as.character(get_path(m, "contract")))
stage_names <- vapply(m$stages, function(s) s$stage, character(1))
check(length(stage_names) >= 6L &&
        all(vapply(sprintf("L%d", 0:5), function(k) any(grepl(k, stage_names, fixed = TRUE)), logical(1))),
      "L0–L5 六个阶段均已执行", paste(stage_names, collapse = " / "))
check(all(file.exists(file.path(out_dir, "cache",
                                c("L0_contract.rds", "L2_alert.rds",
                                  "L3_space.rds", "L4_ineq.rds")))),
      "四层阶段缓存 rds 齐全")
check(file.exists(file.path(out_dir, "raw_counts.csv")), "原始面板只读导出存在")
check(nrow(alerts) == get_path(m, "results.n_alerts"), "告警 CSV 行数与 manifest 一致")
outbreak <- alerts[alerts$region == "地区10" & alerts$level == "告警", ]
check(nrow(outbreak) == 6L, "注入的 6 周暴发全部命中最高级告警",
      sprintf("命中 %d 周", nrow(outbreak)))
check(file.info(report_path)$size > 10000 &&
        all(vapply(c("端到端综合分析报告", "<svg", "流水线执行状态", "不可直接作为"),
                   function(k) grepl(k, html, fixed = TRUE), logical(1))),
      "单文件 HTML 完整（标题 / SVG / 阶段卡 / 方法说明）")
check(isTRUE(get_path(m, "privacy") != ""), "manifest 含隐私声明")

# ---------------- 4 · golden 更新或比对 ----------------
tolerance <- list(
  "results.moran_I" = 0.002, "results.moran_p" = 0.002,
  "results.CI" = 0.002, "results.rate_ratio" = 0.002,
  "probe.W_rowsum_min" = 1e-9, "probe.W_rowsum_max" = 1e-9
)
if (do_update) {
  golden <- list(
    golden_version = "0.1.0",
    note = "固定种子 20261110 的六层链路基线；仅当有意改变口径时经人工审阅后更新",
    seed = 20261110L,
    expected = observed,
    tolerance = tolerance
  )
  epi_json_write(golden, golden_path)
  cat(sprintf("\n[UPDATE] 已写入基线：%s（%d 项指标）\n",
              golden_path, length(observed)))
  cat("        请人工审阅 diff 后再提交；更新基线不等于修复回归。\n")
} else {
  cat("== 4. 与 golden 基线比对 ==\n")
  if (!file.exists(golden_path)) {
    cat("  [FAIL] golden 基线不存在，请先运行 Rscript tests/smoke_e2e.R --update\n")
    quit(save = "no", status = 1L, runLast = FALSE)
  }
  g <- epi_json_read(golden_path)
  ex <- g$expected
  for (k in names(ex)) {
    got <- observed[[k]]; want <- ex[[k]]
    tol <- if (!is.null(g$tolerance[[k]])) as.numeric(g$tolerance[[k]]) else 0
    ok <- if (is.character(want)) identical(as.character(got), as.character(want)) else
      !is.null(got) && is.finite(as.numeric(got)) &&
      abs(as.numeric(got) - as.numeric(want)) <= tol
    check(ok, sprintf("golden · %s", k),
          sprintf("期望 %s，实测 %s（容差 %g）", as.character(want),
                  if (is.null(got)) "NULL" else as.character(got), tol))
  }
  extra <- setdiff(names(observed), names(ex))
  check(length(extra) == 0L, "golden 覆盖全部观测指标",
        if (length(extra)) paste(extra, collapse = ", ") else "")
}

cat(sprintf("\n冒烟测试：%d PASS / %d FAIL ｜ 契约版本 %s ｜ 包加载方式 %s\n",
            n_pass, n_fail, epi_schema()$version, core_mode))
# 被 pipeline.R 内嵌调用时不退出，让编排把结果写进统一 manifest
if (n_fail > 0L && Sys.getenv("EPISTACK_SMOKE_NOQUIT", unset = "") != "1")
  quit(save = "no", status = 1L, runLast = FALSE)
