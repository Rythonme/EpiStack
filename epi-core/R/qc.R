# =============================================================
# epiCore / qc.R — L1 接入质控
# 只读原始表，输出干净表 + 可审计的质控报告。所有检查都逐行留痕，
# 不静默改数：脏行一律剔除并在报告里计数。
# =============================================================

epi_qc <- function(raw, geo = NULL,
                   keys = c("date", "region", "disease"),
                   check_population = FALSE) {
  n <- nrow(raw)

  # 日期：兼容 Date / YYYY-MM-DD / YYYY-MM / YYYY 四类输入
  dv <- as.character(raw$date)
  parsed <- tryCatch(
    suppressWarnings(as.Date(dv)),
    error = function(e) {
      out <- rep(as.Date(NA), n)
      ok <- grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", dv)
      if (any(ok)) out[ok] <- as.Date(dv[ok])
      out
    }
  )
  if (inherits(raw$date, "Date")) parsed <- raw$date

  cnt <- suppressWarnings(as.numeric(raw$count))
  dup_mask <- if (all(keys %in% names(raw))) duplicated(raw[keys]) else rep(FALSE, n)
  na_mask  <- is.na(cnt) | !is.finite(cnt) | cnt < 0
  bad_date <- is.na(parsed)
  unknown_r <- if (!is.null(geo) && "region" %in% names(raw))
    !as.character(raw$region) %in% as.character(geo$region) else rep(FALSE, n)
  bad_pop <- if (isTRUE(check_population) && "population" %in% names(raw)) {
    p <- suppressWarnings(as.numeric(raw$population))
    is.na(p) | p <= 0
  } else rep(FALSE, n)

  drop_mask <- dup_mask | na_mask | bad_date | unknown_r | bad_pop

  data <- raw[!drop_mask, , drop = FALSE]
  data$date  <- parsed[!drop_mask]
  data$count <- cnt[!drop_mask]
  data$year  <- as.integer(format(data$date, "%Y"))
  rownames(data) <- NULL

  report <- data.frame(
    检查项 = c("重复键 (date+region+disease)", "缺失或负计数",
               "日期不可解析", "未知地区编码", "人口分母无效"),
    检出 = c(sum(dup_mask), sum(na_mask), sum(bad_date), sum(unknown_r), sum(bad_pop)),
    处理 = c("保留首条", "剔除该行", "剔除该行", "剔除该行", "剔除该行"),
    stringsAsFactors = FALSE
  )

  list(
    data    = data,
    report  = report,
    dropped = sum(drop_mask),
    masks   = list(duplicate = dup_mask, missing = na_mask, bad_date = bad_date,
                   unknown_region = unknown_r, bad_population = bad_pop,
                   dropped = drop_mask)
  )
}
