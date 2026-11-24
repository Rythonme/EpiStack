# =============================================================
# epiRobust / multiplicity.R — 局部检验的多重比较
#
# LISA 对每个地区各做一次置换检验，地区越多假阳性越多；不校正就把
# 噪声点报成热点。这里提供 Bonferroni 与 BH-FDR 两种校正，并报告
# 校正后热点还剩几个、哪些地区发生结论翻转。
# =============================================================

.robust_bh <- function(p) {
  m <- length(p)
  ok <- !is.na(p)
  adj <- rep(NA_real_, m)
  pv <- p[ok]
  o <- order(pv)
  a <- pmin(1, pv[o] * m / seq_along(pv))
  a <- rev(cummin(rev(a)))
  adj[ok] <- a[o]
  adj
}

#' 局部检验的多重比较校正
#'
#' @param lisa_or_p LISA 结果（含 `table$p_i`）、MAUP 结果，或 p 值向量
#' @param method 校正方法：fdr / bonferroni / both
#' @param alpha 显著性水平
#' @return 类 `epi_robust_multiplicity` 的列表，含 table / verdict
#' @export
robust_multiplicity <- function(lisa_or_p,
                                method = c("fdr", "bonferroni", "both"),
                                alpha = 0.05) {
  method <- match.arg(method, c("fdr", "bonferroni", "both"),
                      several.ok = TRUE)
  if (is.numeric(lisa_or_p) && is.null(dim(lisa_or_p))) {
    p <- as.numeric(lisa_or_p)
    tab <- data.frame(region = paste0("V", seq_along(p)), p = p,
                      stringsAsFactors = FALSE)
  } else if (is.data.frame(lisa_or_p) && "p_i" %in% names(lisa_or_p)) {
    tab <- data.frame(region = lisa_or_p$region, p = lisa_or_p$p_i,
                      quadrant = lisa_or_p$quadrant,
                      stringsAsFactors = FALSE)
  } else if (is.list(lisa_or_p) && !is.null(lisa_or_p$table) &&
             "p_i" %in% names(lisa_or_p$table)) {
    tab <- data.frame(region = lisa_or_p$table$region,
                      p = lisa_or_p$table$p_i,
                      quadrant = lisa_or_p$table$quadrant,
                      stringsAsFactors = FALSE)
  } else if (inherits(lisa_or_p, "epi_robust_maup")) {
    d <- lisa_or_p$details[[length(lisa_or_p$details)]]$lisa
    tab <- data.frame(region = d$region, p = d$p_i, quadrant = d$quadrant,
                      stringsAsFactors = FALSE)
  } else {
    .epi_stop("lisa_or_p 必须是 p 值向量、LISA 结果或 MAUP 结果")
  }
  if (!nrow(tab)) .epi_stop("没有可校正的 p 值")
  m <- sum(!is.na(tab$p))
  if (!m) .epi_stop("p 值全为缺失（置换次数可能是 0）")

  methods <- if ("both" %in% method) c("fdr", "bonferroni") else method
  raw_sig <- !is.na(tab$p) & tab$p < alpha
  for (mm in methods) {
    adj <- if (identical(mm, "fdr")) .robust_bh(tab$p) else pmin(1, tab$p * m)
    tab[[paste0(mm, "_p")]] <- adj
    tab[[paste0(mm, "_sig")]] <- !is.na(adj) & adj < alpha
  }
  lost <- sum(raw_sig & !Reduce(`|`, lapply(methods, function(mm)
    tab[[paste0(mm, "_sig")]])))
  if (length(methods) == 1L)
    lost <- sum(raw_sig & !tab[[paste0(methods[1L], "_sig")]])
  verdict <- if (lost > 0L) {
    sprintf("警示：%d 个原始显著地区在校正后失去显著性", lost)
  } else {
    "稳定：校正后显著地区未减少"
  }
  structure(
    list(table = tab, methods = methods, alpha = alpha,
         raw_significant = sum(raw_sig), lost = lost, verdict = verdict),
    class = "epi_robust_multiplicity"
  )
}

#' @export
print.epi_robust_multiplicity <- function(x, ...) {
  cat(sprintf("<epi_robust_multiplicity> %d 地区 ｜ alpha = %.2f\n",
              nrow(x$table), x$alpha))
  cat(sprintf("  原始显著 %d ｜ 校正后丢失 %d ｜ 方法 %s\n",
              x$raw_significant, x$lost, paste(x$methods, collapse = " + ")))
  cat(sprintf("  判定：%s\n", x$verdict))
  invisible(x)
}
