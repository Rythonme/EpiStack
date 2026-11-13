# =============================================================
# epiIngest / desensitize.R — 分析前脱敏
#
# 用途：把可识别的地区编码换成不可逆的假名，再交给外部合作者或上传。
# 做法：加盐 SHA-256 取前 10 位十六进制。同一盐 + 同一编码永远得到同一假名，
# 所以纵向合并、面板匹配都不受影响；没有盐就无法反查。
# 日期只支持整体平移（所有地区同样天数），避免破坏同期可比性。
# =============================================================

.epi_sha256 <- function(x) {
  if (requireNamespace("openssl", quietly = TRUE))
    return(as.character(openssl::sha256(charToRaw(x))))
  if (requireNamespace("digest", quietly = TRUE))
    return(digest::digest(x, algo = "sha256", serialize = FALSE))
  .epi_stop("脱敏需要 openssl 或 digest 包：install.packages(\"openssl\")")
}

#' 对已读取的数据做脱敏
#'
#' @param x epi_ingest 对象或可直接读取的数据源
#' @param salt 盐值；必须由使用者提供，建议存在本机私有配置里，不要入库
#' @param region 是否把地区编码替换为假名
#' @param date_shift_days 整体日期平移天数，0 表示不平移
#' @param drop 需要从原始列中删除的字段名
#' @param key_file 若非 NULL，把「原编码 → 假名」对照表写到这里（再识别密钥，务必私有保存）
ingest_desensitize <- function(x, salt, region = TRUE, date_shift_days = 0L,
                               drop = NULL, key_file = NULL) {
  if (missing(salt) || is.null(salt) || !nzchar(as.character(salt)))
    .epi_stop("必须显式提供 salt；不要把盐值提交到仓库")
  salt <- as.character(salt)
  ing <- if (inherits(x, "epi_ingest")) x else ingest_read(x)

  d <- ing$data
  raw <- ing$raw
  map <- NULL

  if (isTRUE(region)) {
    regs <- sort(unique(d$region[!is.na(d$region)]))
    ps <- vapply(regs, function(r) paste0("R", substr(.epi_sha256(paste0(salt, "|", r)), 1L, 10L)), "")
    if (anyDuplicated(ps)) .epi_stop("假名冲突（盐值过短或地区过多），请换一个盐值")
    map <- data.frame(region = regs, pseudonym = unname(ps), stringsAsFactors = FALSE)
    d$region <- unname(ps[match(d$region, regs)])
    raw_col <- ing$meta$mapping$region %||% .epi_pick_col(names(raw), EPI_INGEST_ALIASES$region)
    if (!is.na(raw_col) && raw_col %in% names(raw))
      raw[[raw_col]] <- unname(ps[match(trimws(as.character(raw[[raw_col]])), regs)])
  }

  if (as.integer(date_shift_days) != 0L) {
    d$date <- d$date + as.integer(date_shift_days)
    raw_col <- ing$meta$mapping$date %||% .epi_pick_col(names(raw), EPI_INGEST_ALIASES$date)
    if (!is.na(raw_col) && raw_col %in% names(raw)) {
      rd <- .epi_parse_date(raw[[raw_col]])
      if (any(!is.na(rd))) raw[[raw_col]][!is.na(rd)] <-
        format(rd[!is.na(rd)] + as.integer(date_shift_days))
    }
  }

  if (length(drop)) raw <- raw[, setdiff(names(raw), drop), drop = FALSE]

  if (!is.null(key_file) && !is.null(map)) {
    dir.create(dirname(key_file), recursive = TRUE, showWarnings = FALSE)
    utils::write.csv(map, key_file, row.names = FALSE, fileEncoding = "UTF-8")
    .epi_warn("%s 是再识别密钥，请只保存在本机私有目录并加入 .gitignore", key_file)
  }

  ing$data <- d
  ing$raw <- raw
  ing$meta$desensitized <- list(
    algorithm = "sha256-salted",
    region    = isTRUE(region),
    salt_hash = .epi_hash_string(salt),
    n_region  = if (is.null(map)) 0L else nrow(map),
    date_shift_days = as.integer(date_shift_days),
    dropped   = as.character(drop),
    at        = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  )
  ing
}
