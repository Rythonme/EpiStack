# =============================================================
# L2 · epiAlert 端到端演示（合成数据，CI 安全）
#
# 做的事：
#   1. 用内置生成器造 31 地区 × 36 月合成计数，经 L1 出契约
#   2. 在末期给一个地区注入 3 个月暴发（已知答案）
#   3. 回溯评估（assess = "all"）与当期评估（assess = "latest"）各跑一遍
#   4. 断言：注入的暴发被评为预警/告警；基线只用更早年份，不被自身抬升
#
# 这条断言一旦红，说明换层动了口径或基线漏了未来信息，必须先解释清楚。
# =============================================================

root <- Sys.getenv("EPISTACK_PROJECT_ROOT", unset = "")
if (!nzchar(root)) {
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  root <- if (length(f)) dirname(dirname(normalizePath(f[1L]))) else getwd()
}
out <- Sys.getenv("EPISTACK_OUT_DIR", unset = file.path(root, "alert_demo", "output"))
dir.create(out, recursive = TRUE, showWarnings = FALSE)

source(file.path(root, "bootstrap_core.R"), encoding = "UTF-8")
epi_bootstrap_core(file.path(root, "epi-core"))
source(file.path(root, "bootstrap_ingest.R"), encoding = "UTF-8")
epi_bootstrap_ingest(file.path(root, "epi-ingest"))
source(file.path(root, "bootstrap_alert.R"), encoding = "UTF-8")
alert_mode <- epi_bootstrap_alert(file.path(root, "epi-alert"))

json_write <- local({
  if (exists(".epi_json_write", mode = "function")) .epi_json_write
  else get(".epi_json_write", envir = asNamespace("epiAlert"))
})

# ---- 1. 合成计数 → 契约 ----
demo_dir <- file.path(out, "demo")
demo <- new.env(parent = globalenv())
sys.source(file.path(root, "demo", "make_demo_data.R"), envir = demo, keep.source = FALSE)
paths <- demo$epi_make_demo_data(demo_dir)
core <- ingest_counts(paths$counts, time_step = "month")
d <- core$data
cat(sprintf("[L2] 契约 %d 行 / %d 地区 / 粒度 %s\n",
            nrow(d), length(unique(d$region)), core$meta$time_step))

# ---- 2. 注入已知暴发：最后一个地区、最后 3 个月 ----
regs <- sort(unique(d$region))
hit_region <- utils::tail(regs, 1L)
last_periods <- utils::tail(sort(unique(d$date)), 3L)
ix <- d$region == hit_region & d$date %in% last_periods
d$count[ix] <- as.integer(round(d$count[ix] * 3 + 10))
cat(sprintf("[L2] 注入暴发：%s 共 %d 期（%s 起）\n",
            hit_region, sum(ix), format(min(d$date[ix]))))

# ---- 3. 回溯与当期各跑一遍 ----
retro  <- alert_counts(d, assess = "all")
latest <- alert_counts(d, assess = "latest")

# ---- 4. 断言 ----
hit <- retro$alerts[retro$alerts$region == hit_region &
                      retro$alerts$date %in% last_periods, , drop = FALSE]
hit_serious <- hit[hit$level %in% c("预警", "告警"), , drop = FALSE]
ok_hit  <- nrow(hit_serious) >= 2L
ok_now  <- any(latest$alerts$region == hit_region)
# 基线不含未来信息：暴发期的历史观测数应与同期其它年一致（3 期窗口 × 2 年 = 6）
band_hit <- retro$band[retro$band$region == hit_region &
                         retro$band$date %in% last_periods, , drop = FALSE]
ok_nohist <- all(band_hit$n_hist <= 6L)
# 未注入地区不应出现告警
ok_quiet <- !any(retro$alerts$level[retro$alerts$region != hit_region] == "告警")

# ---- 5. 产物 ----
rules_file <- file.path(out, "alert_rules.json")
alert_rules_write(retro$settings$rules, rules_file)
alert_report(retro, file.path(out, "预警单_回溯.html"),
             title = sprintf("L2 预警单 · 合成月报（回溯评估，注入 %s 暴发）", hit_region))
alert_report(retro, file.path(out, "alerts_retro.csv"), format = "csv")

lvl <- function(x, l) sum(x$current$level == l)
metrics <- list(
  generated_at     = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
  contract_rows    = nrow(d),
  n_regions        = length(regs),
  time_step        = core$meta$time_step,
  method           = retro$settings$method,
  targets_all      = retro$meta$n_targets,
  targets_latest   = latest$meta$n_targets,
  band_missing     = retro$meta$n_band_missing,
  level_all        = list(watch = lvl(retro, "关注"), warn = lvl(retro, "预警"),
                          alarm = lvl(retro, "告警")),
  level_latest     = list(watch = lvl(latest, "关注"), warn = lvl(latest, "预警"),
                          alarm = lvl(latest, "告警")),
  injected_region  = hit_region,
  injected_periods = length(last_periods),
  injected_hit     = nrow(hit_serious),
  quiet_elsewhere  = ok_quiet,
  report_bytes     = file.info(file.path(out, "预警单_回溯.html"))$size,
  alert_mode       = alert_mode
)
json_write(metrics, file.path(out, "alert_metrics.json"))

cat(sprintf("[L2] 回溯评估 %d 期 ｜ 关注 %d / 预警 %d / 告警 %d（基线不足 %d 期）\n",
            retro$meta$n_targets, lvl(retro, "关注"), lvl(retro, "预警"),
            lvl(retro, "告警"), retro$meta$n_band_missing))
cat(sprintf("[L2] 当期评估 %d 期 ｜ 关注 %d / 预警 %d / 告警 %d\n",
            latest$meta$n_targets, lvl(latest, "关注"), lvl(latest, "预警"),
            lvl(latest, "告警")))
cat(sprintf("[L2] 注入暴发命中 %d/%d 期 ｜ 其它地区无误报：%s ｜ 基线只看更早年份：%s\n",
            nrow(hit_serious), length(last_periods), ok_quiet, ok_nohist))

if (!ok_hit) stop(sprintf("注入的暴发没有被识别：只有 %d 期达到预警及以上", nrow(hit_serious)),
                  call. = FALSE)
if (!ok_now) stop("当期评估没有发现注入的暴发", call. = FALSE)
if (!ok_nohist) stop("暴发期的基线混入了同期数据（历史观测数异常偏多）", call. = FALSE)
