# =============================================================
# epiRobust / robust.R — 一键体检入口
#
# 四项检查一次跑完：MAUP 尺度、邻接定义、空间稳健 SE、多重比较。
# 本层只读不写：不改上游数据，不回写契约，所有结论都带可复现种子。
# =============================================================

#' 空间稳健性一键体检
#'
#' 对同一份空间数据依次做 MAUP 尺度敏感性、邻接定义敏感性、
#' Conley 空间稳健标准误与局部检验多重比较校正，汇总为一份体检结果。
#'
#' @param x 契约表 data.frame，或 epiCore::read_counts() 的返回值
#' @param scales MAUP 聚合倍数向量
#' @param style MAUP 使用的邻接类型
#' @param styles 权重敏感性比较的邻接类型向量
#' @param k kNN 邻居数
#' @param cutoffs Conley 距离截断向量
#' @param design Conley 回归的设计矩阵；缺省为截距
#' @param year_value 取哪一年；默认最新年份
#' @param n_perm 置换次数
#' @param seed 随机种子；非 NULL 时全部检查可复现
#' @param alpha 显著性水平
#' @param method 多重比较校正方法
#' @param region,count,population,year 契约列名
#' @return 类 `epi_robust` 的列表：maup / weights / conley / multiplicity /
#'   verdicts / overall
#' @export
robust_check <- function(x, scales = c(1L, 2L, 3L), style = "rook",
                         styles = c("rook", "queen", "knn"), k = 4L,
                         cutoffs = c(1.5, 2, 3, 6), design = NULL,
                         year_value = NULL, n_perm = 999L, seed = NULL,
                         alpha = 0.05,
                         method = c("fdr", "bonferroni"),
                         region = "region", count = "count",
                         population = "population", year = "year") {
  p <- .robust_prepare(x, region, count, population, year)
  vv <- .robust_values(p, year_value)

  maup <- robust_maup(x, scales = scales, style = style, k = k,
                      year_value = year_value, n_perm = n_perm,
                      seed = seed, alpha = alpha,
                      region = region, count = count,
                      population = population, year = year)
  ws <- robust_weights(x, styles = styles, k = k,
                       year_value = year_value, n_perm = n_perm,
                       seed = seed, region = region, count = count,
                       population = population, year = year)
  cy <- robust_conley(x, cutoffs = cutoffs, design = design,
                      year_value = year_value, region = region,
                      count = count, population = population, year = year)
  lisa0 <- maup$details[["1"]]$lisa
  if (!is.data.frame(lisa0) || !"p_i" %in% names(lisa0))
    .epi_stop("MAUP 原始尺度的 LISA 表缺失，无法做多重比较校正")
  mult <- robust_multiplicity(lisa0, method = method, alpha = alpha)

  verdicts <- c(
    maup = maup$verdict,
    weights = ws$verdict,
    conley = cy$verdict,
    multiplicity = mult$verdict
  )
  flagged <- grepl("翻转|警示|需警惕", verdicts)
  overall <- if (any(flagged)) {
    sprintf("%d / 4 项检查出现结论警示，请在报告与论文中如实报告敏感性",
            sum(flagged))
  } else {
    "4 / 4 项检查结论一致，未发现由分析选择驱动的翻转"
  }
  structure(
    list(maup = maup, weights = ws, conley = cy, multiplicity = mult,
         verdicts = verdicts, overall = overall,
         settings = list(n_perm = n_perm, seed = seed, alpha = alpha,
                         year = vv$year, n_regions = length(vv$values),
                         method = method)),
    class = "epi_robust"
  )
}

#' 体检结论摘要
#'
#' @param x `robust_check()` 的结果
#' @return data.frame(check, verdict)
#' @export
robust_summary <- function(x) {
  if (!inherits(x, "epi_robust"))
    .epi_stop("x 必须是 robust_check() 的结果")
  data.frame(check = names(x$verdicts), verdict = unname(x$verdicts),
             stringsAsFactors = FALSE)
}

#' @export
print.epi_robust <- function(x, ...) {
  cat(sprintf("<epi_robust> %d 地区 ｜ 置换 %d 次 ｜ 种子 %s\n",
              x$settings$n_regions, x$settings$n_perm,
              if (is.null(x$settings$seed)) "未固定" else as.character(x$settings$seed)))
  for (nm in names(x$verdicts))
    cat(sprintf("  %-12s %s\n", nm, x$verdicts[[nm]]))
  cat(sprintf("  总判定：%s\n", x$overall))
  invisible(x)
}
