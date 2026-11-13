# =============================================================
# EpiStack · 分层编排计划（targets 雏形，W2）
#
# 这是主仓唯一需要「每月改一行」的地方：把某一层的 current_impl
# 从 thin 改成 formal、把 impl 指向当月卫星仓即可，上下游契约不变。
#
# 当前用「声明式计划 + 输入指纹缓存 + 阶段 rds」模拟 targets 的核心语义：
#   * 每个 stage 声明输入（脚本与包源码）、输出、依赖层
#   * 指纹未变且产物齐全则跳过（targets 的 skip-if-unchanged）
#   * 统一 manifest 记录每阶段状态、耗时、契约版本
# 2027-08 的 epi-flow 卫星仓会把本计划翻译成真正的 targets 管道，
# 届时替换执行器即可，不改本文件描述的层级与产物契约。
# =============================================================

# 本机私有数据源路径解析：公开仓库不含任何绝对路径。
# 优先环境变量 EPISTACK_HFRS_INCIDENCE / _GRAPH / _SES，其次读取不入库的
# case_hfrs_real/data_paths.local.R；未配置时返回不存在的哨兵，
# 使该阶段在 CI 与他人机器上自动 skipped_missing_data。
epi_local_requires <- function(root = getwd()) {
  keys <- c("incidence", "graph", "ses")
  p <- stats::setNames(rep("", length(keys)), keys)
  cfg <- file.path(root, "case_hfrs_real", "data_paths.local.R")
  if (file.exists(cfg)) {
    e <- new.env(parent = baseenv())
    try(sys.source(cfg, envir = e), silent = TRUE)
    if (exists("DATA", envir = e, inherits = FALSE)) {
      d <- get("DATA", envir = e, inherits = FALSE)
      for (k in keys) if (k %in% names(d)) p[[k]] <- as.character(d[[k]][1L])
    }
  }
  for (k in keys) {
    ev <- Sys.getenv(paste0("EPISTACK_HFRS_", toupper(k)), unset = "")
    if (nzchar(ev)) p[[k]] <- ev
  }
  v <- unname(unlist(p))
  ifelse(nzchar(v), v, "EPISTACK_LOCAL_DATA_NOT_CONFIGURED")
}

EPI_STACK_PLAN <- list(
  plan_version     = "0.1.0",
  contract_version = "0.1.0",
  seed             = 20261110L,
  contract         = "date, region, count, population, disease",
  layers = list(
    list(id = "L0", name = "epi-core",    role = "统一契约 / 地区编码 / 邻接权重",
         current_impl = "formal", impl = "epi-core/R/*.R", satellite = "epi-core",    since = "2026-11"),
    list(id = "L1", name = "epi-ingest",  role = "多源读取与质控",
         current_impl = "formal", impl = "epi-ingest/R/*.R", satellite = "epi-ingest",  since = "2026-12"),
    list(id = "L2", name = "epi-alert",   role = "季节性基线带与异常信号",
         current_impl = "thin",   impl = "vertical_slice / case_hfrs_real 内置", satellite = "epi-alert",   since = "2027-01"),
    list(id = "L3", name = "epi-space",   role = "空间自相关 / BYM2 / 景观格局",
         current_impl = "thin",   impl = "内置 Moran's I 置换检验", satellite = "epi-space",   since = "2027-02"),
    list(id = "L4", name = "epi-ineq",    role = "集中指数 / SII / 可达性",
         current_impl = "thin",   impl = "内置人口加权集中曲线", satellite = "epi-ineq",    since = "2027-04"),
    list(id = "L5", name = "epi-report",  role = "单文件 HTML 报告与看板",
         current_impl = "thin",   impl = "手写内联 SVG，零 pandoc", satellite = "epi-report",  since = "2027-06"),
    list(id = "L6", name = "epi-flow",    role = "编排 / 缓存 / 可复现清单",
         current_impl = "thin",   impl = "pipeline.R + manifest + golden", satellite = "epi-flow",    since = "2027-08")
  ),
  # 每条流水线是一个可独立运行的 stage；requires 里的本地真实数据缺失时自动跳过，
  # 因此 CI（无本机数据）也能完整跑通并发布合成数据报告。
  pipelines = list(
    list(
      id = "vertical_slice", label = "合成数据六层切片（CI 安全）",
      script = "vertical_slice/run_e2e.R",
      layers = c("L0", "L1", "L2", "L3", "L4", "L5", "L6"),
      privacy = "synthetic", requires = character(0),
      inputs = c("vertical_slice/run_e2e.R"),
      outputs = c("端到端演示报告.html", "run_manifest.json", "alerts.csv",
                  "raw_counts.csv", "cache/L0_contract.rds"),
      report = "端到端演示报告.html"
    ),
    list(
      id = "ingest_l1", label = "L1 接入层演示：读取 → 规则质控 → 契约等价性",
      script = "ingest_demo/run_ingest.R",
      layers = c("L0", "L1"),
      privacy = "synthetic", requires = character(0),
      inputs = c("ingest_demo/run_ingest.R", "demo/make_demo_data.R"),
      outputs = c("质控单.html", "ingest_metrics.json", "ingest_lineage.json"),
      report = "质控单.html"
    ),
    list(
      id = "panel_demo", label = "模拟面板端到端演示（CI 安全，公开默认）",
      script = "case_hfrs_real/run_hfrs.R",
      layers = c("L0", "L1", "L2", "L3", "L4", "L5", "L6"),
      privacy = "synthetic", requires = character(0),
      env = list(EPISTACK_HFRS_MODE = "demo"),
      inputs = c("case_hfrs_real/run_hfrs.R", "demo/make_demo_data.R"),
      outputs = c("面板分析报告_模拟.html", "run_manifest_panel_模拟.json",
                  "alerts_panel_模拟.csv", "cache/L0_contract.rds"),
      report = "面板分析报告_模拟.html"
    ),
    list(
      id = "panel_local", label = "本机私有面板实测（仅本机，数据不入库）",
      script = "case_hfrs_real/run_hfrs.R",
      layers = c("L0", "L1", "L2", "L3", "L4", "L5", "L6"),
      privacy = "real-local",
      requires = epi_local_requires(if (exists("root", inherits = TRUE)) root else getwd()),
      env = list(EPISTACK_HFRS_MODE = "local"),
      inputs = c("case_hfrs_real/run_hfrs.R"),
      outputs = c("面板分析报告.html", "run_manifest_panel.json",
                  "alerts_panel.csv", "cache/L0_contract.rds"),
      report = "面板分析报告.html"
    )
  ),
  shared_inputs = c(
    "bootstrap_core.R", "bootstrap_ingest.R", "R/pipeline_plan.R", "R/epi_json.R",
    "demo/make_demo_data.R",
    "epi-core/DESCRIPTION", "epi-core/NAMESPACE",
    "epi-core/R/contract.R", "epi-core/R/region.R", "epi-core/R/period.R",
    "epi-core/R/adjacency.R", "epi-core/R/qc.R", "epi-core/R/read_counts.R",
    "epi-core/inst/contract/schema.json",
    "epi-ingest/DESCRIPTION", "epi-ingest/NAMESPACE",
    "epi-ingest/R/utils.R", "epi-ingest/R/json.R", "epi-ingest/R/source.R",
    "epi-ingest/R/adapters.R", "epi-ingest/R/read.R", "epi-ingest/R/qc.R",
    "epi-ingest/R/report.R", "epi-ingest/R/lineage.R",
    "epi-ingest/R/desensitize.R", "epi-ingest/R/ingest_counts.R",
    "epi-ingest/inst/rules/qc_default.json"
  )
)
