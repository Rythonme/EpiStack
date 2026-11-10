# =============================================================
# EpiStack · 主仓统一编排入口（targets 雏形，W2）
#
# 用法：
#   Rscript pipeline.R                 # 跑合成数据六层切片（CI 安全，默认）
#   Rscript pipeline.R --all          # 额外跑 HFRS 真实数据链路（仅本机有数据时）
#   Rscript pipeline.R --check        # 跑链路 + golden 集成冒烟测试
#   Rscript pipeline.R --force        # 忽略指纹缓存，强制重跑
#   Rscript pipeline.R --list         # 只打印分层计划
#   Rscript pipeline.R --out <目录>   # 自定义产物目录（默认 pipeline_out/）
#
# 设计：声明式分层计划（R/pipeline_plan.R）+ 输入指纹缓存 + 阶段产物校验，
# 用 base R 复现 targets 的 skip-if-unchanged 语义；不装 targets 也能一条命令跑通。
# 真实数据链路只在本机执行，产物落 pipeline_out/ 且不入库、不发布。
# =============================================================

cli_args <- commandArgs(trailingOnly = TRUE)
a0 <- commandArgs(trailingOnly = FALSE)
f0 <- sub("^--file=", "", a0[grep("^--file=", a0)])
root <- Sys.getenv("EPISTACK_PROJECT_ROOT", unset = "")
if (!nzchar(root))
  root <- if (length(f0)) dirname(normalizePath(f0[1L])) else getwd()

source(file.path(root, "R", "epi_json.R"), encoding = "UTF-8")
source(file.path(root, "R", "pipeline_plan.R"), encoding = "UTF-8")
plan <- EPI_STACK_PLAN

flag <- function(x) x %in% cli_args
ix_out <- match("--out", cli_args)
out_root <- if (!is.na(ix_out) && length(cli_args) >= ix_out + 1L)
  cli_args[ix_out + 1L] else file.path(root, "pipeline_out")
dir.create(out_root, recursive = TRUE, showWarnings = FALSE)

# ---------------- --list：只打印计划 ----------------
if (flag("--list")) {
  cat(sprintf("EpiStack 分层计划 v%s ｜ 契约 v%s ｜ 种子 %d\n\n",
              plan$plan_version, plan$contract_version, plan$seed))
  cat("层  仓库          实现状态  当前实现                              上线月份\n")
  for (l in plan$layers)
    cat(sprintf("%-3s %-13s %-8s %-36s %s\n", l$id, l$name,
                l$current_impl, l$impl, l$since))
  cat("\n流水线：\n")
  for (p in plan$pipelines)
    cat(sprintf("  %-15s %s ｜ 数据=%s ｜ 层数=%d ｜ 本地依赖=%d\n",
                p$id, p$label, p$privacy, length(p$layers), length(p$requires)))
  quit(save = "no", status = 0L, runLast = FALSE)
}

# ---------------- 输入指纹（targets 语义的核心） ----------------
fingerprint <- function(rel_files) {
  parts <- vapply(rel_files, function(rel) {
    f <- file.path(root, rel)
    if (!file.exists(f)) return(paste0(rel, "=MISSING"))
    h <- tryCatch(unname(tools::md5sum(f)), error = function(e) NA_character_)
    if (is.na(h)) {
      i <- file.info(f)
      h <- sprintf("mtime=%s,size=%s", as.character(i$mtime), i$size)
    }
    paste0(rel, "=", h)
  }, character(1))
  paste(parts, collapse = ";")
}

state_path <- file.path(out_root, "state.json")
state <- if (file.exists(state_path)) epi_json_read(state_path) else list()

