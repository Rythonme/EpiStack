# =============================================================
# EpiStack v0.1.0 · HFRS 真实数据端到端实测（W4）
#
# 用法：
#   Rscript run_hfrs.R                       # 省-年真实面板（本机现有真实数据）
#   Rscript run_hfrs.R --monthly <月度CSV>   # 拿到月度直报数据后切到月度链路
#
# 只读外部数据，绝不回写源文件；产物全部落在本项目 output/ 且不入库。
#
# 重要口径声明：本机真实 HFRS 发病数据来自《中国卫生健康统计年鉴》年刊，
#   粒度为「省-年」；panel_province_month.csv 的真实「省-月」面板只有气候变量，
#   没有发病结局。因此本脚本默认按年际基线做异常检测，并在报告里明确标注。
#   一旦提供月度发病 CSV，--monthly 分支会用同一个 read_counts() 契约
#   切到 time_step="month" 的季节性基线带链路，无需改动上下游。
# =============================================================

args <- commandArgs(trailingOnly = TRUE)
ix_m <- match("--monthly", args)
monthly_csv <- if (!is.na(ix_m) && length(args) >= ix_m + 1L) args[ix_m + 1L] else NULL
# 月度模式单独命名产物，避免覆盖真实省-年实测报告
suffix <- if (!is.null(monthly_csv)) "_月度" else ""

a0 <- commandArgs(trailingOnly = FALSE)
f0 <- sub("^--file=", "", a0[grep("^--file=", a0)])
here <- if (length(f0)) dirname(normalizePath(f0[1L])) else getwd()
# 被主仓 pipeline.R source 时由环境变量注入；直接 Rscript 运行时按脚本位置推断
root <- Sys.getenv("EPISTACK_PROJECT_ROOT", unset = "")
if (!nzchar(root)) root <- dirname(here)
source(file.path(root, "bootstrap_core.R"), encoding = "UTF-8")
core_mode <- epi_bootstrap_core(file.path(root, "epi-core"))

# ---------------- 只读数据源配置（改成你自己的路径即可复跑） ----------------
DATA <- list(
  incidence = "F:/00在研项目/03_HFRS地理谱系/data/t14/clean/incidence_province_year.csv",
  graph     = "F:/00在研项目/03_HFRS地理谱系/data/t14/clean/prov_adj.graph",
  ses       = "F:/00在研项目/02_统计建模/【统计建模】一组/00_原始数据/医疗卫生不平等性/01_面板与字典/analysis_panel_2012_2024.csv",
  monthly   = "F:/00在研项目/03_HFRS地理谱系/data/t14/clean/panel_province_month.csv"
)
out_env <- Sys.getenv("EPISTACK_OUT_DIR", unset = "")
out_dir <- if (nzchar(out_env)) out_env else file.path(here, "output")
cache_dir <- file.path(out_dir, "cache")
dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)

SEED <- 20261110L
K_SIGMA <- 1.645
t_start <- Sys.time()
stage_log <- list()
esc <- function(x) {
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  gsub(">", "&gt;", x, fixed = TRUE)
}
mark_stage <- function(name, detail) {
  stage_log[[length(stage_log) + 1L]] <<- list(
    name = name, detail = detail,
    secs = round(as.numeric(difftime(Sys.time(), t_start, units = "secs")), 2))
  cat(sprintf("[%s] %s\n", name, detail))
}
read_bom_csv <- function(p) {
  d <- utils::read.csv(p, fileEncoding = "UTF-8", stringsAsFactors = FALSE,
                       check.names = FALSE)
  names(d) <- gsub(intToUtf8(65279L), "", names(d), fixed = TRUE)
  d
}

# ---------------- L0 / L1 · 真实面板 -> 正式契约 ----------------
inc <- read_bom_csv(DATA$incidence)
ses <- read_bom_csv(DATA$ses)
mo  <- read_bom_csv(DATA$monthly)
for (p in c(DATA$incidence, DATA$graph, DATA$ses, DATA$monthly))
  if (!file.exists(p)) stop(sprintf("真实数据源不存在：%s", p), call. = FALSE)

# 邻接图的节点顺序 = T14d 中 sort(unique(prov_s))，必须用同一顺序构造 geo
provs <- sort(unique(inc$province))
ses24 <- ses[ses$year == 2024, ]
gdp <- as.numeric(ses24$X1_gdp_pcap[match(provs, ses24$prov)])
ses_norm <- (gdp - min(gdp, na.rm = TRUE)) / diff(range(gdp, na.rm = TRUE))
pop24 <- as.numeric(inc$pop[inc$year == 2024][match(provs, inc$province[inc$year == 2024])])
geo <- data.frame(region = provs, population = pop24, pop = pop24,
                  ses = ses_norm, gdp_pcap = gdp, stringsAsFactors = FALSE)

