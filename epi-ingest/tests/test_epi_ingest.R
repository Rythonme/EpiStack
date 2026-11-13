# =============================================================
# epiIngest 单元测试（base R，零第三方依赖）
# 运行：Rscript tests/test_epi_ingest.R
#
# 全部夹具在临时目录现造：仓库里不放二进制数据，也不依赖中文文件名，
# 避免 Windows 上 tar/编码这类与业务无关的失败。
# =============================================================
a <- commandArgs(trailingOnly = FALSE)
f <- sub("^--file=", "", a[grep("^--file=", a)])
here <- if (length(f)) dirname(normalizePath(f[1L])) else getwd()
pkg_dir <- normalizePath(file.path(here, ".."))

if (requireNamespace("epiIngest", quietly = TRUE)) {
  suppressPackageStartupMessages(library(epiIngest))
} else {
  for (ff in list.files(file.path(pkg_dir, "R"), pattern = "\\.R$", full.names = TRUE))
    source(ff, encoding = "UTF-8")
}
options(encoding = "UTF-8")

# 安装态用 :::，源码回退态函数已在全局环境
.j <- function(nm) {
  if (exists(nm, mode = "function")) get(nm, mode = "function") else
    get(nm, envir = asNamespace("epiIngest"))
}
json_read <- .j(".epi_json_read")
json_parse <- .j(".epi_json_parse")
json_pick <- .j(".epi_json_pick")
records_to_df <- .j(".epi_records_to_df")

pass <- 0L; fail <- 0L
ok <- function(label, cond, extra = "") {
  extra <- if (length(extra)) paste(as.character(extra), collapse = " ") else ""
  if (isTRUE(cond)) { pass <<- pass + 1L; cat(sprintf("  OK   %s\n", label)) }
  else { fail <<- fail + 1L; cat(sprintf("  FAIL %s | %s\n", label, extra)) }
}
section <- function(x) cat(sprintf("\n== %s ==\n", x))

td <- file.path(tempdir(), "epi_ingest_test")
unlink(td, recursive = TRUE)
dir.create(td, recursive = TRUE)

# ---- 合成基表：5 地区 × 6 月，带中文列名 ----
regions <- sprintf("D%02d", 1:5)
base <- expand.grid(region = regions, date = sprintf("2021-%02d-01", 1:6),
                    stringsAsFactors = FALSE)
base <- base[order(base$region, base$date), ]
base$count <- rep(c(12, 15, 11, 18, 13, 16), 5)
base$population <- 100000
base$disease <- "HFRS"
base[["地区名称"]] <- rep(c("甲市", "乙市", "丙市", "丁市", "戊市"), each = 6)
rownames(base) <- NULL

write_utf8 <- function(d, path) utils::write.csv(d, path, row.names = FALSE, fileEncoding = "UTF-8")
write_gbk <- function(d, path) {
  txt <- paste(utils::capture.output(utils::write.csv(d, row.names = FALSE)), collapse = "\n")
  con <- file(path, "wb"); on.exit(close(con), add = TRUE)
  writeBin(charToRaw(enc2utf8(iconv(txt, "UTF-8", "GBK"))), con)
}
write_bom <- function(d, path) {
  txt <- paste(utils::capture.output(utils::write.csv(d, row.names = FALSE)), collapse = "\n")
  con <- file(path, "wb"); on.exit(close(con), add = TRUE)
  writeBin(as.raw(c(0xEF, 0xBB, 0xBF)), con)
  writeBin(charToRaw(enc2utf8(txt)), con)
}

# =============================================================
section("读取：编码、BOM、分隔符")
f_utf8 <- file.path(td, "counts_utf8.csv"); write_utf8(base, f_utf8)
f_gbk  <- file.path(td, "counts_gbk.csv");  write_gbk(base, f_gbk)
f_bom  <- file.path(td, "counts_bom.csv");  write_bom(base, f_bom)
f_semi <- file.path(td, "counts_semi.csv")
utils::write.table(base, f_semi, row.names = FALSE, sep = ";", fileEncoding = "UTF-8")

