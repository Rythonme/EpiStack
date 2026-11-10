# =============================================================
# EpiStack v0.1.0 · 端到端最小切片（vertical slice）
# 一条命令贯穿 L0 契约 -> L1 质控 -> L2 预警 -> L3 空间自相关
#              -> L4 健康不平等 -> L5 综合 HTML 报告 -> L6 可复现 manifest
#
# 用法：Rscript run_e2e.R [输出报告.html]
# 依赖：base R + 本仓正式包 epi-core（自动安装到 .rlib/，断网时回退源码加载）
# 数据：内置合成数据（模拟"原始多源面板"），固定随机种子，可完全复现
# 说明：L0/L1 已替换为 epi-core 正式包函数（read_counts / validate_contract /
#       epi_adjacency / epi_period）；L2–L6 仍为薄实现，后续逐月替换为卫星仓。
# =============================================================

# ---- 载入正式 epi-core 包 ----
# 直接 Rscript 运行时由 --file= 推断项目根目录；
# 被主仓 pipeline.R / 冒烟测试 source 时，由 EPISTACK_PROJECT_ROOT 注入
# （同一会话内调用，避免 Windows 中文路径经命令行传给子进程时乱码）。
a0 <- commandArgs(trailingOnly = FALSE)
f0 <- sub("^--file=", "", a0[grep("^--file=", a0)])
root <- Sys.getenv("EPISTACK_PROJECT_ROOT", unset = "")
if (!nzchar(root))
  root <- if (length(f0)) dirname(dirname(normalizePath(f0[1L]))) else dirname(getwd())
source(file.path(root, "bootstrap_core.R"), encoding = "UTF-8")
core_mode <- epi_bootstrap_core(file.path(root, "epi-core"))

args     <- commandArgs(trailingOnly = TRUE)
out_env  <- Sys.getenv("EPISTACK_OUT_DIR", unset = "")
out_html <- if (nzchar(out_env)) file.path(out_env, "端到端演示报告.html") else
            if (length(args) >= 1L && !grepl("^--", args[1L])) args[1L] else
            file.path(getwd(), "端到端演示报告.html")
out_dir  <- dirname(out_html)
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)
cache_dir <- file.path(out_dir, "cache")
if (!dir.exists(cache_dir)) dir.create(cache_dir, recursive = TRUE)

SEED      <- 20261110L
N_PERIODS <- 52L
K_SIGMA   <- 1.645
t_start   <- Sys.time()
stage_log <- list()

esc <- function(x) {
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;",  x, fixed = TRUE)
  x <- gsub(">", "&gt;",  x, fixed = TRUE)
  x
}
# 时间周期也交给 epi-core，避免切片里另存一份实现
period_of <- function(d) epi_period(d, N_PERIODS, "week")
wrap_p    <- function(w) epi_wrap_period(w, N_PERIODS)
mark_stage <- function(name, detail) {
  stage_log[[length(stage_log) + 1L]] <<- list(name = name, detail = detail,
                                               secs = round(as.numeric(difftime(Sys.time(), t_start, units = "secs")), 2))
  cat(sprintf("[%s] %s\n", name, detail))
}