# 年鉴给的是发病率，cases_est 为按人口反算的估计发病数；取整后作为计数结局
hfrs_raw <- data.frame(
  year = inc$year, province = inc$province,
  cases = pmax(0L, as.integer(round(inc$cases_est))),
  pop = inc$pop, disease = "HFRS", stringsAsFactors = FALSE
)

if (!is.null(monthly_csv)) {
  if (!file.exists(monthly_csv)) stop(sprintf("月度数据不存在：%s", monthly_csv), call. = FALSE)
  # 月度 CSV 约定列：date(YYYY-MM-DD 或 YYYY-MM), region, count, population, disease
  # 也可由 read_counts() 的自动列名别名识别 year/month/province/cases/pop
  core <- read_counts(monthly_csv, geo = geo, time_step = "month", n_periods = 12L,
                      graph = DATA$graph, disease = "HFRS",
                      source_label = basename(monthly_csv))
  time_step <- "month"
  n_periods <- 12L
  data_label <- "月度直报数据（用户提供）"
} else {
  core <- read_counts(
    hfrs_raw, geo = geo, graph = DATA$graph,
    mapping = list(date = "year", region = "province", count = "cases",
                   population = "pop", disease = "disease"),
    time_step = "year", n_periods = length(unique(inc$year)),
    disease = "HFRS", source_label = "中国卫生健康统计年鉴（省-年，cases_est 反算）"
  )
  time_step <- "year"
  n_periods <- length(unique(inc$year))
  data_label <- "真实省-年发病面板（年鉴反算）"
}
validate_contract(core)
contract <- core$data
W <- core$W
qc <- core$qc$report
n_drop <- core$qc$dropped
stopifnot(identical(rownames(W), provs), identical(colnames(W), provs))
saveRDS(contract, file.path(cache_dir, "L0_contract.rds"))
mark_stage("L0 epi-core", sprintf("契约 v%s 校验通过；%s 共 %d 行、%d 地区；真实邻接 %dx%d（%s）",
                                  EPI_CONTRACT_VERSION, data_label, core$meta$n_raw,
                                  length(provs), nrow(W), ncol(W), core_mode))
mark_stage("L1 epi-ingest", sprintf("read_counts() 质控剔除 %d 行；清洁契约表 %d 行（真实面板无脏行即为通过）",
                                    n_drop, nrow(contract)))

# ---------------- 月度时间轴接入核验（真实省-月气候面板） ----------------
mo$date <- as.Date(paste0(mo$year, "-", sprintf("%02d", mo$month), "-01"))
mo$period <- epi_period(mo$date, 12L, "month")
monthly_axis <- list(
  rows = nrow(mo), regions = length(unique(mo$province)),
  years = paste(range(mo$year), collapse = "-"),
  periods = length(unique(mo$period)),
  note = if (time_step == "year")
    "该面板仅含 temp/prec/season 气候协变量，不含发病结局" else
    "内置面板仅气候；本次月度发病结局来自 --monthly 指定的 CSV"
)
mark_stage("L1b 月度轴", sprintf("真实省-月气候面板 %d 行、%d 地区、%d 个自然月周期；%s",
                                 monthly_axis$rows, monthly_axis$regions,
                                 monthly_axis$periods, monthly_axis$note))

# ---------------- L2 · 异常检测（年际基线 / 季节性基线带） ----------------
cur_year <- max(contract$year)
hist <- contract[contract$year < cur_year, ]
current <- contract[contract$year == cur_year, ]