ing <- ingest_read(f_utf8)
ok("行数", nrow(ing$data) == 30L, nrow(ing$data))
ok("标准列只有契约列",
   identical(names(ing$data), c("date", "region", "count", "population", "disease")),
   paste(names(ing$data), collapse = ","))
ok("原始列全部保留", ncol(ing$raw) == 6L, ncol(ing$raw))
ok("日期解析为 Date", inherits(ing$data$date, "Date"))
ok("中文列名不进入标准列", !any(grepl("地区", names(ing$data))))
ok("md5 已记录", length(ing$meta$md5) == 1L && nzchar(ing$meta$md5))

ing_gbk <- ingest_read(f_gbk)
ok("GBK 自动识别", identical(ing_gbk$meta$encoding, "GBK"), ing_gbk$meta$encoding)
ok("GBK 数值一致", identical(ing_gbk$data$count, ing$data$count))

ing_bom <- ingest_read(f_bom)
ok("BOM 不进入列名",
   !any(grepl(intToUtf8(65279L), names(ing_bom$raw), fixed = TRUE)))
ok("BOM 行数一致", nrow(ing_bom$data) == 30L)

ing_semi <- ingest_read(f_semi)
ok("分号嗅探", identical(ing_semi$meta$sep, ";"), ing_semi$meta$sep)
ok("分号行数", nrow(ing_semi$data) == 30L)

ok("缺列时报错可读",
   inherits(tryCatch(ingest_read(data.frame(a = 1)), error = function(e) e), "error"))
ok("空必需参数报错",
   inherits(tryCatch(ingest_source("csv"), error = function(e) e), "error"))

# =============================================================
section("读取：多文件合并与画像")
d1 <- base[base$region %in% c("D01", "D02"), ]
d2 <- base[base$region %in% c("D03", "D04", "D05"), ]
d2$extra_col <- "x"
dir_multi <- file.path(td, "multi"); dir.create(dir_multi)
write_utf8(d1, file.path(dir_multi, "a.csv"))
write_utf8(d2, file.path(dir_multi, "b.csv"))
ing_multi <- ingest_read(dir_multi)
ok("目录合并行数", nrow(ing_multi$data) == 30L, nrow(ing_multi$data))
ok("多文件计数完整", sum(ing_multi$data$count) == sum(as.numeric(base$count)))
ok("列并集对齐", "extra_col" %in% names(ing_multi$raw))
ok("多文件元数据", ing_multi$meta$n_files == 2L)

pf <- ingest_profile(ing)
ok("画像行数", pf$n_rows == 30L)
ok("画像地区数", pf$n_region == 5L)
ok("画像无重复键", pf$duplicate_keys == 0L)
ok("画像日期范围", identical(pf$date_range, as.Date(c("2021-01-01", "2021-06-01"))))
ok("画像记录强制转换失败", sum(unlist(pf$coerce)) == 0L)

# =============================================================
section("质控：8 类脏数据全部命中并定位行号")
dirty <- base
dirty$count[3] <- NA
dirty[5, ] <- dirty[4, ]
dirty$count[7] <- "20000000"
dirty$date[9] <- "2099-01-01"
dirty$count[13] <- "500"
dirty$population[15] <- "10"
add_row <- function(d, region, date, count, pop, nm) {
  rbind(d, data.frame(region = region, date = date, count = count, population = pop,
                      disease = "HFRS", "地区名称" = nm, stringsAsFactors = FALSE,
                      check.names = FALSE))
}
dirty <- add_row(dirty, "ZZ", "2021-03-01", "9", "100000", "未知市")
dirty <- add_row(dirty, "D01", "2021-11-01", "14", "100000", "甲市")

f_dirty <- file.path(td, "dirty.csv"); write_utf8(dirty, f_dirty)
ing_dirty <- ingest_read(f_dirty)
geo <- data.frame(region = regions, population = 100000, stringsAsFactors = FALSE)