# ---------------- L0 · 统一数据契约与合成"原始面板" ----------------
set.seed(SEED)
geo <- data.frame(
  region = paste0("地区", 1:16),
  row = rep(1:4, each = 4L),                    # 4×4 县级格网
  col = rep(1:4, times = 4L),
  pop = c(120, 90, 210, 80, 150, 260, 110, 95, 175, 130, 240, 85, 100, 190, 145, 220),
  ses = c(0.16, 0.28, 0.52, 0.78, 0.18, 0.32, 0.58, 0.82,   # 左低右高，含轻微噪声
          0.14, 0.30, 0.55, 0.85, 0.20, 0.34, 0.60, 0.88),
  stringsAsFactors = FALSE
)
dates <- seq(as.Date("2021-01-04"), by = "week", length.out = N_PERIODS * 5L)
rows <- vector("list", nrow(geo) * length(dates)); k <- 0L
for (r in seq_len(nrow(geo))) {
  for (i in seq_along(dates)) {
    p   <- period_of(dates[i])
    # 每万人周基准率 0.12，叠加季节、长期趋势、SES 效应（低 SES 负担更高）
    lam <- geo$pop[r] * 0.12 * (1.45 - 0.55 * geo$ses[r]) *
           (1 + 0.5 * sin(2 * pi * (p - 9) / N_PERIODS)) *
           (1 + 0.005 * i / N_PERIODS)
    if (r == 10L && i > length(dates) - 6L) lam <- lam * 2.8  # 地区10 注入 6 周暴发
    k <- k + 1L
    rows[[k]] <- data.frame(date = as.character(dates[i]), region = geo$region[r],
                            count = rpois(1L, max(lam, 0.5)), disease = "HFRS",
                            stringsAsFactors = FALSE)
  }
}
raw <- do.call(rbind, rows)
# 故意混入两条脏记录，让 L1 质控有真实工作可做
raw <- rbind(raw, raw[100L, ])
raw$count[200L] <- NA_integer_
raw_csv <- file.path(out_dir, "raw_counts.csv")
write.csv(raw, raw_csv, row.names = FALSE, fileEncoding = "UTF-8")
# 正式 L0：read_counts() 读取只读原始表 -> epi_contract（含 geo / W / 质控 / meta）
core <- read_counts(
  raw_csv,
  geo          = geo,
  time_step    = "week",
  n_periods    = N_PERIODS,
  disease      = "HFRS",
  source_label = "合成示例面板（固定种子 20261110；非真实监测数据）"
)
validate_contract(core)                    # 字段 / 类型 / 主键 / 非负计数全量校验
contract <- core$data
geo      <- core$geo                       # 规范地区码表（含 region_id）
W        <- core$W                         # 行标准化 rook 邻接权重
qc       <- core$qc$report
n_drop   <- core$qc$dropped
dup_n    <- sum(core$qc$masks$duplicate)
na_n     <- sum(core$qc$masks$missing)
mark_stage("L0 epi-core", sprintf("契约 v%s 校验通过；原始面板 %d 行、%d 地区；邻接 %dx%d（%s）",
                                  EPI_CONTRACT_VERSION, core$meta$n_raw, nrow(geo),
                                  nrow(W), ncol(W), core_mode))
saveRDS(contract, file.path(cache_dir, "L0_contract.rds"))

# ---------------- L1 · 接入与质控（由 read_counts() 内的 epi_qc() 完成） ----------------
mark_stage("L1 epi-ingest", sprintf("read_counts() 质控剔除 %d 行（重复 %d / 缺失 %d）；清洁契约表 %d 行",
                                    n_drop, dup_n, na_n, nrow(contract)))

# ---------------- L2 · 监测与预警 ----------------
cur_year <- max(contract$year)
hist <- contract[contract$year < cur_year, ]
current <- contract[contract$year == cur_year, ]
band <- expand.grid(region = geo$region, period = 1L:N_PERIODS,
                    stringsAsFactors = FALSE, KEEP.OUT.ATTRS = FALSE)