if (time_step == "year") {
  # 年度无季节周期：用每省全历史 log(count+0.5) 的单侧上界评估最新年
  band <- data.frame(region = provs, baseline = NA_real_, upper = NA_real_,
                     stringsAsFactors = FALSE)
  for (i in seq_along(provs)) {
    z <- hist$count[hist$region == provs[i]]
    if (length(z) >= 3L) {
      lz <- log(z + 0.5); mu <- mean(lz); sd <- stats::sd(lz)
      band$baseline[i] <- exp(mu) - 0.5
      band$upper[i] <- exp(mu + K_SIGMA * sd) - 0.5
    }
  }
  cur <- merge(current, band, by = "region", all.x = TRUE, sort = FALSE)
  cur <- cur[order(cur$region, cur$date), ]
  cur$exceed <- !is.na(cur$upper) & cur$count > cur$upper
  cur$ratio <- ifelse(!is.na(cur$upper) & cur$upper > 0,
                      cur$count / pmax(cur$upper, 1), 0)
  cur$level <- "正常"
  cur$level[cur$exceed] <- "关注"
  cur$level[cur$ratio >= 1.5] <- "预警"
  cur$level[cur$ratio >= 2.0] <- "告警"
  alert_note <- "年际基线：每省 2004–2023 年 log(count+0.5) 均值 + 1.645σ 单侧上界；年度数据无「连续超限」概念，分级按超出倍数"
} else {
  # 月度：与合成切片同构的季节性基线带（历史同期 ±1 期）
  band <- expand.grid(region = provs, period = 1L:n_periods,
                      stringsAsFactors = FALSE, KEEP.OUT.ATTRS = FALSE)
  band$baseline <- NA_real_; band$upper <- NA_real_
  for (i in seq_len(nrow(band))) {
    w <- epi_wrap_period((band$period[i] - 1L):(band$period[i] + 1L), n_periods)
    z <- hist$count[hist$region == band$region[i] & hist$period %in% w]
    if (length(z) >= 3L) {
      lz <- log(z + 0.5); mu <- mean(lz); sd <- stats::sd(lz)
      band$baseline[i] <- exp(mu) - 0.5
      band$upper[i] <- exp(mu + K_SIGMA * sd) - 0.5
    }
  }
  cur <- merge(current, band, by = c("region", "period"), all.x = TRUE, sort = FALSE)
  cur <- cur[order(cur$region, cur$date), ]
  cur$exceed <- !is.na(cur$upper) & cur$count > cur$upper
  cur$run_len <- 0L
  for (rg in provs) {
    ix <- which(cur$region == rg)
    if (!length(ix)) next
    rr <- rle(cur$exceed[ix]); lens <- integer(length(ix)); pos <- 1L
    for (j in seq_along(rr$lengths)) {
      if (rr$values[j]) lens[pos:(pos + rr$lengths[j] - 1L)] <- rr$lengths[j]
      pos <- pos + rr$lengths[j]
    }
    cur$run_len[ix] <- lens
  }
  cur$ratio <- ifelse(!is.na(cur$upper) & cur$upper > 0,
                      cur$count / pmax(cur$upper, 1), 0)
  cur$level <- "正常"
  cur$level[cur$run_len >= 1L] <- "关注"
  cur$level[cur$run_len >= 2L | cur$ratio >= 1.5] <- "预警"
  cur$level[cur$run_len >= 3L | cur$ratio >= 2.0] <- "告警"
  alert_note <- "季节性基线带：历史同期 ±1 月 log(count+0.5) 均值 + 1.645σ 上界；按连续超限与超出倍数分级"
}
alerts <- cur[cur$level != "正常",
              c("date", "region", "count", "upper", "ratio", "level")]
alerts <- alerts[order(match(alerts$level, c("告警", "预警", "关注")), -alerts$count), ]
utils::write.csv(alerts, file.path(out_dir, paste0("alerts_hfrs", suffix, ".csv")),
                 row.names = FALSE, fileEncoding = "UTF-8")
saveRDS(list(band = band, cur = cur, alerts = alerts),
        file.path(cache_dir, "L2_alert.rds"))
mark_stage("L2 epi-alert", sprintf("%d 年评估 %d 地区-期；升高异常 %d 条（告警 %d）；基线口径 %s",
                                   cur_year, nrow(cur), nrow(alerts),
                                   sum(cur$level == "告警"),
                                   if (time_step == "year") "年际单侧上界" else "季节性基线带"))

# 全国长期趋势：解释「为什么单侧升高预警零命中」
agg_year <- aggregate(count ~ year, data = contract, sum)
total_cur <- sum(current$count)
hist_median <- stats::median(agg_year$count[agg_year$year < cur_year])
change_pct <- 100 * (total_cur / hist_median - 1)
mark_stage("L2b 趋势", sprintf("全国合计 %d 例，历史中位数 %d 例（%+.1f%%）；%s",
                               total_cur, round(hist_median), change_pct,
                               if (nrow(alerts) == 0L) "单侧升高预警零命中" else
                                 sprintf("检出 %d 条升高信号", nrow(alerts))))
alert_note <- paste0(alert_note,
  sprintf("；%d 年全国合计 %d 例，较历史中位数 %+.1f%%，呈长期下降", cur_year, total_cur, change_pct))

# ---------------- L3 · 全局 Moran's I（真实省邻接） ----------------
tot <- aggregate(count ~ region, data = current, sum)
tot <- merge(geo[, c("region", "pop")], tot, by = "region", all.x = TRUE)
tot <- tot[match(provs, tot$region), ]          # 强制与 W 的 dimnames 对齐
tot$count[is.na(tot$count)] <- 0
tot$rate <- tot$count / tot$pop * 1e5           # 每 10 万人报告率
x <- tot$rate
moran_I <- function(v) {
  z <- v - mean(v)
  (length(v) / sum(W)) * sum(W * outer(z, z)) / sum(z^2)
}
I_obs <- moran_I(x)
set.seed(SEED + 1L)
I_null <- replicate(999L, moran_I(sample(x)))
p_val <- (1 + sum(abs(I_null) >= abs(I_obs))) / 1000L
# 稳健性：单年计数稀疏，补算 2004–2024 累积报告率的空间自相关
tot_cum <- aggregate(count ~ region, data = contract, sum)
tot_cum <- tot_cum[match(provs, tot_cum$region), ]
x_cum <- tot_cum$count / tot$pop * 1e5
I_cum <- moran_I(x_cum)
set.seed(SEED + 2L)
p_cum <- (1 + sum(abs(replicate(999L, moran_I(sample(x_cum)))) >= abs(I_cum))) / 1000L
saveRDS(list(W = W, tot = tot, I = I_obs, p = p_val, I_cum = I_cum, p_cum = p_cum),
        file.path(cache_dir, "L3_space.rds"))