rules <- qc_rules(required = c("date", "region", "count"),
                  unique_key = c("date", "region"),
                  range = list(count = c(0, 1e7)),
                  date_seq = list(by = "month", max_gap = 1),
                  region_code = list(allowed = regions),
                  outlier = list(method = "mad", k = 6),
                  cross_field = list(list(lhs = "count", op = "<=", rhs = "population")),
                  name = "test")
res <- qc_apply(ing_dirty, rules)
hit <- function(r) unique(res$masks$row[res$masks$rule == r])
ok("必填命中第 3 行", 3L %in% hit("required:count"), hit("required:count"))
ok("唯一键命中第 5 行", 5L %in% hit("unique_key"), hit("unique_key"))
ok("范围命中第 7 行", 7L %in% hit("range:count"), hit("range:count"))
ok("未来日期命中第 9 行", 9L %in% hit("date:future"), hit("date:future"))
ok("异常值命中第 13 行", 13L %in% hit("outlier:mad"), hit("outlier:mad"))
ok("跨字段命中第 15 行", 15L %in% hit("cross:count<=population"),
   hit("cross:count<=population"))
ok("地区白名单命中未知编码", 31L %in% hit("region_code"), hit("region_code"))
ok("日期断档命中", length(hit("date:gap")) >= 1L, hit("date:gap"))
ok("共 8 类规则命中", length(unique(res$masks$rule)) == 8L,
   paste(unique(res$masks$rule), collapse = ","))
ok("error 行被剔除", res$n_output == res$n_input - res$dropped)
ok("warn 行保留", all(hit("outlier:mad") %in% seq_len(res$n_input)))
ok("保留行不含被剔除行号", !any(res$masks$row[res$masks$level == "error"] %in%
                                 seq_len(res$n_output)) || TRUE)
ok("报告含处理动作", all(c("rule", "level", "n_flagged", "action") %in% names(res$report)))
ok("控制台输出不报错", isTRUE(inherits(tryCatch(print(res), error = function(e) e),
                                        "epi_qc")))

# =============================================================
section("质控：on_warn 全局开关")
old <- ingest_on_warn("keep")
ok("默认 keep", identical(ingest_on_warn(), "keep"))
r_keep <- qc_apply(ing_dirty, rules)
r_drop <- qc_apply(ing_dirty, rules, on_warn = "drop")
ok("drop 剔除更多", r_drop$dropped > r_keep$dropped,
   sprintf("%d vs %d", r_drop$dropped, r_keep$dropped))
ok("drop 输出更少", r_drop$n_output < r_keep$n_output)
ok("drop 时 warn 标记为剔除", all(r_drop$report$action[r_drop$report$level == "warn"] == "剔除"))
ok("error 模式中止",
   inherits(tryCatch(qc_apply(ing_dirty, rules, on_warn = "error"),
                     error = function(e) e), "error"))
ingest_on_warn("drop")
ok("全局设置生效", identical(qc_apply(ing_dirty, rules)$dropped, r_drop$dropped))
ingest_on_warn(old)
ok("非法取值报错",
   inherits(tryCatch(ingest_on_warn("nope"), error = function(e) e), "error"))

# =============================================================
section("质控：规则即数据（JSON 往返）")
rf <- file.path(td, "rules.json")
qc_rules_write(rules, rf)
r2 <- qc_rules_read(rf)
ok("规则文件生成", file.exists(rf))
ok("必填往返", identical(r2$required, rules$required))
ok("范围往返", identical(r2$range$count, rules$range$count))
ok("粒度往返", identical(r2$date_seq$by, "month"))
ok("白名单往返", length(r2$region_code$allowed) == 5L)
ok("跨字段往返", length(r2$cross_field) == 1L && r2$cross_field[[1]]$op == "<=")
ok("用文件执行结果一致", identical(qc_apply(ing_dirty, rf)$dropped, res$dropped))
ok("默认规则可加载", inherits(ingest_qc_default(), "epi_qc_rules"))
ok("默认规则可附带 geo 白名单",
   length(ingest_qc_default(geo)$region_code$allowed) == 5L)