run_stage <- function(p, force = FALSE) {
  od <- file.path(out_root, p$id)
  dir.create(od, recursive = TRUE, showWarnings = FALSE)

  missing <- p$requires[!file.exists(p$requires)]
  if (length(missing)) {
    cat(sprintf("[%s] SKIP ｜ 缺少 %d 个本地只读数据源（CI 环境预期行为）\n",
                p$id, length(missing)))
    return(list(id = p$id, label = p$label, layers = p$layers,
                privacy = p$privacy, status = "skipped_missing_data",
                missing = unname(missing), elapsed_sec = 0))
  }

  fp <- fingerprint(c(p$inputs, plan$shared_inputs))
  outs_ok <- all(file.exists(file.path(od, p$outputs)))
  prev <- state[[p$id]]
  if (!force && !is.null(prev) && identical(prev$fingerprint, fp) && outs_ok) {
    cat(sprintf("[%s] SKIP ｜ 输入指纹未变且产物齐全（targets skip-if-unchanged）\n", p$id))
    return(list(id = p$id, label = p$label, layers = p$layers,
                privacy = p$privacy, status = "cached",
                elapsed_sec = 0, outputs = p$outputs))
  }

  # 同一会话内 source：避免 Windows 中文路径经命令行传给子进程乱码
  Sys.setenv(EPISTACK_PROJECT_ROOT = root, EPISTACK_OUT_DIR = od)
  env <- new.env(parent = globalenv())
  t0 <- Sys.time()
  err <- NULL
  ok <- tryCatch({
    source(file.path(root, p$script), encoding = "UTF-8", local = env)
    TRUE
  }, error = function(e) { err <<- conditionMessage(e); FALSE })
  secs <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 2)
  if (!ok) {
    cat(sprintf("[%s] FAIL ｜ %s\n", p$id, err))
    return(list(id = p$id, label = p$label, layers = p$layers,
                privacy = p$privacy, status = "failed",
                elapsed_sec = secs, error = err))
  }
  ok_out <- all(file.exists(file.path(od, p$outputs)))
  cat(sprintf("[%s] DONE ｜ %.2f 秒 ｜ 产物 %d/%d ｜ 数据=%s\n",
              p$id, secs, sum(file.exists(file.path(od, p$outputs))),
              length(p$outputs), p$privacy))
  list(id = p$id, label = p$label, layers = p$layers,
       privacy = p$privacy, status = if (ok_out) "ran" else "incomplete",
       elapsed_sec = secs, outputs = p$outputs,
       fingerprint = fp, outputs_ok = ok_out)
}

# ---------------- 生成静态报告站（仅合成数据） ----------------
build_site <- function(results) {
  site <- file.path(out_root, "site")
  dir.create(site, recursive = TRUE, showWarnings = FALSE)
  copy <- function(from, to) if (file.exists(from))
    file.copy(from, file.path(site, to), overwrite = TRUE)
  copy(file.path(out_root, "vertical_slice", "端到端演示报告.html"), "report.html")
  copy(file.path(root, "项目进展看板.html"), "kanban.html")
  copy(file.path(root, "kanban_data.js"), "kanban_data.js")

  rows <- paste(vapply(results, function(r)
    sprintf('<tr><td>%s</td><td>%s</td><td>%.2f</td><td>%s</td></tr>',
            r$id, r$status, as.numeric(r$elapsed_sec), r$privacy), character(1)),
    collapse = "\n")
  idx <- paste0(
    '<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8">',
    '<meta name="viewport" content="width=device-width,initial-scale=1">',
    '<title>EpiStack · 示例报告站</title><style>',
    'body{margin:0;background:#f4f7fb;color:#243447;font-family:"Microsoft YaHei",',
    '-apple-system,Segoe UI,sans-serif;line-height:1.6}',
    '.w{max-width:900px;margin:0 auto;padding:34px 22px 60px}',
    'h1{font-size:26px;margin:0 0 6px} .sub{color:#61748c;font-size:14px;margin:0 0 22px}',
    '.cards{display:grid;grid-template-columns:1fr 1fr;gap:14px;margin-bottom:24px}',
    'a.card{display:block;background:#fff;border:1px solid #e3e9f0;border-radius:12px;',
    'padding:20px;text-decoration:none;color:#185fa5;font-weight:600}',
    'a.card small{display:block;color:#7a8899;font-weight:400;margin-top:6px}',
    '.box{background:#fff;border:1px solid #e3e9f0;border-radius:12px;padding:18px 22px;margin-bottom:16px}',
    'table{border-collapse:collapse;width:100%;font-size:14px}',
    'td,th{border-bottom:1px solid #eef2f6;padding:8px 10px;text-align:left}',
    '.note{background:#fff7ed;border-left:5px solid #e67e22;padding:12px 16px;',
    'border-radius:8px;font-size:13px;color:#7a4b12}</style></head><body><div class="w">',
    '<h1>EpiStack · 示例报告站</h1>',
    '<p class="sub">端到端传染病时空分析与健康不平等体系 ｜ 契约 v', plan$contract_version,
    ' ｜ 生成于 ', format(Sys.time(), "%Y-%m-%d %H:%M"), '</p>',
    '<div class="cards">',
    '<a class="card" href="report.html">端到端演示报告<small>合成数据 · 六层链路 · 单文件离线 HTML</small></a>',
    '<a class="card" href="kanban.html">项目进展看板<small>主线任务、里程碑与月度路线图</small></a>',
    '</div>',
    '<div class="box"><h3>本次编排执行状态</h3><table>',
    '<tr><th>流水线</th><th>状态</th><th>耗时(秒)</th><th>数据</th></tr>', rows,
    '</table></div>',
    '<div class="note"><b>隐私声明：</b>本页仅发布<b>合成数据</b>报告与项目看板。',
    'HFRS 真实监测数据及其分析报告只在本机执行，不入库、不上传、不发布。</div>',
    '</div></body></html>')
  writeLines(enc2utf8(idx), file.path(site, "index.html"), useBytes = TRUE)
  invisible(site)
}

