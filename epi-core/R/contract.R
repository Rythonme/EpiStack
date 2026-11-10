# =============================================================
# epiCore / contract.R — 统一数据契约 schema 与校验（L0 地基）
# 零第三方依赖；所有层只认这张长表：date, region, count, population, disease
# =============================================================

EPI_CONTRACT_VERSION <- "0.1.0"
EPI_REQUIRED_FIELDS  <- c("date", "region", "count", "population", "disease")

#' 返回当前版本的契约 schema
epi_schema <- function(version = EPI_CONTRACT_VERSION) {
  list(
    version     = version,
    primary_key = c("date", "region", "disease"),
    granularity = c("week", "month", "quarter", "year"),
    fields = list(
      date = list(
        type = "Date", required = TRUE,
        note = "观察期锚点；周/月数据用真实日期，年数据用该年 1 月 1 日"
      ),
      region = list(
        type = "character", required = TRUE,
        note = "经 normalize_region() 规范化后的地区编码"
      ),
      count = list(
        type = "numeric", required = TRUE,
        note = "非负发病/报告计数；年发病率反算值须取整后使用并标注口径"
      ),
      population = list(
        type = "numeric", required = TRUE,
        note = "对应人口分母，必须为正数"
      ),
      disease = list(
        type = "character", required = TRUE,
        note = "病种代码，例如 HFRS"
      )
    ),
    derived    = c("year", "period"),
    geo_fields = c("region", "population", "ses", "row", "col"),
    note = "契约版本变更必须同步 inst/contract/schema.json 与集成冒烟测试"
  )
}

#' 校验契约对象或长表
#'
#' strict = TRUE 时遇问题直接报错；FALSE 时返回问题描述字符向量。
#' 返回 invisibly TRUE 表示通过。
validate_contract <- function(x, strict = TRUE, schema = epi_schema()) {
  d <- if (inherits(x, "epi_contract")) x$data else x
  problems <- character(0)

  if (!is.data.frame(d)) {
    if (strict) stop("契约必须是 data.frame 或 epi_contract 对象", call. = FALSE)
    return("契约必须是 data.frame 或 epi_contract 对象")
  }

  miss <- setdiff(EPI_REQUIRED_FIELDS, names(d))
  if (length(miss))
    problems <- c(problems, paste0("缺少必需字段: ", paste(miss, collapse = ", ")))

  if ("date" %in% names(d) && !inherits(d$date, "Date")) {
    parsed <- tryCatch(
      suppressWarnings(as.Date(as.character(d$date))),
      error = function(e) rep(as.Date(NA), length(d$date))
    )
    if (any(is.na(parsed) & !is.na(d$date)))
      problems <- c(problems, "date 列含有无法解析的日期")
  }

  if ("count" %in% names(d)) {
    cnt <- suppressWarnings(as.numeric(d$count))
    if (any(is.na(cnt)) || any(cnt < 0))
      problems <- c(problems, "count 列必须为有限的非负数")
  }

  if ("population" %in% names(d)) {
    pop <- suppressWarnings(as.numeric(d$population))
    if (any(is.na(pop)) || any(pop <= 0))
      problems <- c(problems, "population 列必须为正数")
  }

  if ("region" %in% names(d)) {
    rg <- as.character(d$region)
    if (any(is.na(rg)) || any(!nzchar(trimws(rg))))
      problems <- c(problems, "region 列含空值")
  }

  if (all(schema$primary_key %in% names(d))) {
    ndup <- sum(duplicated(d[schema$primary_key]))
    if (ndup > 0L)
      problems <- c(problems, sprintf("主键 (date+region+disease) 重复 %d 行", ndup))
  }

  if (strict && length(problems))
    stop(paste0("契约校验未通过：\n  - ", paste(problems, collapse = "\n  - ")),
         call. = FALSE)

  invisible(if (length(problems)) problems else TRUE)
}

#' 非严格校验：返回问题描述向量（无问题返回长度为 0 的 character）
epi_contract_check <- function(x, schema = epi_schema()) {
  validate_contract(x, strict = FALSE, schema = schema)
}

#' 契约对象摘要
print.epi_contract <- function(x, ...) {
  d <- x$data
  cat(sprintf("<epi_contract> v%s | %d 行 | %d 地区 | 粒度 %s | 质控剔除 %d 行\n",
              x$meta$version, nrow(d), length(unique(d$region)),
              x$meta$time_step, x$qc$dropped))
  if (!is.null(x$W))
    cat(sprintf("  邻接权重: %d x %d（行标准化）\n", nrow(x$W), ncol(x$W)))
  if (!is.null(x$meta$source))
    cat(sprintf("  数据源: %s\n", x$meta$source))
  invisible(x)
}