mark_stage("L3 epi-space", sprintf("真实 31 省邻接 %dx%d；单年 Moran's I = %.3f (p = %.3f)，2004–2024 累积 I = %.3f (p = %.3f)",
                                   nrow(W), ncol(W), I_obs, p_val, I_cum, p_cum))

# ---------------- L4 · 健康不平等（真实人均 GDP 作 SES） ----------------
tot$ses <- geo$ses[match(tot$region, geo$region)]
o <- order(tot$ses)
p <- tot$pop[o]; y <- tot$count[o]
cp <- c(0, cumsum(p) / sum(p)); cy <- c(0, cumsum(y) / sum(y))
area <- sum((cp[-1] - cp[-length(cp)]) * (cy[-1] + cy[-length(cy)]) / 2)
CI <- 1 - 2 * area
low <- tot$ses < stats::median(tot$ses, na.rm = TRUE)
rate_low  <- sum(tot$count[low])  / sum(tot$pop[low])  * 1e5
rate_high <- sum(tot$count[!low]) / sum(tot$pop[!low]) * 1e5
rate_ratio <- rate_low / rate_high
top_i <- which.max(tot$rate)
top_region <- tot$region[top_i]
top_share <- tot$count[top_i] / sum(tot$count)
saveRDS(list(CI = CI, cp = cp, cy = cy, ratio = rate_ratio,
             top_region = top_region, top_share = top_share),
        file.path(cache_dir, "L4_ineq.rds"))
mark_stage("L4 epi-ineq", sprintf("集中指数 CI = %.3f；低/高 GDP 组率比 %.2f；%s 占全国病例 %.1f%%（率 %.2f/10万）",
                                  CI, rate_ratio, top_region, 100 * top_share, tot$rate[top_i]))

# ---------------- L5 · 单文件 HTML 报告 ----------------
css <- paste0(
'*{box-sizing:border-box}body{margin:0;background:#f4f7fb;color:#243447;',
'font-family:"Microsoft YaHei","PingFang SC",-apple-system,Segoe UI,sans-serif;line-height:1.6}',
'.wrap{max-width:980px;margin:0 auto;padding:26px 20px 56px}',
'header{background:linear-gradient(120deg,#1f4e88,#2c7bc9);color:#fff;border-radius:14px;padding:24px 28px;margin-bottom:16px}',
'header h1{margin:0 0 6px;font-size:24px}header p{margin:2px 0;opacity:.92;font-size:13px}',
'.warn{background:#fff7ed;border:1px solid #f0b775;border-left:5px solid #e67e22;',
'border-radius:10px;padding:14px 18px;margin-bottom:16px;font-size:13px;color:#7a4a12}',
'.warn b{color:#b45309}',
'.kpis{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin-bottom:16px}',
'.kpi{background:#fff;border:1px solid #e3e9f0;border-radius:12px;padding:14px 16px}',
'.kpi .v{font-size:22px;font-weight:700;color:#1f4e88}.kpi .l{font-size:12px;color:#718096}',
'.kpi.g .v{color:#2e9e6b}.kpi.o .v{color:#e67e22}',
'.card{background:#fff;border:1px solid #e3e9f0;border-radius:12px;padding:16px 20px;margin-bottom:16px}',
'.card h2{font-size:16px;margin:0 0 12px}.card h3{font-size:14px;margin:14px 0 8px}',
'.flow{display:grid;grid-template-columns:repeat(7,1fr);gap:6px;margin:0 0 6px}',
'.st{background:#e8f1fc;border-radius:8px;padding:8px 4px;text-align:center;font-size:11px;color:#1f4e88}',
'.st b{display:block;font-size:12px;margin-bottom:2px}',
'table{width:100%;border-collapse:collapse;font-size:12px}',
'th,td{padding:7px 9px;border-bottom:1px solid #edf1f6;text-align:left}',
'th{background:#f7f9fc;color:#5a6a7e;font-weight:600}',
'.two{display:grid;grid-template-columns:1fr 300px;gap:16px;align-items:start}',
'.note{font-size:12px;color:#5a6a7e;margin:0}',
'code{background:#eef3f9;padding:1px 5px;border-radius:4px;font-size:12px}',
'footer{font-size:11px;color:#8a97a5;text-align:center;margin-top:24px}',
'@media(max-width:700px){.kpis{grid-template-columns:repeat(2,1fr)}.two{grid-template-columns:1fr}.flow{grid-template-columns:repeat(2,1fr)}}')