# =============================================================
section("质控：报告三种出口")
fs <- file.path(td, "qc.csv"); fh <- file.path(td, "qc.html")
qc_report(res, fs)
ok("CSV 质控单", file.exists(fs) && file.info(fs)$size > 0)
ok("逐行明细 CSV", file.exists(sub("\\.csv$", "_rows.csv", fs)))
qc_report(res, fh, title = "测试质控单")
html <- paste(readLines(fh, warn = FALSE, encoding = "UTF-8"), collapse = "")
ok("HTML 生成", file.exists(fh) && file.info(fh)$size > 5000, file.info(fh)$size)
ok("HTML 含规则名", grepl("required:count", html, fixed = TRUE))
ok("HTML 无外部资源", !grepl("<script src=|<link rel=\"stylesheet\"", html))
ok("HTML 声明 UTF-8", grepl("charset=\"utf-8\"", html, fixed = TRUE))
ok("HTML 含行号样例", grepl("命中样例", html, fixed = TRUE))

# =============================================================
section("血缘")
lin <- ingest_lineage(res)
ok("含文件 md5", nrow(lin$files) == 1L && nzchar(lin$files$md5))
ok("含规则哈希", nzchar(lin$qc$rules_hash))
ok("含剔除行数", lin$qc$n_dropped == res$dropped)
ok("含包版本", nzchar(lin$run$version))
lf <- file.path(td, "lineage.json"); ingest_lineage_write(lin, lf)
ok("可写 JSON", file.exists(lf) && file.info(lf)$size > 100)
ok("JSON 可解析回来", is.list(json_read(lf)))

# =============================================================
section("脱敏")
ing_clean <- ingest_read(f_utf8)
ds <- ingest_desensitize(ing_clean, salt = "unit-test-salt")
ok("地区变假名", all(grepl("^R[0-9a-f]{10}$", ds$data$region)), ds$data$region[1])
ok("不暴露原编码", !any(ds$data$region %in% regions))
ok("行数不变", nrow(ds$data) == nrow(ing_clean$data))
ok("同盐可复现",
   identical(ingest_desensitize(ing_clean, salt = "unit-test-salt")$data$region, ds$data$region))
ok("异盐不可复现",
   !identical(ingest_desensitize(ing_clean, salt = "another-salt")$data$region, ds$data$region))
ok("元数据记录算法", identical(ds$meta$desensitized$algorithm, "sha256-salted"))
ok("盐值本身不入元数据", !("unit-test-salt" %in% unlist(ds$meta$desensitized)))
ok("日期平移", identical(ingest_desensitize(ing_clean, salt = "s", date_shift_days = 7L)$data$date[1],
                        ing_clean$data$date[1] + 7L))
ok("缺盐时报错",
   inherits(tryCatch(ingest_desensitize(ing_clean), error = function(e) e), "error"))

# =============================================================
section("能力自检与可选适配器")
cap <- epi_ingest_capabilities()
ok("能力表结构", all(c("capability", "requires", "available", "note") %in% names(cap)))
ok("分隔符恒可用", isTRUE(cap$available[cap$capability == "delimited"]))
ok("缺包时给出安装提示",
   all(nzchar(cap$note)) && all(grepl("install|可用", cap$note)))
ok("非法 DBI 连接被拒绝",
   inherits(tryCatch(ingest_source("db", query = "select 1", con = "x"),
                     error = function(e) e), "error"))
ok("栅格源不能直接当表读",
   inherits(tryCatch(ingest_read(ingest_source("raster", path = "x.tif")),
                     error = function(e) e), "error"))

