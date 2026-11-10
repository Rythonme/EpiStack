# =============================================================
# epiCore 单元测试（base R，零第三方依赖）
# 运行：Rscript tests/test_epi_core.R
# =============================================================
a <- commandArgs(trailingOnly = FALSE)
f <- sub("^--file=", "", a[grep("^--file=", a)])
here <- if (length(f)) dirname(normalizePath(f[1L])) else getwd()
pkg_dir <- normalizePath(file.path(here, ".."))
# 已安装（含 R CMD check 的临时 library）时直接 attach；
# 否则回退为按文件名顺序 source 源码，保证单独 Rscript 也能跑。
if (requireNamespace("epiCore", quietly = TRUE)) {
  suppressPackageStartupMessages(library(epiCore))
} else {
  for (ff in list.files(file.path(pkg_dir, "R"), pattern = "\\.R$", full.names = TRUE))
    source(ff, encoding = "UTF-8")
}

pass <- 0L
check <- function(label, expr) {
  ok <- isTRUE(tryCatch(expr, error = function(e) FALSE))
  if (!ok) stop(sprintf("测试失败: %s", label), call. = FALSE)
  pass <<- pass + 1L
  cat(sprintf("  OK  %s\n", label))
}

cat("== 契约 schema ==\n")
check("schema 版本", identical(epi_schema()$version, "0.1.0"))
check("必需字段", identical(names(epi_schema()$fields),
                            c("date", "region", "count", "population", "disease")))
check("缺列时 strict 报错", inherits(tryCatch(
  validate_contract(data.frame(date = as.Date("2020-01-01"), a = 1)),
  error = function(e) e), "error"))
check("缺列时非严格返回问题", length(epi_contract_check(data.frame(a = 1))) > 0L)
good <- data.frame(date = as.Date("2020-01-01"), region = "A", count = 3,
                   population = 100, disease = "HFRS", stringsAsFactors = FALSE)
check("合法契约通过", isTRUE(validate_contract(good)))
check("重复主键被拒绝", inherits(tryCatch(
  validate_contract(rbind(good, good)), error = function(e) e), "error"))

cat("== 地区编码 ==\n")
check("行政后缀清理", identical(
  normalize_region(c(" 陕西省 ", "内蒙古自治区", "新疆维吾尔自治区", "北京市")),
  c("陕西", "内蒙古", "新疆", "北京")))
check("BOM 与空白清理", identical(normalize_region(paste0(intToUtf8(65279L), " 上海 ")), "上海"))
check("别名映射", identical(normalize_region("长安", aliases = c("长安" = "西安")), "西安"))
check("重复编码报错", inherits(tryCatch(
  epi_region_codes(c("陕西省", "陕西")), error = function(e) e), "error"))
check("码表 id 连续", identical(epi_region_codes(c("A", "B"))$region_id, 1:2))

cat("== 时间粒度 ==\n")
d <- as.Date(c("2021-01-04", "2021-02-01", "2021-12-27"))
check("week 周期在 1..52", all(epi_period(d, 52L, "week") >= 1L & epi_period(d, 52L, "week") <= 52L))
check("month 周期", identical(epi_period(as.Date("2021-06-15"), 12L, "month"), 6L))
check("quarter 周期", identical(epi_period(as.Date("2021-11-01"), 4L, "quarter"), 4L))
check("year 序号", identical(epi_period(as.Date(c("2004-01-01", "2006-01-01")), 21L, "year"), c(1L, 3L)))
check("周期回绕", identical(epi_wrap_period(c(0L, 53L), 52L), c(52L, 1L)))
check("周期标签", identical(epi_period_label(6L, "month"), "6月"))

cat("== 邻接权重 ==\n")
geo <- data.frame(region = paste0("地区", 1:16),
                  row = rep(1:4, each = 4L), col = rep(1:4, times = 4L),
                  stringsAsFactors = FALSE)
