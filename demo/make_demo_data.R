# =============================================================
# EpiStack · 内置模拟数据生成器（公开仓库默认数据源）
#
# 目的：让任何人 clone 后无需任何真实数据，就能跑通「31 地区面板 →
#       邻接权重 → 预警 → 空间自相关 → 健康不平等 → HTML 报告」全链路。
#
# 全部数值由固定种子的伪随机数生成，地区编码为 D01..D31，
# 不对应任何真实行政区、不含任何真实观测记录、不含任何本机路径。
#
# 生成的文件与真实数据适配器的列结构完全一致，因此下游脚本零改动。
# =============================================================

epi_make_demo_data <- function(dir, seed = 20261110L) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  set.seed(seed)

  n_region <- 31L
  years    <- 2004:2024
  regions  <- sprintf("D%02d", seq_len(n_region))

  # ---- 4×8 规则格网取前 31 格，rook 邻接；保证无孤岛、结构对称 ----
  grid <- expand.grid(row = 1:4, col = 1:8)[seq_len(n_region), ]
  nb <- lapply(seq_len(n_region), function(i) {
    which(abs(grid$row - grid$row[i]) + abs(grid$col - grid$col[i]) == 1L)
  })
  stopifnot(all(lengths(nb) > 0L))
  graph_lines <- c(
    as.character(n_region),
    vapply(seq_len(n_region), function(i)
      paste(c(i, length(nb[[i]]), nb[[i]]), collapse = " "), character(1))
  )
  graph_path <- file.path(dir, "demo_adj.graph")
  writeLines(graph_lines, graph_path, useBytes = TRUE)

  # ---- 人口与 SES：SES 沿格网呈空间梯度，便于演示 Moran's I ----
  pop <- round(runif(n_region, 2.0e7, 1.1e8))
  ses_base <- 0.15 + 0.65 * (grid$col - 1L) / 7 + runif(n_region, -0.06, 0.06)
  ses_base <- pmin(pmax(ses_base, 0.02), 0.98)
  gdp <- round(30000 + 120000 * ses_base)

  # ---- 省-年发病面板：长期下降 + 低 SES 高负担 + 泊松噪声 ----
  rows <- vector("list", length(years) * n_region)
  k <- 0L
  for (yy in years) {
    decline <- 0.90 ^ (yy - min(years))          # 长期下降
    for (i in seq_len(n_region)) {
      rate <- (1.35 - 0.85 * ses_base[i]) * decline * runif(1L, 0.75, 1.25)
      lam  <- max(0.5, pop[i] / 1e5 * rate)
      cnt  <- stats::rpois(1L, lam)
      k <- k + 1L
      rows[[k]] <- data.frame(
        province    = regions[i],
        year        = yy,
        cases_est   = cnt,
        pop         = pop[i],
        rate_per100k = 1e5 * cnt / pop[i],
        stringsAsFactors = FALSE
      )
    }
  }
  inc <- do.call(rbind, rows)
  inc_path <- file.path(dir, "demo_incidence.csv")
  utils::write.csv(inc, inc_path, row.names = FALSE, fileEncoding = "UTF-8")

  # ---- SES 面板：每年一份，最新年用于集中指数 ----
  ses <- do.call(rbind, lapply(years, function(yy) {
    data.frame(prov = regions, year = yy,
               X1_gdp_pcap = round(gdp * (1 + 0.02 * (yy - min(years)))),
               stringsAsFactors = FALSE)
  }))
  ses_path <- file.path(dir, "demo_ses.csv")
  utils::write.csv(ses, ses_path, row.names = FALSE, fileEncoding = "UTF-8")

  # ---- 月度轴面板：只有气候协变量，没有发病结局（与真实口径一致） ----
  month_grid <- expand.grid(month = 1:12, year = years, province = regions,
                            KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  m <- month_grid$month
  month_grid$temp   <- round(15 + 12 * sin(2 * pi * (m - 7) / 12) +
                               stats::rnorm(nrow(month_grid), 0, 1.5), 1)
  month_grid$prec   <- round(pmax(0, 60 + 40 * sin(2 * pi * (m - 5) / 12) +
                                    stats::rnorm(nrow(month_grid), 0, 12)), 1)
  month_grid$season <- ((m - 1L) %/% 3L) + 1L
  mo <- month_grid[, c("province", "year", "month", "temp", "prec", "season")]
  mo_path <- file.path(dir, "demo_month.csv")
  utils::write.csv(mo, mo_path, row.names = FALSE, fileEncoding = "UTF-8")

  # ---- 月度发病结局（模拟）：供 --monthly 演示季节性基线带链路 ----
  # 地区编码与上面的面板完全一致，避免 read_counts() 因地区未知全部剔除
  n_month <- 36L
  m_dates   <- rep(seq(as.Date("2022-01-01"), by = "month", length.out = n_month),
                   each = n_region)
  m_regions <- rep(regions, times = n_month)
  m_pop     <- rep(pop, times = n_month)
  m_month   <- as.integer(format(m_dates, "%m"))
  lam <- m_pop / 1e5 * (0.4 + 0.6 * sin(2 * pi * (m_month - 6) / 12)) *
         (1.3 - 0.6 * rep(ses_base, times = n_month))
  counts <- stats::rpois(length(m_dates), pmax(lam, 0.1))
  counts_path <- file.path(dir, "demo_counts_month.csv")
  utils::write.csv(
    data.frame(date = as.character(m_dates), region = m_regions,
               count = counts, population = m_pop, disease = "DEMO",
               stringsAsFactors = FALSE),
    counts_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(incidence = inc_path, graph = graph_path,
       ses = ses_path, monthly = mo_path, counts = counts_path,
       seed = seed, regions = regions, years = range(years))
}