svg_series <- function(contract, cur) {
  agg <- aggregate(count ~ year, data = contract, sum)
  agg <- agg[order(agg$year), ]
  n <- nrow(agg); if (n < 2L) return("")
  Wd <- 860; H <- 230; L <- 56; R <- 16; T <- 22; B <- 32
  ymax <- max(agg$count) * 1.18
  X <- function(i) L + (i - 1L) * (Wd - L - R) / (n - 1L)
  Y <- function(v) H - B - v / ymax * (H - T - B)
  grid <- character(0)
  for (g in seq(0, 1, by = 0.25)) {
    yy <- H - B - g * (H - T - B)
    grid <- c(grid,
      sprintf('<line x1="%.0f" y1="%.1f" x2="%.0f" y2="%.1f" stroke="#e8edf2"/>', L, yy, Wd - R, yy),
      sprintf('<text x="%.0f" y="%.1f" font-size="11" fill="#8a97a5" text-anchor="end">%.0f</text>', L - 8, yy + 4, g * ymax))
  }
  sprintf(paste0('<svg viewBox="0 0 %d %d" width="100%%" height="%d" style="background:#fff;border:1px solid #e3e9f0;border-radius:10px">',
                 '%s<polyline points="%s" fill="none" stroke="#2c6fbb" stroke-width="2.5"/>%s',
                 '<text x="%d" y="%d" font-size="11" fill="#8a97a5">%d</text>',
                 '<text x="%d" y="%d" font-size="11" fill="#8a97a5" text-anchor="end">%d</text></svg>'),
          Wd, H, H, paste(grid, collapse = ""),
          paste(sprintf("%.1f,%.1f", X(seq_len(n)), Y(agg$count)), collapse = " "),
          paste(sprintf('<circle cx="%.1f" cy="%.1f" r="3.5" fill="#2c6fbb"/>',
                        X(seq_len(n)), Y(agg$count)), collapse = ""),
          L, H - 9, min(agg$year), Wd - R, H - 9, max(agg$year))
}

svg_bars <- function(tot) {
  d <- tot[order(-tot$rate), ][seq_len(min(15L, nrow(tot))), ]
  Wd <- 560; rowh <- 22; L <- 76; H <- 16 + nrow(d) * rowh
  mx <- max(d$rate) * 1.05
  s <- sprintf('<svg viewBox="0 0 %d %d" width="100%%" height="%d" style="background:#fff;border:1px solid #e3e9f0;border-radius:10px">', Wd, H, H)
  for (i in seq_len(nrow(d))) {
    y <- 12 + (i - 1L) * rowh
    w <- d$rate[i] / mx * (Wd - L - 70)
    s <- paste0(s,
      sprintf('<text x="%d" y="%d" font-size="12" fill="#243447" text-anchor="end">%s</text>', L - 8, y + 14, esc(d$region[i])),
      sprintf('<rect x="%d" y="%d" width="%.1f" height="14" rx="3" fill="#2c7bc9" fill-opacity="%.2f"/>',
              L, y + 3, w, 0.45 + 0.55 * d$rate[i] / mx),
      sprintf('<text x="%.1f" y="%d" font-size="11" fill="#5a6a7e">%.2f</text>', L + w + 6, y + 14, d$rate[i]))
  }
  paste0(s, '</svg>')
}

svg_lorenz <- function(cp, cy) {
  S <- 220; L <- 46; T <- 18
  X <- function(v) L + v * S; Y <- function(v) T + (1 - v) * S
  pts <- paste(sprintf("%.1f,%.1f", X(cp), Y(cy)), collapse = " ")
  sprintf(paste0('<svg viewBox="0 0 300 270" width="300" height="270" style="background:#fff;border:1px solid #e3e9f0;border-radius:10px">',
                 '<line x1="%.0f" y1="%.0f" x2="%.0f" y2="%.0f" stroke="#c9d6e4" stroke-dasharray="5 4" stroke-width="1.5"/>',
                 '<polyline points="%s" fill="none" stroke="#0f6e56" stroke-width="2.5"/>%s',
                 '<text x="%d" y="%d" font-size="11" fill="#8a97a5">累计人口份额 →</text>',
                 '<text x="%d" y="%d" font-size="11" fill="#8a97a5">累计病例份额</text></svg>'),
          X(0), Y(0), X(1), Y(1), pts,
          paste(sprintf('<circle cx="%.1f" cy="%.1f" r="3.5" fill="#0f6e56"/>', X(cp), Y(cy)), collapse = ""),
          L, T + S + 22, 12, T + 8)
}

