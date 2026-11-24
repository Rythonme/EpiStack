# =============================================================
# epiRobust 演示：36 个虚构地区，一键体检并输出单文件 HTML 报告
# 用法：在仓库根目录执行  Rscript robust_demo/run_robust.R
# 原始监测数据不入库；本脚本只用内置合成数据。
# =============================================================

library(epiRobust)

d <- robust_example(n_side = 6L, years = 2022:2024)
cat(sprintf("合成数据：%d 行 ｜ %d 个虚构地区\n", nrow(d), length(unique(d$region))))

res <- robust_check(
  d,
  scales = c(1L, 2L, 3L),
  styles = c("rook", "queen", "knn"),
  cutoffs = c(1.5, 2, 3, 6),
  n_perm = 199L,
  seed = 20261124L
)

print(res)
cat("\n--- MAUP ---\n")
print(res$maup)
cat("\n--- 权重 ---\n")
print(res$weights)
cat("\n--- Conley ---\n")
print(res$conley)
cat("\n--- 多重比较 ---\n")
print(res$multiplicity)

out <- file.path("robust_demo", "output", "robust-report.html")
dir.create(dirname(out), showWarnings = FALSE, recursive = TRUE)
robust_report(res, out)
cat(sprintf("\n报告已生成：%s\n", out))
