# =============================================================
# EpiBulletin 最小可运行原型（v0.0.1）
# 传染病监测周/月报一键生成器：CSV -> 自包含单文件 HTML 报告
#
# 用法：
#   Rscript demo_epibulletin.R                          # 用内置合成示例数据
#   Rscript demo_epibulletin.R input.csv out.html      # 用自己的数据
#
# 输入 CSV 列：date, region, count
#   date   : YYYY-MM-DD（周/月起始日，脚本按 7 天周期自动折算周期序号）
#   region : 地区/病种名称（UTF-8 中文可）
#   count  : 该期病例数（非负整数）
#
# 依赖：零第三方包，仅 base R（作图直接手写内联 SVG）
# 输出：单文件 HTML（离线可开、可直接转发）+ 预警清单.csv
# =============================================================

args <- commandArgs(trailingOnly = TRUE)
input_csv <- if (length(args) >= 1L) args[1L] else NA_character_
out_html  <- if (length(args) >= 2L) args[2L] else file.path(getwd(), "监测周报示例.html")
out_dir   <- dirname(out_html)
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

# ---------------- 参数（v0.1 中将改为配置项） ----------------
K_SIGMA     <- 1.645   # 单侧 95% 上界（对数尺度）
MIN_HIST    <- 3L      # 每个周期至少需要的历史观测数
WINDOW      <- 1L      # 相邻周期窗口（w-1, w, w+1）
N_PERIODS   <- 52L     # 一年周期数（月度数据改为 12）