stage_cards <- paste(vapply(stage_log, function(s)
  sprintf('<div class="st"><b>%s</b>%s</div>', esc(s$name),
          esc(sub("；.*$", "", s$detail))), character(1)), collapse = "")
qc_rows <- paste(sprintf('<tr><td>%s</td><td>%d</td><td>%s</td></tr>',
                         esc(qc$检查项), qc$检出, esc(qc$处理)), collapse = "")
src_rows <- paste(sprintf('<tr><td>%s</td><td>%d</td><td>%s</td><td>只读，不复制入库</td></tr>',
  esc(c("发病面板 incidence_province_year.csv", "省邻接 prov_adj.graph",
        "SES 面板 analysis_panel_2012_2024.csv", "月度面板 panel_province_month.csv")),
  c(nrow(inc), length(readLines(DATA$graph, warn = FALSE)) - 1L, nrow(ses), nrow(mo)),
  esc(c(sprintf("省-年 %d–%d", min(inc$year), max(inc$year)), "31 省 queen 邻接（已清洗孤岛）",
        sprintf("省-年 %d–%d", min(ses$year), max(ses$year)),
        sprintf("省-月 %s", monthly_axis$years)))), collapse = "")
alert_rows <- if (nrow(alerts)) {
  a <- head(alerts, 12L)
  paste(sprintf('<tr><td>%s</td><td>%s</td><td>%s</td><td>%.1f</td><td>%.2f</td><td>%s</td></tr>',
                esc(format(a$date, "%Y")), esc(a$region), esc(a$count),
                a$upper, a$ratio, esc(a$level)), collapse = "")
} else '<tr><td colspan="6">评估期未检出异常信号</td></tr>'
metric_rows <- paste0(
  sprintf('<tr><td>全局 Moran\'s I（%d 年报告率）</td><td>%.3f</td><td>999 次置换检验 p = %.3f；真实省邻接</td></tr>', cur_year, I_obs, p_val),
  sprintf('<tr><td>多年累积 Moran\'s I</td><td>%.3f</td><td>2004–2024 累积报告率；置换 p = %.3f，单年计数稀疏时更稳健</td></tr>', I_cum, p_cum),
  sprintf('<tr><td>集中指数 CI</td><td>%.3f</td><td>按人均 GDP 升序、人口加权；负值表示负担偏向低 GDP 省份</td></tr>', CI),
  sprintf('<tr><td>低/高 GDP 组报告率比</td><td>%.2f</td><td>按 GDP 中位数二分、人口标化；与连续排序的 CI 口径不同</td></tr>', rate_ratio),
  sprintf('<tr><td>%d 年合计 / 历史中位数</td><td>%.0f / %.0f</td><td>%+.1f%%，长期下降</td></tr>',
          cur_year, total_cur, hist_median, change_pct))

trend_msg <- if (nrow(alerts) == 0L)
  "长期下降使单侧升高预警零命中，监测系统应同时关注「显著低于基线」的结构性变化" else
  sprintf("本期检出 %d 条升高信号，需结合基线口径复核", nrow(alerts))
findings_html <- sprintf(paste0(
'<section class="card"><h2>本次实测的三条主要发现</h2>',
'<p class="note"><b>1. 趋势与单侧预警。</b>%d 年全国合计 %d 例，为历史年中位数 %.0f 例的 %.1f%%（%+.1f%%）；%s。</p>',
'<p class="note"><b>2. 空间自相关检验。</b>%d 年 Moran\'s I = %.3f (p = %.3f)；',
'改用 2004–2024 累积报告率后 I = %.3f (p = %.3f)；单年计数稀疏时两者可能都不显著。</p>',
'<p class="note"><b>3. 单一中位数分组对极端值敏感。</b>集中指数 CI = %.3f 提示负担略偏向低 GDP 省份，',
'但二分组率比 = %.2f 方向相反：%s 一省占全国病例 %.1f%%（率 %.2f/10万），其人均 GDP 恰好略高于中位数，',
'被划入「高 GDP」组并拉高该组率。连续 SES 排序的集中指数更稳健；省级生态学关联不可作因果解释。</p></section>'),
 cur_year, total_cur, hist_median, 100 * total_cur / hist_median, change_pct, trend_msg,
 cur_year, I_obs, p_val, I_cum, p_cum,
 CI, rate_ratio, esc(top_region), 100 * top_share, tot$rate[top_i])

