# =============================================================
# epiSpace 单元测试（base R，零第三方依赖）
# 运行：Rscript tests/test_epi_space.R
#
# 重点：权重校验、Moran 与 LISA 的手算一致、置换可复现、
#       热点只在显著时标注、三种输出出口、BYM2 模板不碰 INLA。
# =============================================================
a <- commandArgs(trailingOnly = FALSE)
f <- sub("^--file=", "", a[grep("^--file=", a)])
here <- if (length(f)) dirname(normalizePath(f[1L])) else getwd()
pkg_dir <- normalizePath(file.path(here, ".."))

if (requireNamespace("epiSpace", quietly = TRUE)) {
  suppressPackageStartupMessages(library(epiSpace))
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

cat("== 示例数据与权重 ==\n")
d <- space_example()
ok("示例 16 地区 × 3 年", length(unique(d$region)) == 16L &&
     length(unique(d$date)) == 3L)
ok("示例确定性", identical(space_example(), d))
W <- space_weights(d, "rook")
ok("权重类正确", inherits(W, "epi_space_weights"))
ok("16×16", nrow(W$W) == 16L && ncol(W$W) == 16L)
ok("行标准化", all(abs(rowSums(W$W) - 1) < 1e-10))
ok("对角线为 0", all(diag(W$W) == 0))
ok("邻接结构对称", isTRUE(all.equal((W$W > 0), t(W$W > 0), check.attributes = FALSE)))
ok("地区名来自格网", identical(rownames(W$W), sprintf("R%02d", 1:16)))
Wq <- space_weights(d, "queen")
ok("queen 邻接不少于 rook", Wq$density > W$density)
ok("邻接表行数", nrow(space_neighbors(W)) == 16L)
ok("角点邻居数为 2", space_neighbors(W)$n_neighbors[1L] == 2L)
m0 <- matrix(0, 3L, 3L, dimnames = list(c("a", "b", "c"), c("a", "b", "c")))
ok("孤立地区报错", catch_err(space_weights(m0)))
ok("非方阵报错", catch_err(space_weights(matrix(0, 2L, 3L))))
ok("非法类型报错", catch_err(space_weights(1:10)))
ok("结构不对称报错", catch_err(space_weights(matrix(c(0,1,0,0,0,0,0,0,0), 3L, 3L,
     dimnames = list(c("a","b","c"), c("a","b","c"))))))

cat("== 全局 Moran ==\n")
v <- tapply(d$count, d$region, sum)
z <- as.numeric(v) - mean(v)
I_manual <- (length(z) / sum(W$W)) * sum(W$W * outer(z, z)) / sum(z^2)
m1 <- space_moran(v, W = W$W, n_perm = 999L, seed = 4242L)
ok("手算一致", abs(m1$I - I_manual) < 1e-12, sprintf("包 %.10f 手算 %.10f", m1$I, I_manual))
ok("置换 p 在合法范围", m1$p >= 0.001 && m1$p <= 1)
ok("置换次数记录正确", m1$n_perm == 999L)
m2 <- space_moran(v, W = W$W, n_perm = 999L, seed = 4242L)
ok("同种子可复现", identical(m1$I, m2$I) && identical(m1$p, m2$p))
m3 <- space_moran(v, W = W$W, n_perm = 999L, seed = 7L)
ok("不同种子置换序列不同", !identical(m1$I_null, m3$I_null))
m0p <- space_moran(v, W = W$W, n_perm = 0L)
ok("不置换则 p 为 NA", is.na(m0p$p) && length(m0p$I_null) == 0L)
ok("greater 与双侧不同实现", space_moran(v, W$W, n_perm = 9L, seed = 1L,
                                          alternative = "greater")$alternative == "greater")
ok("常量序列报错", catch_err(space_moran(rep(1, 16L), W = W$W)))
ok("长度不匹配报错", catch_err(space_moran(1:5, W = W$W)))
ok("缺权重报错", catch_err(space_moran(v)))
ok("RNG 状态不被无种子调用污染", {
  set.seed(99); a <- runif(1)
  set.seed(99); invisible(space_moran(v, W$W, n_perm = 5L)); b <- runif(1)
  !identical(a, b)
})

cat("== 局部 LISA 与热点 ==\n")
li <- space_lisa(v, W = W$W, n_perm = 999L, seed = 4242L)
ok("逐地区 16 行", nrow(li$table) == 16L)
ok("四象限合法", all(li$table$quadrant %in% c("HH", "LL", "HL", "LH")))
ok("局部 p 范围", all(li$table$p_i >= 0.001 & li$table$p_i <= 1))
ok("局部 I 不为 NA", all(is.finite(li$table$I_i)))
ok("空间滞后按权重计算", max(abs(li$table$spatial_lag - as.vector(W$W %*% (v - mean(v))))) < 1e-10)
li2 <- space_lisa(v, W = W$W, n_perm = 999L, seed = 4242L)
ok("同种子表一致", identical(li$table, li2$table))
hs <- space_hotspot(li)
ok("热点只在 HH", all(hs$category[hs$quadrant != "HH"] != "热点"))
ok("冷点只在 LL", all(hs$category[hs$quadrant != "LL"] != "冷点"))
ok("注入的角落是热点", "R16" %in% hs$region[hs$category == "热点"],
   paste(hs$region[hs$category == "热点"], collapse = ","))
ok("显著性标记一致", all(hs$significant == (hs$p_i < 0.05)))
ok("更严格 alpha 不增加热点",
   sum(space_hotspot(li, 0.01)$category == "热点") <= sum(hs$category == "热点"))
ok("非法 alpha 报错", catch_err(space_hotspot(li, 1.2)))
ok("非法 lisa 报错", catch_err(space_hotspot(data.frame(x = 1))))

cat("== 一站式入口 ==\n")
x <- space_counts(d, W = W, seed = 4242L)
ok("结果类正确", inherits(x, "epi_space"))
ok("全局与单独调用一致", abs(x$global$I - m1$I) < 1e-12)
ok("值按 W 顺序对齐", identical(x$values$region, rownames(W$W)))
ok("摘要 9 行", nrow(x$summary) == 9L)
ok("热点计数与明细一致",
   as.integer(x$summary$value[x$summary$metric == "hotspots"]) == sum(x$hotspots$category == "热点"))
ok("设置回写正确", x$settings$n_perm == 999L && x$settings$alpha == 0.05)
x2 <- space_counts(list(data = d, W = W$W), seed = 4242L)
ok("契约 list 入口可用", x2$meta$n_regions == 16L)
x3 <- space_counts(d, W = W, value = "count", seed = 4242L)
ok("指定 value 列可用", identical(x3$settings$value, "count"))
ok("无权重报错", catch_err(space_counts(d[, c("region", "count")])))
ok("缺列报错", catch_err(space_counts(data.frame(region = "a"))))
ok("坏年份报错", catch_err(space_counts(d, W = W, year_value = 1999L)))

cat("== 输出出口 ==\n")
f_html <- tempfile(fileext = ".html")
space_report(x, f_html)
html <- paste(readLines(f_html, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
ok("HTML 已生成", file.exists(f_html) && file.info(f_html)$size > 2000)
ok("HTML 单文件无外链", !grepl("<script|<link|https?://", html))
ok("HTML 含方法与结论", grepl("Moran", html) && grepl("热点", html))
ok("HTML 含地区名", grepl("R16", html))
f_csv <- tempfile(fileext = ".csv")
space_report(x, f_csv, format = "csv")
ok("CSV 信号表已生成", file.exists(f_csv) && nrow(read.csv(f_csv)) == 16L)
ok("CSV 摘要已生成", file.exists(sub("\\.csv$", "_summary.csv", f_csv)))
con_out <- capture.output(space_report(x))
ok("控制台输出有统计量", any(grepl("Moran", con_out)))
ok("CSV 无文件路径报错", catch_err(space_report(x, format = "csv")))
ok("非法 format 报错", catch_err(space_report(x, file = tempfile(), format = "pdf")))

cat("== BYM2 模板与方法表 ==\n")
tpl <- space_bym2_template(d, W = W)
ok("模板数据 16 行", nrow(tpl$data) == 16L)
ok("模板含 BYM2 公式", grepl("bym2", tpl$code, fixed = TRUE))
ok("模板含 offset", grepl("E = d\\$pop", tpl$code))
ok("模板给邻接图代码", grepl("nb2INLA", tpl$graph_code))
ok("清单完整", length(tpl$checklist) >= 4L)
ok("不创建图文件", !file.exists(tpl$graph_file))
ok("方法表 4 行", nrow(space_methods()) == 4L)
ok("方法名完整", identical(space_methods()$method, c("moran", "lisa", "hotspot", "bym2")))

cat(sprintf("\n结论：%d PASS / %d FAIL\n", pass, fail))
if (fail > 0L) quit(status = 1L, save = "no")