# ---------------- 工具函数 ----------------
esc <- function(x) {
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;",  x, fixed = TRUE)
  x <- gsub(">", "&gt;",  x, fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  x
}

period_of <- function(d, n_periods = N_PERIODS) {
  # 用 day-of-year 折算周期序号，避免 Windows 下 %V/%G 的兼容问题
  yday <- as.integer(format(d, "%j"))
  p <- 1L + floor((yday - 1L) / (365.25 / n_periods))
  pmin(pmax(p, 1L), n_periods)
}

wrap_period <- function(w, n = N_PERIODS) ((w - 1L) %% n) + 1L

# ---------------- 1. 数据载入 / 合成示例 ----------------
if (!is.na(input_csv)) {
  dat <- read.csv(input_csv, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
  data_note <- paste0("外部数据：", esc(basename(input_csv)))
} else {
  set.seed(20261110)
  regions <- c("示例地区A", "示例地区B", "示例地区C")
  dates <- seq(as.Date("2021-01-04"), by = "week", length.out = 52L * 5L)
  base_level <- c(9, 14, 6)
  rows <- list()
  k <- 0L
  for (r in seq_along(regions)) {
    for (i in seq_along(dates)) {
      k <- k + 1L
      p <- period_of(dates[i])
      lambda <- base_level[r] +
        0.55 * base_level[r] * sin(2 * pi * (p - 9) / 52) +
        0.012 * i
      # 最后一个流行季在"示例地区B"注入一次持续 6 周的异常升高
      if (r == 2L && i > length(dates) - 6L) lambda <- lambda * 2.6
      rows[[k]] <- data.frame(
        date   = as.character(dates[i]),
        region = regions[r],
        count  = rpois(1L, max(lambda, 0.5)),
        stringsAsFactors = FALSE
      )
    }
  }
  dat <- do.call(rbind, rows)
  demo_csv <- file.path(out_dir, "example_counts.csv")
  write.csv(dat, demo_csv, row.names = FALSE, fileEncoding = "UTF-8")
  data_note <- paste0("内置合成示例数据（已导出 ", esc(basename(demo_csv)), "，可替换为自己的 CSV）")
}

need <- c("date", "region", "count")
miss <- setdiff(need, names(dat))
if (length(miss)) stop("输入 CSV 缺少必需列：", paste(miss, collapse = ", "))

dat$date  <- as.Date(dat$date)
dat$count <- as.numeric(dat$count)
dat$year  <- as.integer(format(dat$date, "%Y"))
dat$period <- period_of(dat$date)
dat <- dat[!is.na(dat$date) & !is.na(dat$count) & dat$count >= 0, ]
dat <- dat[order(dat$region, dat$date), ]
if (!nrow(dat)) stop("输入数据为空或不合法")

cur_year  <- max(dat$year)
hist      <- dat[dat$year < cur_year, , drop = FALSE]
current   <- dat[dat$year == cur_year, , drop = FALSE]
if (!nrow(hist)) stop("至少需要 2 个年份的数据才能建立历史基线")

# ---------------- 2. 季节性基线带（endemic channel，几何均值法简化版） ----------------
# 对每个 (region, period)，取历史年份同一周期及相邻 ±WINDOW 周期的计数，
# 在 log(count + 0.5) 尺度上求均值与标准差，回推基线与单侧上界。
regions_all <- sort(unique(dat$region))
band <- expand.grid(region = regions_all, period = 1L:N_PERIODS,
                    stringsAsFactors = FALSE, KEEP.OUT.ATTRS = FALSE)
band$baseline <- NA_real_
band$upper    <- NA_real_
band$n_hist   <- 0L

for (i in seq_len(nrow(band))) {
  rg <- band$region[i]; pp <- band$period[i]
  wanted <- wrap_period((pp - WINDOW):(pp + WINDOW))
  z <- hist$count[hist$region == rg & hist$period %in% wanted]
  band$n_hist[i] <- length(z)
  if (length(z) >= MIN_HIST) {
    lz <- log(z + 0.5)
    mu <- mean(lz); sd <- stats::sd(lz)
    band$baseline[i] <- exp(mu) - 0.5
    band$upper[i]    <- exp(mu + K_SIGMA * sd) - 0.5
  }
}

cur <- merge(current, band, by = c("region", "period"), all.x = TRUE, sort = FALSE)
cur <- cur[order(cur$region, cur$date), ]
cur$exceed <- !is.na(cur$upper) & cur$count > cur$upper

# ---------------- 3. 预警分级（连续超限周数 + 超出幅度） ----------------
cur$run_len <- 0L
for (rg in regions_all) {
  ix <- which(cur$region == rg)
  if (!length(ix)) next
  rr <- rle(cur$exceed[ix])
  lens <- rep(0L, length(ix))
  pos <- 1L
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
cur$level <- factor(cur$level, levels = c("告警", "预警", "关注", "正常"), ordered = TRUE)

alerts <- cur[cur$level != "正常", c("date", "region", "period", "count", "baseline", "upper", "run_len", "level")]
alerts <- alerts[order(alerts$level, -alerts$count), ]
alert_csv <- file.path(out_dir, "预警清单.csv")
write.csv(alerts, alert_csv, row.names = FALSE, fileEncoding = "UTF-8")

# ---------------- 4. 内联 SVG 时序图 ----------------
svg_plot <- function(d, b, title) {
  W <- 860; H <- 260; L <- 52; R <- 16; T <- 24; B <- 34
  n <- nrow(d)
  if (n < 2L) return("")
  ymax <- max(c(d$count, d$upper, b$upper), na.rm = TRUE) * 1.15
  ymax <- max(ymax, 5)
  X <- function(i) L + (i - 1) * (W - L - R) / (n - 1L)
  Y <- function(v) H - B - pmin(v, ymax) / ymax * (H - T - B)
  upper <- ifelse(is.na(d$upper), 0, d$upper)
  baseline <- ifelse(is.na(d$baseline), 0, d$baseline)
  poly_pts <- paste0(
    paste(sprintf("%.1f,%.1f", X(seq_len(n)), Y(upper)), collapse = " "), " ",
    paste(sprintf("%.1f,%.1f", X(rev(seq_len(n))), Y(rev(baseline))), collapse = " ")
  )
  line_pts <- paste(sprintf("%.1f,%.1f", X(seq_len(n)), Y(d$count)), collapse = " ")
  base_pts <- paste(sprintf("%.1f,%.1f", X(seq_len(n)), Y(baseline)), collapse = " ")
  pts <- character(0)
  for (i in seq_len(n)) {
    if (d$level[i] != "正常") {
      col <- switch(as.character(d$level[i]), 告警 = "#c0392b", 预警 = "#e67e22", "#f1c40f")
      pts <- c(pts, sprintf('<circle cx="%.1f" cy="%.1f" r="4" fill="%s" stroke="#fff" stroke-width="1"/>',
                            X(i), Y(d$count[i]), col))
    }
  }
  grid <- character(0)
  for (g in seq(0, 1, by = 0.25)) {
    yy <- H - B - g * (H - T - B)
    grid <- c(grid, sprintf('<line x1="%.0f" y1="%.1f" x2="%.0f" y2="%.1f" stroke="#e8edf2" stroke-width="1"/>', L, yy, W - R, yy),
              sprintf('<text x="%.0f" y="%.1f" font-size="11" fill="#8a97a5" text-anchor="end">%.0f</text>',
                      L - 8, yy + 4, g * ymax))
  }
  sprintf(paste0(
    '<svg viewBox="0 0 %d %d" width="100%%" height="%d" role="img" aria-label="%s" ',
    'style="background:#fff;border:1px solid #e3e9f0;border-radius:10px">',
    '<text x="%d" y="16" font-size="13" font-weight="600" fill="#243447">%s</text>',
    '%s',
    '<polygon points="%s" fill="#dce9f7" fill-opacity="0.75"/>',
    '<polyline points="%s" fill="none" stroke="#9fb8d0" stroke-width="1.5" stroke-dasharray="4 3"/>',
    '<polyline points="%s" fill="none" stroke="#2c6fbb" stroke-width="2"/>',
    '%s',
    '<text x="%d" y="%d" font-size="11" fill="#8a97a5">%s</text>',
    '<text x="%d" y="%d" font-size="11" fill="#8a97a5" text-anchor="end">%s</text>',
    '</svg>'),
    W, H, H, esc(title),
    L, esc(title),
    paste(grid, collapse = ""),
    poly_pts, base_pts, line_pts,
    paste(pts, collapse = ""),
    L, H - 10, esc(format(min(d$date), "%Y-%m-%d")),
    W - R, H - 10, esc(format(max(d$date), "%Y-%m-%d")))
}

plots <- character(0)
for (rg in regions_all) {
  d <- cur[cur$region == rg, ]
  b <- band[band$region == rg, ]
  if (nrow(d) >= 2L) {
    n_alert <- sum(d$level %in% c("预警", "告警"))
    plots <- c(plots,
      sprintf('<section class="card"><h3>%s <span class="tag">%d 期 · %d 条预警/告警</span></h3>%s</section>',
              esc(rg), nrow(d), n_alert, svg_plot(d, b, paste0(rg, " · ", cur_year, " 年监测曲线"))))
  }
}

# ---------------- 5. 组装单文件 HTML ----------------
n_alert <- sum(cur$level %in% c("预警", "告警"))
n_watch <- sum(cur$level == "关注")
n_red   <- sum(cur$level == "告警")
alert_rows <- if (nrow(alerts)) {
  paste0("<tr>", apply(alerts, 1L, function(r) {
    lv <- as.character(r["level"])
    cls <- switch(lv, 告警 = "lv-red", 预警 = "lv-orange", "lv-yellow")
    sprintf('<td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td class="%s">%s</td>',
      esc(r["date"]), esc(r["region"]), esc(r["period"]), esc(r["count"]),
      esc(sprintf("%.1f", as.numeric(r["upper"]))), esc(r["run_len"]), cls, esc(lv))
  }), "</tr>", collapse = "\n")
} else '<tr><td colspan="7" class="empty">本评估期无异常信号</td></tr>'

html <- sprintf(paste0(
'<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8">',
'<meta name="viewport" content="width=device-width,initial-scale=1">',
'<title>传染病监测周报 · EpiBulletin</title><style>',
'*{box-sizing:border-box}body{margin:0;background:#f4f7fb;color:#243447;',
'font-family:"Microsoft YaHei","PingFang SC",-apple-system,Segoe UI,sans-serif;line-height:1.6}',
'.wrap{max-width:960px;margin:0 auto;padding:28px 20px 60px}',
'header{background:linear-gradient(120deg,#1f4e88,#2c7bc9);color:#fff;border-radius:14px;padding:26px 30px;margin-bottom:20px}',
'header h1{margin:0 0 6px;font-size:25px}header p{margin:2px 0;opacity:.9;font-size:13px}',
'.kpis{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin-bottom:20px}',
'.kpi{background:#fff;border:1px solid #e3e9f0;border-radius:12px;padding:16px 18px}',
'.kpi .v{font-size:26px;font-weight:700;color:#1f4e88}.kpi .l{font-size:12px;color:#718096}',
'.kpi.warn .v{color:#e67e22}.kpi.red .v{color:#c0392b}',
'.card{background:#fff;border:1px solid #e3e9f0;border-radius:12px;padding:18px 20px;margin-bottom:18px}',
'.card h2,.card h3{margin:0 0 12px;font-size:17px}.card h3{font-size:15px}',
'.tag{font-size:11px;font-weight:400;color:#718096;background:#f0f4f9;padding:3px 9px;border-radius:20px;margin-left:8px}',
'table{width:100%%;border-collapse:collapse;font-size:13px}',
'th,td{padding:8px 10px;border-bottom:1px solid #edf1f6;text-align:left}',
'th{background:#f7f9fc;color:#5a6a7e;font-weight:600}',
'.lv-red{color:#c0392b;font-weight:700}.lv-orange{color:#e67e22;font-weight:600}',
'.lv-yellow{color:#b7950b}.empty{text-align:center;color:#8a97a5;padding:18px}',
'.legend{font-size:12px;color:#718096;margin-top:10px}',
'.legend span{display:inline-block;margin-right:16px}',
'.sw{display:inline-block;width:12px;height:12px;border-radius:3px;vertical-align:-2px;margin-right:5px}',
'footer{font-size:12px;color:#8a97a5;text-align:center;margin-top:26px}',
'@media(max-width:640px){.kpis{grid-template-columns:repeat(2,1fr)}}',
'</style></head><body><div class="wrap">',
'<header><h1>传染病监测周报</h1>',
'<p>EpiBulletin 原型报告 · 生成时间 %s</p>',
'<p>数据来源：%s ｜ 历史基线：%d–%d 年 ｜ 评估期：%d 年</p></header>',
'<div class="kpis">',
'<div class="kpi"><div class="v">%d</div><div class="l">监测地区</div></div>',
'<div class="kpi"><div class="v">%d</div><div class="l">评估期数</div></div>',
'<div class="kpi warn"><div class="v">%d</div><div class="l">预警 / 告警信号</div></div>',
'<div class="kpi red"><div class="v">%d</div><div class="l">告警（红色）</div></div>',
'</div>',
'<section class="card"><h2>本期异常信号清单</h2><table>',
'<thead><tr><th>日期</th><th>地区</th><th>周期</th><th>报告数</th><th>基线上界</th><th>连续超限</th><th>级别</th></tr></thead>',
'<tbody>%s</tbody></table>',
'<div class="legend"><span><i class="sw" style="background:#dce9f7"></i>历史基线带</span>',
'<span><i class="sw" style="background:#2c6fbb"></i>报告病例数</span>',
'<span><i class="sw" style="background:#c0392b"></i>超限点</span></div></section>',
'%s',
'<section class="card"><h2>方法与口径</h2><p style="font-size:13px;color:#5a6a7e;margin:0">',
'按地区与年度周期（默认 52 期）建立季节性基线带：取历史年份同一周期及相邻 ±%d 期的计数，',
'在 log(count + 0.5) 尺度上计算均值与标准差，回推基线值与单侧 %.3fσ 上界（近似 95%%）。',
'超限 1 期为「关注」，连续 ≥2 期或超上界 1.5 倍为「预警」，连续 ≥3 期或超上界 2 倍为「告警」。',
'本报告为原型演示，参数与阈值需按病种和当地报告口径校准，<b>不可直接作为公共卫生决策依据</b>。</p></section>',
'<footer>EpiBulletin v0.0.1 prototype · 纯 base R 生成 · 单文件离线报告 · 数据全程本地处理</footer>',
'</div></body></html>'),
  esc(format(Sys.time(), "%Y-%m-%d %H:%M")),
  data_note,
  min(hist$year), max(hist$year), cur_year,
  length(regions_all), nrow(cur), n_alert, n_red,
  alert_rows,
  paste(plots, collapse = "\n"),
  WINDOW, K_SIGMA
)

con <- file(out_html, open = "wt", encoding = "UTF-8")
writeLines(enc2utf8(html), con, useBytes = TRUE)
close(con)

cat(sprintf("完成：%s | 地区 %d | 评估期 %d | 关注 %d / 预警+告警 %d | 告警 %d\n",
            out_html, length(regions_all), nrow(cur), n_watch, n_alert, n_red))
cat(sprintf("预警清单：%s\n", alert_csv))
