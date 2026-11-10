# =============================================================
# epiCore / read_counts.R — L0 + L1 主入口
#
# 一张原始表（CSV 或 data.frame）-> 一个 epi_contract 对象：
#   data : 规范长表 date/region/count/population/disease + year/period
#   geo  : 地区码表（region/region_id/population/ses/row/col）
#   W    : 行标准化邻接权重（规则格网或真实 .graph）
#   qc   : 质控报告与逐行留痕
#   meta : 契约版本、时间粒度、数据源、行数
#
# 时间粒度可配置：week / month / quarter / year，auto 时按日期间隔推断。
# 换层不改契约，这是整个 EpiStack 能拼起来的唯一保证。
# =============================================================

EPI_FIELD_ALIASES <- list(
  date       = c("date", "日期", "时间", "year", "年", "年份", "month_date", "ym"),
  region     = c("region", "province", "prov", "省", "省份", "地区", "地区名称", "area", "county"),
  count      = c("count", "cases", "cases_est", "发病数", "病例数", "报告数", "n", "value"),
  population = c("population", "pop", "人口", "人口数", "pop_total"),
  disease    = c("disease", "病种", "疾病")
)

.epi_pick_col <- function(nms, candidates) {
  hit <- intersect(candidates, nms)
  if (length(hit)) hit[1L] else NA_character_
}

.epi_parse_dates <- function(v) {
  v <- trimws(as.character(v))
  if (length(v) && all(grepl("^[0-9]{4}$", v)))
    return(as.Date(paste0(v, "-01-01")))
  if (length(v) && all(grepl("^[0-9]{4}-[0-9]{1,2}$", v)))
    return(as.Date(paste0(v, "-01")))
  ok <- grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", v)
  out <- rep(as.Date(NA), length(v))
  if (any(ok)) out[ok] <- as.Date(v[ok])
  out
}

.epi_infer_step <- function(d) {
  dd <- sort(unique(d[!is.na(d)]))
  if (length(dd) < 2L) return("week")
  gap <- stats::median(as.numeric(diff(dd)))
  if (gap >= 300) "year" else if (gap >= 25) "month" else "week"
}

