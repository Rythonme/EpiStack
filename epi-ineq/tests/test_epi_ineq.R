# =============================================================
# epiIneq 单元测试（base R，零第三方依赖）
# 运行：Rscript tests/test_epi_ineq.R
#
# 重点：集中曲线与 CI 手算一致、SII 的加权回归可复算、分解恒等式、
#       可达性距离衰减、三出口、错误输入、与切片口径逐位对齐。
# =============================================================
a <- commandArgs(trailingOnly = FALSE)
f <- sub("^--file=", "", a[grep("^--file=", a)])
here <- if (length(f)) dirname(normalizePath(f[1L])) else getwd()
pkg_dir <- normalizePath(file.path(here, ".."))

if (requireNamespace("epiIneq", quietly = TRUE)) {
  suppressPackageStartupMessages(library(epiIneq))
} else {
  for (ff in list.files(file.path(pkg_dir, "R"), pattern = "\\.R$", full.names = TRUE))
    source(ff, encoding = "UTF-8")
}
options(encoding = "UTF-8")

pass <- 0L; fail <- 0L
ok <- function(label, cond, extra = "") {
  extra <- if (length(extra)) paste(as.character(extra), collapse = " ") else ""
  cond <- isTRUE(cond)
  if (cond) { pass <<- pass + 1L; cat(sprintf("  [PASS] %s\n", label)) }
  else { fail <<- fail + 1L; cat(sprintf("  [FAIL] %s %s\n", label, extra)) }
}
catch_err <- function(expr) inherits(try(force(expr), silent = TRUE), "try-error")

cat("\n== 合成示例与一站式 ==\n")
d <- ineq_example()
ok("示例含契约列与 ses/x/y",
   all(c("date", "region", "count", "population", "disease", "ses", "x", "y") %in% names(d)))
ok("示例无随机性（两次调用相同）", identical(d, ineq_example()))
x <- ineq_counts(d)
ok("返回 epi_ineq 类", inherits(x, "epi_ineq"))
ok("核心字段齐全",
   all(c("curve", "ci", "sii", "gini", "decompose", "access", "groups", "core", "summary") %in% names(x)))
ok("地区数为 16", x$meta$n == 16L)
ok("CI 为负（弱势负担更重）", x$ci < 0)
ok("低/高 SES 率比 > 1", x$core$rate_ratio > 1)
ok("SII 为负", x$sii$sii < 0)
ok("SII 显著", x$sii$p_value < 0.05)
ok("Gini 在 0–1", x$gini >= 0 && x$gini <= 1)
ok("PAF 在 0–1", x$core$paf >= 0 && x$core$paf <= 1)
ok("CI ≈ 曲线手算", abs(x$ci - (1 - 2 * x$curve$area)) < 1e-12)
ok("summary 含 7 项指标", nrow(x$summary) == 7L)

cat("\n== 集中曲线手算 ==\n")
t4 <- data.frame(region = letters[1:4], ses = c(0.1, 0.3, 0.6, 0.9),
                 population = c(100, 200, 300, 400),
                 count = c(50, 40, 30, 20), stringsAsFactors = FALSE)
cp <- c(0, cumsum(t4$population) / sum(t4$population))
cy <- c(0, cumsum(t4$count) / sum(t4$count))
area_manual <- sum((cp[-1] - cp[-length(cp)]) * (cy[-1] + cy[-length(cy)]) / 2)
ok("ineq_ci 与梯形法手算一致", abs(ineq_ci(t4) - (1 - 2 * area_manual)) < 1e-12)
cv <- ineq_curve(t4)
ok("曲线首点等于首组份额",
   abs(cv$curve$cum_pop[1] - t4$population[1] / sum(t4$population)) < 1e-12)
ok("曲线末点为 1", abs(tail(cv$curve$cum_pop, 1) - 1) < 1e-12)
ok("曲线点数 = 地区数", nrow(cv$curve) == nrow(t4))
ok("CI 与 ineq_curve 一致", abs(ineq_ci(cv) - cv$CI) < 1e-12)

cat("\n== SII 手算 ==\n")
p <- t4$population
r <- (cumsum(p) - p / 2) / sum(p)
fit <- stats::lm(t4$count / p ~ r, weights = p)
sii_manual <- unname(stats::coef(fit)[2L])
sii <- ineq_sii(t4, per = 1)
ok("SII 与加权回归斜率一致", abs(sii$sii - sii_manual) < 1e-12)
ok("SII 方向为负", sii$sii < 0)
ok("SII 返回标准误与 p 值", is.finite(sii$se) && is.finite(sii$p_value))
ok("SII 的 R² 在 0–1", sii$r_squared >= 0 && sii$r_squared <= 1)
ok("少于 3 地区报错", catch_err(ineq_sii(t4[1:2, ])))