# ---------------- 主流程 ----------------
cat(sprintf("EpiStack pipeline v%s ｜ R %s ｜ 契约 v%s ｜ 产物 %s\n",
            plan$plan_version, getRversion(), plan$contract_version, out_root))
todo <- plan$pipelines
if (!flag("--all"))
  todo <- Filter(function(p) identical(p$privacy, "synthetic"), todo)

results <- lapply(todo, run_stage, force = flag("--force"))
names(results) <- vapply(results, function(r) r$id, character(1))

smoke <- NULL
if (flag("--check")) {
  cat("\n== 集成冒烟测试（golden 比对） ==\n")
  # 被编排 source 时显式注入根目录（此时 --file= 指向 pipeline.R）
  Sys.setenv(EPISTACK_PROJECT_ROOT = root,
             EPISTACK_SMOKE_NOQUIT = "1")
  senv <- new.env(parent = globalenv())
  s_ok <- tryCatch({
    source(file.path(root, "tests", "smoke_e2e.R"), encoding = "UTF-8", local = senv)
    TRUE
  }, error = function(e) { cat("  冒烟测试异常：", conditionMessage(e), "\n"); FALSE })
  smoke <- list(executed = TRUE, ok = s_ok,
                pass = if (s_ok) senv$n_pass else 0L,
                fail = if (s_ok) senv$n_fail else NA_integer_)
  Sys.unsetenv("EPISTACK_SMOKE_NOQUIT")
}

site_dir <- build_site(results)

# 缓存状态与统一 manifest
new_state <- state            # 保留未变阶段（cached / skipped）的历史指纹
for (r in results) if (!is.null(r$fingerprint))
  new_state[[r$id]] <- list(fingerprint = r$fingerprint,
                            status = r$status,
                            updated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
epi_json_write(new_state, state_path)

manifest <- list(
  pipeline = "EpiStack pipeline v0.1.1",
  plan_version = plan$plan_version,
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
  r_version = R.version.string,
  seed = plan$seed,
  contract = plan$contract,
  contract_version = plan$contract_version,
  args = unname(cli_args),
  layers = lapply(plan$layers, function(l) list(
    id = l$id, name = l$name, impl = l$current_impl,
    satellite = l$satellite, since = l$since)),
  stages = unname(lapply(results, function(r) r[setdiff(names(r), "fingerprint")])),
  smoke = if (is.null(smoke)) list(executed = FALSE) else smoke,
  site = list(path = site_dir,
              privacy = "仅合成数据报告与看板；真实数据链路产物不发布"),
  reproduce = "Rscript pipeline.R --check",
  privacy = "原始监测数据只读；真实数据与本地报告不入库、不上传"
)
epi_json_write(manifest, file.path(out_root, "pipeline_manifest.json"))

failed <- vapply(results, function(r) r$status %in% c("failed", "incomplete"), logical(1))
smoke_bad <- !is.null(smoke) &&
  (!isTRUE(smoke$ok) ||
     (is.numeric(smoke$fail) && !is.na(smoke$fail) && smoke$fail > 0L))
cat(sprintf("\n编排完成：%d 个阶段（%d ran / %d cached / %d skipped / %d failed）｜ 站点 %s\n",
            length(results), sum(vapply(results, function(r) r$status, character(1)) == "ran"),
            sum(vapply(results, function(r) r$status, character(1)) == "cached"),
            sum(vapply(results, function(r) r$status, character(1)) == "skipped_missing_data"),
            sum(failed), site_dir))
if (any(failed) || smoke_bad)
  quit(save = "no", status = 1L, runLast = FALSE)