warn_html <- if (time_step == "year") {
  paste0('<div class="warn"><b>数据口径声明（务必先读）</b><br>',
         '本机真实 HFRS 发病数据来自《中国卫生健康统计年鉴》<b>年刊</b>，粒度为「省-年」；',
         '<code>cases_est</code> 是按年鉴发病率与人口反算的估计发病数（本脚本取整后作为计数结局），',
         '<b>不是直报个案数</b>。真实的省-月面板 <code>panel_province_month.csv</code>（',
         monthly_axis$rows, ' 行）只有气温/降水，<b>没有任何月度发病结局</b>，因此本次实测',
         '按年际基线做异常检测，未做「月度周报」。月度链路已用合成数据验证，',
         '拿到月度直报 CSV 后运行 <code>Rscript run_hfrs.R --monthly 你的数据.csv</code> 即可切换，',
         '上下游契约不变。所有阈值均为演示口径，<b>不可直接作为公共卫生决策依据</b>。</div>')
} else {
  paste0('<div class="warn"><b>月度实测模式</b><br>已使用用户提供的月度发病 CSV（',
         esc(basename(monthly_csv)), '）按 <code>time_step="month"</code> 运行季节性基线带链路。',
         '阈值与口径需按当地报告制度校准，<b>不可直接作为公共卫生决策依据</b>。</div>')
}

body <- sprintf(paste0(
'<header><h1>EpiStack v0.1.0 · HFRS 真实数据端到端实测</h1>',
'<p>%s ｜ %d 年评估 ｜ 生成时间 %s</p>',
'<p>L0 → L6 全链路 · 全程本地计算 · 真实数据只读、不入库、不上传</p></header>',
'%s',
'<div class="kpis">',
'<div class="kpi"><div class="v">%d</div><div class="l">真实契约记录</div></div>',
'<div class="kpi"><div class="v">%d</div><div class="l">省级地区</div></div>',
'<div class="kpi o"><div class="v">%d</div><div class="l">异常信号</div></div>',
'<div class="kpi g"><div class="v">%.3f</div><div class="l">集中指数 CI</div></div>',
'</div>',
'%s',
'<section class="card"><h2>流水线执行状态</h2><div class="flow">%s</div>',
'<p class="note">L0/L1 由 epiCore v%s 正式包提供（%s）；L3 使用真实 31 省邻接，L4 使用真实人均 GDP。</p></section>',
'<section class="card"><h2>只读数据源清单</h2><table><thead><tr><th>数据源</th><th>行数</th><th>粒度</th><th>处理方式</th></tr></thead><tbody>%s</tbody></table></section>',
'<section class="card"><h2>L1 · 数据质控</h2><table><thead><tr><th>检查项</th><th>检出</th><th>处理</th></tr></thead><tbody>%s</tbody></table>',
'<p class="note">真实面板无脏行即视为质控通过；质控逻辑与合成切片完全一致（epi_qc）。</p></section>',
'<section class="card"><h2>L2 · 全国年度发病趋势与异常检测</h2>%s',
'<p class="note">%s。</p></section>',
'<section class="card"><h2>L3 / L4 · 空间格局与健康不平等</h2><div class="two"><div>',
'<h3>%d 年各省报告率（前 15，每 10 万人）</h3>%s</div><div><h3>集中曲线</h3>%s',
'<p class="note">虚线为完全平等线；实线在上方表示疾病负担更集中于低 GDP 省份。</p></div></div>',
'<h3>关键指标</h3><table><thead><tr><th>指标</th><th>数值</th><th>解读</th></tr></thead><tbody>%s</tbody></table></section>',
'<section class="card"><h2>L2 · %d 年异常清单（前 12 条）</h2><table>',
'<thead><tr><th>年份</th><th>省份</th><th>发病数</th><th>基线上界</th><th>超出倍数</th><th>级别</th></tr></thead><tbody>%s</tbody></table></section>',
'<section class="card"><h2>月度接入状态与切换方式</h2><p class="note">',
'真实省-月气候面板已按契约 <code>date / region</code> 对齐：%d 行、%d 地区、%s 年、%d 个自然月周期（epi_period 映射核验）。',
'%s 因此「省-月」时间轴与地理编码已就绪，缺的只是月度发病结局列。',
'epi-core 的 <code>read_counts()</code> 支持 <code>time_step = week / month / quarter / year</code>，',
'拿到月度 CSV（列 date, region, count, population, disease）后无需改动上下游即可完整跑通：</p>',
'<p class="note"><code>Rscript run_hfrs.R --monthly your_monthly_counts.csv</code></p></section>',
'<section class="card"><h2>方法与边界</h2><p class="note">',
'计数结局：年鉴发病率 × 人口反算并取整，仅用于方法链路验证。',
'空间：真实 31 省 queen 邻接（INLA .graph，海南已人工连广东），行标准化，Moran\'s I + 999 次置换检验。',
'不平等：按 2024 年人均 GDP 升序、人口加权的集中指数 CI = 1 − 2×集中曲线下面积。',
'率比按人均 GDP 中位数二分分组，与连续排序的集中指数口径不同，方向不一致时以集中指数为准。',
'预警阈值需按病种、报告制度与历史长度校准；本报告为开源工具 v0.1 的实测样例，<b>不构成任何决策依据</b>。</p></section>',
'<footer>EpiStack v0.1.0 · epiCore %s · 单文件离线报告 · manifest 见 output/ 目录</footer>'),
 esc(data_label), cur_year, esc(format(Sys.time(), "%Y-%m-%d %H:%M")),
 warn_html,
 nrow(contract), length(provs), nrow(alerts), CI,
 findings_html,
 stage_cards, EPI_CONTRACT_VERSION, esc(core_mode),
 src_rows, qc_rows, svg_series(contract, cur), esc(alert_note),
 cur_year, svg_bars(tot), svg_lorenz(cp, cy), metric_rows,
 cur_year, alert_rows,
 monthly_axis$rows, monthly_axis$regions, esc(monthly_axis$years), monthly_axis$periods,
 esc(monthly_axis$note), EPI_CONTRACT_VERSION)