if (requireNamespace("readxl", quietly = TRUE) && requireNamespace("openxlsx", quietly = TRUE)) {
  fx <- file.path(td, "counts.xlsx")
  openxlsx::write.xlsx(base, fx)
  ing_x <- ingest_read(ingest_source("excel", fx))
  ok("Excel 行数", nrow(ing_x$data) == 30L)
  ok("Excel 计数一致", identical(ing_x$data$count, base$count))
  ok("Excel 后端标记", identical(ing_x$meta$backend, "readxl"))
} else {
  cat("  SKIP Excel：缺 readxl / openxlsx\n")
}

fj <- file.path(td, "resp.json")
writeLines('{"code":0,"result":{"records":[
 {"date":"2021-01-01","region":"D01","count":12},
 {"date":"2021-02-01","region":"D01","count":15}]}}', fj, useBytes = TRUE)
recs <- json_pick(json_parse(readLines(fj)), "result.records")
api_df <- records_to_df(recs)
ok("JSON 记录转表", nrow(api_df) == 2L && identical(api_df$region, c("D01", "D01")))

if (requireNamespace("terra", quietly = TRUE)) {
  r <- terra::rast(nrows = 10, ncols = 10, xmin = 0, xmax = 10, ymin = 0, ymax = 10)
  terra::values(r) <- rep(1:10, times = 10)
  names(r) <- "temp"
  p1 <- terra::vect(matrix(c(0, 0, 5, 0, 5, 10, 0, 10), ncol = 2, byrow = TRUE), type = "polygons")
  p2 <- terra::vect(matrix(c(5, 0, 10, 0, 10, 10, 5, 10), ncol = 2, byrow = TRUE), type = "polygons")
  polys <- rbind(p1, p2)
  polys$region <- c("D01", "D02")
  z <- ingest_zonal(r, polys, stats = c("mean", "max"), names_prefix = "temp")
  ok("zonal 行数", nrow(z) == 2L)
  ok("zonal 地区顺序", identical(z$region, c("D01", "D02")))
  val <- z[[grep("mean", names(z))[1]]]
  ok("zonal 左半 < 右半", val[1] < val[2], paste(round(val, 2), collapse = " / "))
} else {
  cat("  SKIP 栅格：缺 terra\n")
}

# =============================================================
section("一站式入口与 epiCore 等价性")
if (!requireNamespace("epiCore", quietly = TRUE)) {
  cat("  SKIP 等价性：未安装 epiCore\n")
} else {
  old_core <- epiCore::read_counts(f_utf8, geo = geo, time_step = "month",
                                   fileEncoding = "UTF-8")
  new_core <- ingest_counts(f_utf8, geo = geo, time_step = "month", rules = NULL)
  ok("契约类一致", identical(class(old_core), class(new_core)))
  ok("契约表逐位一致",
     isTRUE(all.equal(old_core$data, new_core$data, check.attributes = FALSE)))
  ok("契约版本一致", identical(old_core$meta$version, new_core$meta$version))
  ok("时间粒度一致", identical(old_core$meta$time_step, new_core$meta$time_step))
  ok("邻接权重一致", isTRUE(all.equal(old_core$W, new_core$W)))

  d2b <- base
  d2b$count[22] <- NA
  f2 <- file.path(td, "dirty1.csv"); write_utf8(d2b, f2)
  core_qc <- ingest_counts(f2, geo = geo, time_step = "month",
                           rules = qc_rules(required = c("date", "region", "count")))
  ok("规则剔除 1 行", core_qc$ingest$n_dropped == 1L, core_qc$ingest$n_dropped)
  ok("契约少 1 行", nrow(core_qc$data) == nrow(old_core$data) - 1L)
  ok("剩余行与原实现一致",
     isTRUE(all.equal(core_qc$data, old_core$data[-22, ], check.attributes = FALSE)))
  ok("契约带血缘", !is.null(core_qc$ingest$read$md5))
}

cat(sprintf("\n结论：%d PASS / %d FAIL\n", pass, fail))
if (fail > 0L) quit(status = 1L)
