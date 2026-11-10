# =============================================================
# 本机私有数据源配置模板（公开仓库不含任何真实路径）
#
# 用法：复制本文件为同目录的 data_paths.local.R 并填写自己的路径，然后
#   Rscript case_hfrs_real/run_hfrs.R --local
# data_paths.local.R 已在 .gitignore 中，绝不入库、不上传。
#
# 也可以完全不改文件，改用环境变量逐项注入：
#   EPISTACK_HFRS_INCIDENCE / EPISTACK_HFRS_GRAPH
#   EPISTACK_HFRS_SES       / EPISTACK_HFRS_MONTHLY
#
# 列结构约定（与内置模拟数据 demo/make_demo_data.R 完全一致）：
#   incidence : province, year, cases_est, pop, rate_per100k
#   graph     : INLA .graph，首行为地区数，节点顺序 = sort(unique(province))
#   ses       : prov, year, X1_gdp_pcap
#   monthly   : province, year, month, temp, prec, season
# =============================================================

DATA <- list(
  incidence = "",
  graph     = "",
  ses       = "",
  monthly   = ""
)