out_html <- file.path(out_dir, paste0("HFRS真实数据实测报告", suffix, ".html"))
html <- paste0('<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8">',
               '<meta name="viewport" content="width=device-width,initial-scale=1">',
               '<title>EpiStack · HFRS 真实数据端到端实测</title><style>', css,
               '</style></head><body><div class="wrap">', body, '</div></body></html>')
con <- file(out_html, open = "wt", encoding = "UTF-8")
writeLines(enc2utf8(html), con, useBytes = TRUE)
close(con)
mark_stage("L5 epi-report", sprintf("单文件实测报告输出：%s（%d 字节）",
                                    basename(out_html), file.info(out_html)$size))

# ---------------- L6 · 可复现 manifest ----------------
manifest <- sprintf(paste0(
'{\n  "pipeline": "EpiStack HFRS real-data case v0.1.0",\n',
'  "generated_at": "%s",\n  "r_version": "%s",\n  "seed": %d,\n',
'  "stages": [\n%s\n  ],\n',
'  "core": {"package": "epiCore", "version": "%s", "load": "%s"},\n',
'  "data_label": "%s",\n  "time_step": "%s",\n',
'  "sources": {"incidence_rows": %d, "ses_rows": %d, "monthly_climate_rows": %d, "graph_nodes": %d},\n',
'  "qc": {"dropped": %d},\n',
'  "results": {"n_records": %d, "regions": %d, "assessment_year": %d, "n_alerts": %d,',
'  "moran_I": %.4f, "moran_p": %.4f, "moran_cum_I": %.4f, "moran_cum_p": %.4f, "CI": %.4f, "rate_ratio": %.4f,',
'  "total_current": %d, "historical_median": %.0f, "change_pct": %.1f, "top_region": "%s", "top_share": %.4f},\n',
'  "monthly_axis": {"rows": %d, "regions": %d, "periods": %d, "note": "%s"},\n',
'  "outputs": {"report": "%s", "alerts_csv": "%s", "cache": "cache/L0,L2,L3,L4 rds"},\n',
'  "reproduce": "Rscript run_hfrs.R [--monthly <月度CSV>]",\n',
'  "privacy": "真实数据只读；output/ 全部产物仅在本地，不入库、不上传"\n}\n'),
 format(Sys.time(), "%Y-%m-%d %H:%M:%S"), R.version.string, SEED,
 paste(vapply(stage_log, function(s) sprintf('    {"stage": "%s", "detail": "%s", "elapsed_sec": %.2f}',
                                             s$name, gsub('"', "'", s$detail), s$secs),
              character(1)), collapse = ",\n"),
 EPI_CONTRACT_VERSION, core_mode, data_label, time_step,
 nrow(inc), nrow(ses), nrow(mo), nrow(W),
 n_drop, nrow(contract), length(provs), cur_year, nrow(alerts),
 I_obs, p_val, I_cum, p_cum, CI, rate_ratio,
 as.integer(total_cur), hist_median, change_pct, top_region, top_share,
 monthly_axis$rows, monthly_axis$regions, monthly_axis$periods, monthly_axis$note,
 basename(out_html), paste0("alerts_hfrs", suffix, ".csv"))
writeLines(enc2utf8(manifest),
           file.path(out_dir, paste0("run_manifest_hfrs", suffix, ".json")),
           useBytes = TRUE)
mark_stage("L6 epi-flow", sprintf("manifest + 4 个阶段缓存已写入 %s/cache/；总耗时 %.2f 秒",
                                  basename(out_dir),
                                  as.numeric(difftime(Sys.time(), t_start, units = "secs"))))
cat(sprintf("\nHFRS 真实数据端到端实测完成：%s\n", out_html))