cat("\n== 分组与分解 ==\n")
g <- ineq_groups(t4, cut = 0.5)
ok("cut 分出两组", nrow(g) == 2L)
ok("人口份额和为 1", abs(sum(g$pop_share) - 1) < 1e-12)
ok("病例份额和为 1", abs(sum(g$count_share) - 1) < 1e-12)
ok("率/十万人与率一致", max(abs(g$rate_per_100k - g$rate * 1e5)) < 1e-9)
g4 <- ineq_groups(d, groups = 4L)
ok("分位数分为四组", nrow(g4) == 4L)
ok("分位组名 Q1–Q4", identical(g4$group, c("Q1", "Q2", "Q3", "Q4")))
ok("median 分组为两组", nrow(ineq_groups(d, cut = "median")) == 2L)
ok("cut 与 groups 冲突报错", catch_err(ineq_groups(d, cut = 0.7, groups = 4L)))
ok("groups 越界报错", catch_err(ineq_groups(d, groups = 11L)))
dec <- x$decompose
ok("分解恒等式成立",
   abs(dec$total - (dec$between + dec$within + dec$residual)) < 1e-9)
ok("分解余量接近 0", abs(dec$residual) < 1e-6)
ok("分解表与 groups 同步", identical(dec$groups, x$groups))
ok("分解 weights 非负", all(dec$weights >= 0))
ok("组间占比在 0–1", x$core$between_share >= 0 && x$core$between_share <= 1)

cat("\n== 可达性 ==\n")
acc <- x$access
ok("自动设施数为 3", nrow(acc$facilities) == 3L)
ok("设施按人口降序", identical(acc$facilities$name,
   x$tot$region[order(-x$tot$population)][1:3]))
ok("可达性非负", all(acc$regions$access >= 0))
ok("总体可达性为正", acc$overall > 0)
ok("人口加权总体可复算",
   abs(acc$overall - stats::weighted.mean(acc$regions$access, acc$regions$population)) < 1e-10)
t4xy <- t4
t4xy$x <- c(1, 2, 3, 4)
t4xy$y <- c(1, 1, 2, 2)
one <- ineq_access(t4xy, facilities = data.frame(name = "F1", x = 0, y = 0),
                   d0 = 1, beta = 1)
d_manual <- sqrt(t4xy$x^2 + t4xy$y^2)
ok("单设施距离衰减手算一致",
   max(abs(one$regions$access - 1 / (1 + d_manual))) < 1e-12)
ok("d0 = 1 生效", one$d0 == 1)
ok("beta 必须为正", catch_err(ineq_access(t4xy, d0 = 1, beta = 0)))
ok("无坐标报错", catch_err(ineq_access(t4[, c("region", "ses", "population", "count")])))
d_no_xy <- d[, c("date", "region", "count", "population", "disease", "ses")]
x_no_xy <- ineq_counts(d_no_xy)
ok("无坐标时主流程仍给结果", is.finite(x_no_xy$ci) && is.null(x_no_xy$access))

cat("\n== Gini ==\n")
ok("常数率 Gini 为 0", {
  flat <- t4; flat$count <- flat$population * 0.01
  abs(ineq_gini(flat)) < 1e-12
})
ok("Gini 随集中上升", ineq_gini(t4) > 0)

cat("\n== 输出三出口 ==\n")
out <- tempfile(tmpdir = tempdir())
cap <- capture.output(ineq_report(x, "console"))
ok("控制台含 CI", any(grepl("集中指数 CI", cap, fixed = TRUE)))
fcsv <- file.path(out, "summary.csv")
dir.create(out, showWarnings = FALSE, recursive = TRUE)
ineq_report(x, "csv", file = fcsv)
ok("CSV 写三张表", all(file.exists(c(fcsv, sub("\\.csv$", "_groups.csv", fcsv),
                                     sub("\\.csv$", "_curve.csv", fcsv)))))
fhtml <- file.path(out, "report.html")
ineq_report(x, "html", fhtml)
h <- paste(readLines(fhtml, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
ok("HTML 含集中曲线 SVG", grepl("<svg", h, fixed = TRUE))
ok("HTML 单文件无外部依赖", !grepl("<script|<link", h))
ok("HTML 含关键指标", grepl("斜率不平等指数", h, fixed = TRUE))
ok("HTML 记录版本", grepl("epiIneq v", h, fixed = TRUE))
ok("错误格式报错", catch_err(ineq_report(x, "html", tempfile(fileext = ".pdf"))))

cat("\n== 方法表与错误输入 ==\n")
mm <- ineq_methods()
ok("方法表五行", nrow(mm) == 5L)
ok("方法表含五列方法", all(c("concentration", "sii", "decompose", "access", "gini") %in% mm$method))
ok("缺 count 列报错", catch_err(ineq_counts(d[, setdiff(names(d), "count")])))
dbad <- d; dbad$count[1] <- -1
ok("负计数报错", catch_err(ineq_counts(dbad)))
dnoses <- d[, setdiff(names(d), c("ses", "x", "y"))]
ok("无 SES 报错", catch_err(ineq_counts(dnoses)))
ok("非契约对象报错", catch_err(ineq_counts(1:10)))
ok("print 方法不报错", !catch_err({ print(x); invisible(NULL) }))

cat(sprintf("\nepiIneq %d 项断言：%d PASS / %d FAIL\n", pass + fail, pass, fail))
if (fail > 0L) quit(status = 1L)