band$baseline <- NA_real_; band$upper <- NA_real_
for (i in seq_len(nrow(band))) {
  w <- wrap_p((band$period[i] - 1L):(band$period[i] + 1L))
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
for (rg in geo$region) {
  ix <- which(cur$region == rg)
  if (!length(ix)) next
  rr <- rle(cur$exceed[ix]); lens <- integer(length(ix)); pos <- 1L
  for (j in seq_along(rr$lengths)) {
    if (rr$values[j]) lens[pos:(pos + rr$lengths[j] - 1L)] <- rr$lengths[j]
    pos <- pos + rr$lengths[j]
  }
  cur$run_len[ix] <- lens
}
ratio <- ifelse(!is.na(cur$upper) & cur$upper > 0, cur$count / pmax(cur$upper, 1), 0)
cur$level <- "正常"
cur$level[cur$run_len >= 1L] <- "关注"
cur$level[cur$run_len >= 2L | ratio >= 1.5] <- "预警"
cur$level[cur$run_len >= 3L | ratio >= 2.0] <- "告警"
alerts <- cur[cur$level != "正常", c("date", "region", "count", "upper", "run_len", "level")]
alerts <- alerts[order(match(alerts$level, c("告警", "预警", "关注")), -alerts$count), ]
write.csv(alerts, file.path(out_dir, "alerts.csv"), row.names = FALSE, fileEncoding = "UTF-8")
saveRDS(list(band = band, cur = cur, alerts = alerts), file.path(cache_dir, "L2_alert.rds"))
n_alert <- sum(cur$level %in% c("预警", "告警"))
mark_stage("L2 epi-alert", sprintf("季节性基线带 %d 组；评估 %d 期；关注/预警/告警共 %d 条（注入暴发命中 %d 周）",
                                   nrow(band), nrow(cur), nrow(alerts), sum(cur$region == "地区10" & cur$level == "告警")))

# ---------------- L3 · 空间自相关（epi-core 邻接权重 + Moran's I 置换检验） ----------------
# W 来自 read_counts() -> epi_adjacency()：行标准化 rook 权重，dimnames 为地区编码
tot <- aggregate(count ~ region, data = contract[contract$year == cur_year, ], sum)
tot <- merge(geo[, c("region", "pop")], tot, by = "region", all.x = TRUE)
tot$count[is.na(tot$count)] <- 0
tot$rate <- tot$count / tot$pop      # 每万人报告率
x <- tot$rate
moran_I <- function(v) {
  z <- v - mean(v)
  (length(v) / sum(W)) * sum(W * outer(z, z)) / sum(z^2)
}
I_obs <- moran_I(x)
set.seed(SEED + 1L)
I_null <- replicate(999L, moran_I(sample(x)))
p_val <- (1 + sum(abs(I_null) >= abs(I_obs))) / 1000L
saveRDS(list(W = W, tot = tot, I = I_obs, p = p_val), file.path(cache_dir, "L3_space.rds"))
mark_stage("L3 epi-space", sprintf("rook 邻接权重矩阵 %dx%d；Moran's I = %.3f（置换检验 p = %.3f）",
                                   nrow(W), ncol(W), I_obs, p_val))

# ---------------- L4 · 健康不平等（集中指数 CI + 组间率比） ----------------
tot$ses <- geo$ses[match(tot$region, geo$region)]
o <- order(tot$ses)
p <- tot$pop[o]; y <- tot$count[o]
cp <- c(0, cumsum(p) / sum(p)); cy <- c(0, cumsum(y) / sum(y))
area <- sum((cp[-1] - cp[-length(cp)]) * (cy[-1] + cy[-length(cy)]) / 2)
CI <- 1 - 2 * area                    # 负值 = 负担集中于低 SES 地区
rate_low  <- sum(tot$count[tot$ses < 0.5]) / sum(tot$pop[tot$ses < 0.5])
rate_high <- sum(tot$count[tot$ses >= 0.5]) / sum(tot$pop[tot$ses >= 0.5])
rate_ratio <- rate_low / rate_high
saveRDS(list(CI = CI, cp = cp, cy = cy, ratio = rate_ratio), file.path(cache_dir, "L4_ineq.rds"))
mark_stage("L4 epi-ineq", sprintf("集中指数 CI = %.3f；低/高 SES 地区报告率比 = %.2f", CI, rate_ratio))

# ---------------- L5 · 综合 HTML 报告（内联 SVG） ----------------
svg_series <- function(d, b) {
  Wd <- 860; H <- 240; L <- 52; R <- 16; T <- 24; B <- 32
  agg <- aggregate(count ~ date, data = d, sum)
  agg <- agg[order(agg$date), ]
  n <- nrow(agg); if (n < 2L) return("")
  upper <- sapply(agg$date, function(dt) {
    pp <- period_of(as.Date(dt))
    mean(vapply(wrap_p((pp - 1L):(pp + 1L)),
                function(w) sum(b$upper[b$period == w], na.rm = TRUE), numeric(1)))
  })
  ymax <- max(c(agg$count, upper), na.rm = TRUE) * 1.15
  X <- function(i) L + (i - 1L) * (Wd - L - R) / (n - 1L)
  Y <- function(v) H - B - pmin(v, ymax) / ymax * (H - T - B)
  poly <- paste0(paste(sprintf("%.1f,%.1f", X(seq_len(n)), Y(upper)), collapse = " "), " ",
                 paste(sprintf("%.1f,%.1f", X(rev(seq_len(n))), Y(rep(0, n))), collapse = " "))
  grid <- character(0)
  for (g in seq(0, 1, by = 0.25)) {
    yy <- H - B - g * (H - T - B)
    grid <- c(grid, sprintf('<line x1="%.0f" y1="%.1f" x2="%.0f" y2="%.1f" stroke="#e8edf2"/>', L, yy, Wd - R, yy),
              sprintf('<text x="%.0f" y="%.1f" font-size="11" fill="#8a97a5" text-anchor="end">%.0f</text>', L - 8, yy + 4, g * ymax))
  }
  sprintf(paste0('<svg viewBox="0 0 %d %d" width="100%%" height="%d" style="background:#fff;border:1px solid #e3e9f0;border-radius:10px">',
                 '%s<polygon points="%s" fill="#dce9f7" fill-opacity="0.8"/>',
                 '<polyline points="%s" fill="none" stroke="#2c6fbb" stroke-width="2"/>',
                 '<text x="%d" y="%d" font-size="11" fill="#8a97a5">%s</text>',
                 '<text x="%d" y="%d" font-size="11" fill="#8a97a5" text-anchor="end">%s</text></svg>'),
          Wd, H, H, paste(grid, collapse = ""), poly,
          paste(sprintf("%.1f,%.1f", X(seq_len(n)), Y(agg$count)), collapse = " "),
          L, H - 9, esc(format(min(agg$date), "%Y-%m-%d")),
          Wd - R, H - 9, esc(format(max(agg$date), "%Y-%m-%d")))
}

svg_grid <- function(tot, geo) {
  cols <- grDevices::colorRampPalette(c("#E6F1FB", "#185FA5"))(24)
  rr <- tot$rate / max(tot$rate)
  idx <- pmax(1L, pmin(24L, ceiling(rr * 24L)))
  cw <- 190L; ch <- 62L; gap <- 8L
  nr <- max(geo$row); nc <- max(geo$col)
  H <- 22L + nr * (ch + gap) + 26L
  s <- sprintf('<svg viewBox="0 0 860 %d" width="100%%" height="%d" style="background:#fff;border:1px solid #e3e9f0;border-radius:10px">', H, H)
  for (i in seq_len(nrow(geo))) {
    xx <- 40L + (geo$col[i] - 1L) * (cw + gap)
    yy <- 22L + (geo$row[i] - 1L) * (ch + gap)
    j <- match(geo$region[i], tot$region)
    s <- paste0(s,
      sprintf('<rect x="%d" y="%d" width="%d" height="%d" rx="8" fill="%s" stroke="#185FA5" stroke-width="0.5"/>',
              xx, yy, cw, ch, cols[idx[j]]),
      sprintf('<text x="%d" y="%d" font-size="13" font-weight="600" fill="#0c447c">%s</text>',
              xx + 12L, yy + 24L, esc(geo$region[i])),
      sprintf('<text x="%d" y="%d" font-size="12" fill="#185fa5">%.2f / 万人</text>',
              xx + 12L, yy + 45L, tot$rate[j]))
  }
  paste0(s, sprintf('<text x="40" y="%d" font-size="11" fill="#8a97a5">%d×%d 县级格网 · rook 邻接 · 颜色越深报告率越高</text></svg>',
                    H - 8L, nr, nc))
}

svg_lorenz <- function(cp, cy) {
  S <- 220; L <- 46; T <- 18
  X <- function(v) L + v * S; Y <- function(v) T + (1 - v) * S
  pts <- paste(sprintf("%.1f,%.1f", X(cp), Y(cy)), collapse = " ")
  sprintf(paste0('<svg viewBox="0 0 300 270" width="300" height="270" style="background:#fff;border:1px solid #e3e9f0;border-radius:10px">',
                 '<line x1="%.0f" y1="%.0f" x2="%.0f" y2="%.0f" stroke="#c9d6e4" stroke-dasharray="5 4" stroke-width="1.5"/>',
                 '<polyline points="%s" fill="none" stroke="#0f6e56" stroke-width="2.5"/>',
                 '%s',
                 '<text x="%d" y="%d" font-size="11" fill="#8a97a5">累计人口份额 →</text>',
                 '<text x="%d" y="%d" font-size="11" fill="#8a97a5">累计病例份额</text></svg>'),
          X(0), Y(0), X(1), Y(1), pts,
          paste(sprintf('<circle cx="%.1f" cy="%.1f" r="3.5" fill="#0f6e56"/>', X(cp), Y(cy)), collapse = ""),
          L, T + S + 22, 12, T + 8)
}

css <- paste0(
'*{box-sizing:border-box}body{margin:0;background:#f4f7fb;color:#243447;',
'font-family:"Microsoft YaHei","PingFang SC",-apple-system,Segoe UI,sans-serif;line-height:1.6}',
'.wrap{max-width:960px;margin:0 auto;padding:26px 20px 56px}',
'header{background:linear-gradient(120deg,#1f4e88,#2c7bc9);color:#fff;border-radius:14px;padding:24px 28px;margin-bottom:18px}',
'header h1{margin:0 0 6px;font-size:24px}header p{margin:2px 0;opacity:.9;font-size:13px}',
'.kpis{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin-bottom:18px}',
'.kpi{background:#fff;border:1px solid #e3e9f0;border-radius:12px;padding:14px 16px}',
'.kpi .v{font-size:22px;font-weight:700;color:#1f4e88}.kpi .l{font-size:12px;color:#718096}',
'.kpi.g .v{color:#2e9e6b}.kpi.o .v{color:#e67e22}',
'.card{background:#fff;border:1px solid #e3e9f0;border-radius:12px;padding:16px 20px;margin-bottom:16px}',
'.card h2{font-size:16px;margin:0 0 12px}.card h3{font-size:14px;margin:16px 0 8px}',
'.flow{display:grid;grid-template-columns:repeat(7,1fr);gap:6px;margin:0 0 6px}',
'.st{background:#e8f1fc;border-radius:8px;padding:8px 4px;text-align:center;font-size:11px;color:#1f4e88}',
'.st b{display:block;font-size:12px;margin-bottom:2px}',
'table{width:100%;border-collapse:collapse;font-size:12px}',
'th,td{padding:7px 9px;border-bottom:1px solid #edf1f6;text-align:left}',
'th{background:#f7f9fc;color:#5a6a7e;font-weight:600}',
'.two{display:grid;grid-template-columns:1fr 300px;gap:16px;align-items:start}',
'.note{font-size:12px;color:#5a6a7e;margin:0}',
'footer{font-size:11px;color:#8a97a5;text-align:center;margin-top:24px}',
'@media(max-width:700px){.kpis{grid-template-columns:repeat(2,1fr)}.two{grid-template-columns:1fr}.flow{grid-template-columns:repeat(2,1fr)}}')

stage_cards <- paste(vapply(stage_log, function(s)
  sprintf('<div class="st"><b>%s</b>%s</div>', esc(s$name), esc(sub("；.*$", "", s$detail))),
  character(1)), collapse = "")

qc_rows <- paste(sprintf('<tr><td>%s</td><td>%d</td><td>%s</td></tr>',
                         esc(qc$检查项), qc$检出, esc(qc$处理)), collapse = "")
alert_rows <- if (nrow(alerts)) {
  a <- head(alerts, 12L)
  paste(sprintf('<tr><td>%s</td><td>%s</td><td>%s</td><td>%.1f</td><td>%s</td><td>%s</td></tr>',
                esc(format(a$date, "%Y-%m-%d")), esc(a$region), esc(a$count),
                a$upper, esc(a$run_len), esc(a$level)), collapse = "")
} else '<tr><td colspan="6">本期无异常信号</td></tr>'
metric_rows <- paste0(
  sprintf('<tr><td>集中指数 CI</td><td>%.3f</td><td>负值表示负担集中于低 SES 地区</td></tr>', CI),
  sprintf('<tr><td>全局 Moran\'s I（最新年报告率）</td><td>%.3f</td><td>置换检验 p = %.3f（999 次）</td></tr>', I_obs, p_val),
  sprintf('<tr><td>低/高 SES 报告率比</td><td>%.2f</td><td>人口标化后</td></tr>', rate_ratio))

body <- sprintf(paste0(
'<header><h1>EpiStack 端到端综合分析报告</h1>',
'<p>L0 → L6 全链路演示 · 生成时间 %s</p>',
'<p>合成示例数据（固定种子 %d） · 原始面板只读 · 全程本地计算</p></header>',
'<div class="kpis">',
'<div class="kpi"><div class="v">%d</div><div class="l">契约表记录</div></div>',
'<div class="kpi o"><div class="v">%d</div><div class="l">质控剔除行</div></div>',
'<div class="kpi o"><div class="v">%d</div><div class="l">异常信号</div></div>',
'<div class="kpi g"><div class="v">%.3f</div><div class="l">集中指数 CI</div></div>',
'</div>',
'<section class="card"><h2>流水线执行状态</h2><div class="flow">%s</div>',
'<p class="note">每层均为真实计算（非占位）：质控、季节性基线带、Moran\'s I 置换检验、集中指数、报告、可复现清单。</p></section>',
'<section class="card"><h2>L1 · 数据质控</h2><table><thead><tr><th>检查项</th><th>检出</th><th>处理</th></tr></thead><tbody>%s</tbody></table></section>',
'<section class="card"><h2>L2 · 监测预警：合计时序与季节性基线带</h2>%s',
'<p class="note">蓝色为报告数，浅蓝带为历史同期 ±1 期的单侧 95%% 基线带上界。</p></section>',
'<section class="card"><h2>L3 / L4 · 空间格局与健康不平等</h2><div class="two"><div>',
'<h3>地区报告率格网</h3>%s</div><div><h3>集中曲线</h3>%s',
'<p class="note">虚线为完全平等线；实线在上方表示疾病负担更集中于低 SES 地区。</p></div></div>',
'<h3>关键指标</h3><table><thead><tr><th>指标</th><th>数值</th><th>解读</th></tr></thead><tbody>%s</tbody></table></section>',
'<section class="card"><h2>L2 · 异常信号清单（前 12 条）</h2><table>',
'<thead><tr><th>日期</th><th>地区</th><th>报告数</th><th>基线上界</th><th>连续超限</th><th>级别</th></tr></thead><tbody>%s</tbody></table></section>',
'<section class="card"><h2>方法与边界</h2><p class="note">',
'基线带：历史年份同一周期及相邻 ±1 期计数在 log(count+0.5) 尺度求均值与标准差，回推单侧 %.3fσ 上界。',
'预警分级：超限 1 期关注，连续 ≥2 期或超 1.5 倍预警，连续 ≥3 期或超 2 倍告警。',
'空间：4×4 县级格网 rook 邻接、行标准化，Moran\'s I + 999 次置换检验。',
'不平等：按 SES 升序、人口加权的集中指数 CI = 1 − 2×集中曲线下面积。',
'本报告为体系原型演示，阈值与口径需按病种和当地报告制度校准，<b>不可直接作为公共卫生决策依据</b>。</p></section>',
'<footer>EpiStack v0.1.0 · L0/L1 由 epiCore 正式包提供 · 单文件离线报告 · L6 manifest 见同目录 run_manifest.json</footer>'),
 esc(format(Sys.time(), "%Y-%m-%d %H:%M")), SEED,
 nrow(contract), n_drop, nrow(alerts), CI,
 stage_cards, qc_rows, svg_series(cur, band), svg_grid(tot, geo), svg_lorenz(cp, cy),
 metric_rows, alert_rows, K_SIGMA)

html <- paste0('<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8">',
               '<meta name="viewport" content="width=device-width,initial-scale=1">',
               '<title>EpiStack 端到端综合分析报告</title><style>', css, '</style></head><body><div class="wrap">',
               body, '</div></body></html>')
con <- file(out_html, open = "wt", encoding = "UTF-8")
writeLines(enc2utf8(html), con, useBytes = TRUE)
close(con)
mark_stage("L5 epi-report", sprintf("单文件综合报告输出：%s（%d 字节）", basename(out_html), file.info(out_html)$size))

# ---------------- L6 · 可复现 manifest ----------------
manifest <- sprintf(paste0(
'{\n  "pipeline": "EpiStack vertical slice v0.1.0",\n',
'  "generated_at": "%s",\n  "r_version": "%s",\n  "seed": %d,\n',
'  "stages": [\n%s\n  ],\n',
'  "contract": "date, region, count, population, disease",\n',
'  "core": {"package": "epiCore", "version": "%s", "load": "%s"},\n',
'  "inputs": {"raw_csv": "%s", "rows": %d, "regions": %d},\n',
'  "qc": {"dropped": %d, "duplicate": %d, "missing": %d},\n',
'  "results": {"n_records": %d, "n_alerts": %d, "moran_I": %.4f, "moran_p": %.4f, "CI": %.4f, "rate_ratio": %.4f},\n',
'  "outputs": {"report": "%s", "alerts_csv": "alerts.csv", "cache": "cache/L0,L2,L3,L4 rds"},\n',
'  "reproduce": "Rscript run_e2e.R",\n',
'  "privacy": "仅合成数据；真实监测数据不入库、不上传"\n}\n'),
 format(Sys.time(), "%Y-%m-%d %H:%M:%S"), R.version.string, SEED,
 paste(vapply(stage_log, function(s) sprintf('    {"stage": "%s", "detail": "%s", "elapsed_sec": %.2f}',
                                             s$name, gsub('"', "'", s$detail), s$secs), character(1)), collapse = ",\n"),
 EPI_CONTRACT_VERSION, core_mode,
 basename(raw_csv), nrow(raw), nrow(geo),
 n_drop, dup_n, na_n,
 nrow(contract), nrow(alerts), I_obs, p_val, CI, rate_ratio,
 basename(out_html))
writeLines(enc2utf8(manifest), file.path(out_dir, "run_manifest.json"), useBytes = TRUE)
mark_stage("L6 epi-flow", sprintf("manifest + 4 个阶段缓存已写入 cache/；总耗时 %.2f 秒",
                                  as.numeric(difftime(Sys.time(), t_start, units = "secs"))))

cat(sprintf("\n端到端链路完成：%s\n", out_html))