W <- epi_adjacency(geo, "rook")
W0 <- epi_adjacency(geo, "rook", row_standardize = FALSE)
check("格网矩阵维度", identical(dim(W), c(16L, 16L)))
check("邻接结构对称", isTRUE(all.equal(W0, t(W0), check.attributes = FALSE)))
check("行标准化", all(abs(rowSums(W) - 1) < 1e-12))
check("dimnames 为地区编码", identical(rownames(W), geo$region))
check("体检无孤岛", length(epi_adjacency_check(W)$islands) == 0L)
Wq <- epi_adjacency(geo, "queen")
check("queen 边数多于 rook", sum(Wq > 0) > sum(W > 0))

gfile <- tempfile(fileext = ".graph")
writeLines(c("3", "1 1 2", "2 2 1 3", "3 1 2"), gfile)
Wg <- epi_read_graph(gfile, regions = c("甲", "乙", "丙"))
Wg0 <- epi_read_graph(gfile, regions = c("甲", "乙", "丙"), row_standardize = FALSE)
check("INLA graph 解析", identical(dim(Wg), c(3L, 3L)))
check("INLA graph 结构对称", isTRUE(all.equal(Wg0, t(Wg0), check.attributes = FALSE)))
check("INLA graph 行和", all(abs(rowSums(Wg) - 1) < 1e-12))
unlink(gfile)

cat("== 质控 ==\n")
raw <- data.frame(
  date = as.character(as.Date("2020-01-01") + c(0, 1, 2, 3, 4)),
  region = c("A", "A", "B", "C", "A"),
  count = c(1, NA, 3, 4, 5),
  disease = rep("HFRS", 5),
  stringsAsFactors = FALSE
)
raw <- rbind(raw, raw[1L, ])                 # 重复键
raw$date[3L] <- "not-a-date"                 # 坏日期
q <- epi_qc(raw, geo = data.frame(region = c("A", "B"), stringsAsFactors = FALSE))
check("质控剔行数", q$dropped >= 3L)
check("质控报告完整", nrow(q$report) == 5L)
check("干净表无 NA 计数", all(!is.na(q$data$count)))
check("干净表 date 为 Date", inherits(q$data$date, "Date"))

cat("== read_counts 主入口 ==\n")
csv <- tempfile(fileext = ".csv")
dirty <- data.frame(
  date = as.character(as.Date("2021-01-04") + 0:4),
  region = rep("地区1", 5L),
  count = c(2, 3, NA, 5, 6),
  disease = rep("HFRS", 5L),
  stringsAsFactors = FALSE
)
dirty <- rbind(dirty, dirty[1L, ])
utils::write.csv(dirty, csv, row.names = FALSE, fileEncoding = "UTF-8")
g <- data.frame(region = "地区1", row = 1L, col = 1L, pop = 100000,
                ses = 0.4, stringsAsFactors = FALSE)
g2 <- rbind(g, data.frame(region = "地区2", row = 1L, col = 2L,
                          pop = 120000, ses = 0.6, stringsAsFactors = FALSE))
core <- read_counts(csv, geo = g2, time_step = "week")
check("返回 epi_contract 对象", inherits(core, "epi_contract"))
check("剔除了 2 行脏数据", identical(core$qc$dropped, 2L))
check("契约字段齐全", all(names(epi_schema()$fields) %in% names(core$data)))
check("兼容旧列名 pop", "pop" %in% names(core$data))
check("population 从 geo 补齐", all(core$data$population == 100000))
check("ses 从 geo 合并", all(core$data$ses == 0.4))
check("周期列存在", "period" %in% names(core$data))
check("自动构建邻接", !is.null(core$W) && identical(dim(core$W), c(2L, 2L)))
check("契约校验通过", isTRUE(validate_contract(core)))
check("auto 推断年粒度", identical(
  read_counts(data.frame(year = 2004:2006, province = "陕西",
                         cases_est = c(10, 12, 15), pop = 3.8e7),
              time_step = "auto")$meta$time_step, "year"))
unlink(csv)

cat(sprintf("\nepiCore 全部 %d 项测试通过\n", pass))
