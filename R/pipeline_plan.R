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

EPI_STACK_PLAN <- list(
  plan_version     = "0.1.0",
  contract_version = "0.1.0",
  seed             = 20261110L,
  contract         = "date, region, count, population, disease",
  layers = list(
    list(id = "L0", name = "epi-core",    role = "统一契约 / 地区编码 / 邻接权重",
         current_impl = "formal", impl = "epi-core/R/*.R", satellite = "epi-core",    since = "2026-11"),
    list(id = "L1", name = "epi-ingest",  role = "多源读取与质控",
         current_impl = "thin",   impl = "read_counts() 内置 epi_qc()", satellite = "epi-ingest",  since = "2026-12"),
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
      id = "hfrs_year", label = "HFRS 真实省-年面板实测（仅本机）",
      script = "case_hfrs_real/run_hfrs.R",
      layers = c("L0", "L1", "L2", "L3", "L4", "L5", "L6"),
      privacy = "real-local",
      requires = c(
        "F:/00在研项目/03_HFRS地理谱系/data/t14/clean/incidence_province_year.csv",
        "F:/00在研项目/03_HFRS地理谱系/data/t14/clean/prov_adj.graph",
        "F:/00在研项目/02_统计建模/【统计建模】一组/00_原始数据/医疗卫生不平等性/01_面板与字典/analysis_panel_2012_2024.csv"
      ),
      inputs = c("case_hfrs_real/run_hfrs.R"),
      outputs = c("HFRS真实数据实测报告.html", "run_manifest_hfrs.json",
                  "alerts_hfrs.csv", "cache/L0_contract.rds"),
      report = "HFRS真实数据实测报告.html"
    )
  ),
  shared_inputs = c(
    "bootstrap_core.R", "R/pipeline_plan.R", "R/epi_json.R",
    "epi-core/DESCRIPTION", "epi-core/NAMESPACE",
    "epi-core/R/contract.R", "epi-core/R/region.R", "epi-core/R/period.R",
    "epi-core/R/adjacency.R", "epi-core/R/qc.R", "epi-core/R/read_counts.R",
    "epi-core/inst/contract/schema.json"
  )
)