#' 读取并规范化监测计数
read_counts <- function(x, geo = NULL, mapping = NULL,
                        disease = "HFRS",
                        time_step = c("auto", "week", "month", "quarter", "year"),
                        n_periods = NULL,
                        graph = NULL,
                        adj_style = c("rook", "queen"),
                        aliases = NULL,
                        qc = TRUE,
                        fileEncoding = "UTF-8",
                        strict = TRUE,
                        source_label = NULL) {
  adj_style <- match.arg(adj_style)
  time_step <- match.arg(time_step)

  # ---- 1. 读取（原始文件只读，绝不回写） ----
  if (is.character(x) && length(x) == 1L) {
    raw <- utils::read.csv(x, fileEncoding = fileEncoding,
                           stringsAsFactors = FALSE, check.names = FALSE)
    src <- x
  } else if (is.data.frame(x)) {
    raw <- as.data.frame(x, stringsAsFactors = FALSE)
    src <- "<data.frame>"
  } else {
    stop("x 必须是 CSV 路径或 data.frame", call. = FALSE)
  }
  bom <- intToUtf8(65279L)
  names(raw) <- gsub(bom, "", names(raw), fixed = TRUE)
  n <- nrow(raw)

  # ---- 2. 列名映射（显式 mapping 优先，其次内置别名） ----
  map <- as.list(mapping %||% list())
  for (f in names(EPI_FIELD_ALIASES)) {
    if (is.null(map[[f]]) || is.na(map[[f]]))
      map[[f]] <- .epi_pick_col(names(raw), EPI_FIELD_ALIASES[[f]])
  }
  for (f in c("date", "region", "count")) {
    if (is.na(map[[f]]))
      stop(sprintf("找不到 %s 列；请用 mapping 显式指定（现有列：%s）",
                   f, paste(names(raw), collapse = ", ")), call. = FALSE)
  }

  # ---- 3. 规范长表 ----
  dates <- .epi_parse_dates(raw[[map$date]])
  region <- normalize_region(raw[[map$region]], aliases = aliases)
  count  <- suppressWarnings(as.numeric(raw[[map$count]]))
  population <- if (!is.na(map$population))
    suppressWarnings(as.numeric(raw[[map$population]])) else rep(NA_real_, n)
  disease_col <- if (!is.na(map$disease)) as.character(raw[[map$disease]]) else rep(disease, n)

  d <- data.frame(date = dates, region = region, count = count,
                  population = population, disease = disease_col,
                  stringsAsFactors = FALSE)

  # ---- 4. geo 表规范化 ----
  geo_norm <- NULL
  if (!is.null(geo)) {
    g <- as.data.frame(geo, stringsAsFactors = FALSE)
    names(g) <- gsub(bom, "", names(g), fixed = TRUE)
    if (!"region" %in% names(g)) {
      alt <- .epi_pick_col(names(g), EPI_FIELD_ALIASES$region)
      if (is.na(alt)) stop("geo 表必须含 region 列", call. = FALSE)
      names(g)[names(g) == alt] <- "region"
    }
    g$region <- normalize_region(g$region, aliases = aliases)
    if (!"population" %in% names(g)) {
      alt <- .epi_pick_col(names(g), EPI_FIELD_ALIASES$population)
      if (!is.na(alt)) g$population <- as.numeric(g[[alt]])
    }
    codes <- epi_region_codes(g$region, strip_suffix = FALSE)
    g$region_id <- codes$region_id[match(g$region, codes$region)]
    geo_norm <- g
  }

  # ---- 5. L1 质控 ----
  if (isTRUE(qc)) {
    q <- epi_qc(d, geo = geo_norm)
    clean <- q$data
  } else {
    q <- list(data = d, dropped = 0L,
              report = data.frame(检查项 = "未启用质控", 检出 = 0L, 处理 = "-",
                                  stringsAsFactors = FALSE),
              masks = list())
    clean <- d
  }

  # ---- 6. 补人口分母与地理属性，保持与旧版列兼容 ----
  if (!is.null(geo_norm)) {
    extra <- intersect(c("population", "ses", "row", "col", "region_id", "label"),
                       names(geo_norm))
    g2 <- geo_norm[, c("region", setdiff(extra, "population")), drop = FALSE]
    if ("population" %in% extra) {
      # 只回填 clean 自身的人口列；不要把它塞进待合并的 g2，
      # 否则 merge 会产出 population.x / population.y 而破坏契约。
      fill <- is.na(clean$population)
      repl <- geo_norm$population[match(clean$region[fill], geo_norm$region)]
      clean$population[fill] <- repl
    }
    clean <- merge(clean, g2, by = "region", all.x = TRUE, sort = FALSE)
  } else if (any(is.na(clean$population))) {
    stop("缺少 population 分母：请提供 geo 表或在原始表中给出人口列", call. = FALSE)
  }
  clean$pop <- clean$population                     # 兼容旧列名（deprecated）
  clean <- clean[order(clean$region, clean$date), ]
  rownames(clean) <- NULL

  # ---- 7. 时间粒度与周期 ----
  if (time_step == "auto") time_step <- .epi_infer_step(clean$date)
  if (is.null(n_periods) || is.na(n_periods)) {
    n_periods <- switch(time_step, week = 52L, month = 12L, quarter = 4L,
                        year = length(unique(clean$year)))
  }
  clean$period <- epi_period(clean$date, n_periods = n_periods, time_step = time_step)

  # ---- 8. 邻接权重 ----
  W <- NULL
  if (!is.null(graph)) {
    regs <- if (!is.null(geo_norm)) geo_norm$region else sort(unique(clean$region))
    W <- epi_read_graph(graph, regions = regs)
  } else if (!is.null(geo_norm) && all(c("row", "col") %in% names(geo_norm))) {
    W <- epi_adjacency(geo_norm, style = adj_style)
  }

  # ---- 9. 契约校验 ----
  if (isTRUE(strict)) validate_contract(clean)

  structure(
    list(
      data = clean,
      geo  = geo_norm,
      W    = W,
      qc   = q,
      meta = list(
        version    = EPI_CONTRACT_VERSION,
        time_step  = time_step,
        n_periods  = as.integer(n_periods),
        source     = source_label %||% src,
        n_raw      = n,
        n_clean    = nrow(clean),
        created_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
      )
    ),
    class = "epi_contract"
  )
}

`%||%` <- function(a, b) if (is.null(a)) b else a
