# =============================================================
# epiAlert / rules.R — 分级阈值是数据，不是代码
#
# 报告制度、病种、地区差异决定「几期算暴发」，这些不该写死在包里。
# alert_rules() 产出可序列化的规则集，alert_rules_write() 存 JSON，
# 随项目版本管理；换口径改文件，不改包、不改下游。
# =============================================================

#' 构造预警分级规则
#'
#' @param watch 判为「关注」所需的最少连续超限期数，默认 1
#' @param warn_run 判为「预警」的连续超限期数，默认 2
#' @param warn_ratio 判为「预警」的超出倍数（实测 / 上界），默认 1.5
#' @param alarm_run 判为「告警」的连续超限期数，默认 3
#' @param alarm_ratio 判为「告警」的超出倍数，默认 2
#' @param labels 四级名称，依次为正常、关注、预警、告警
#' @param name 规则集名称，写进报告便于追溯
alert_rules <- function(watch = 1L, warn_run = 2L, warn_ratio = 1.5,
                        alarm_run = 3L, alarm_ratio = 2,
                        labels = c("正常", "关注", "预警", "告警"),
                        name = NULL) {
  num1 <- function(v, nm) {
    v <- as.numeric(unlist(v))[[1L]]
    if (!is.finite(v) || v < 0) .epi_stop("%s 必须是非负有限数", nm)
    v
  }
  watch <- num1(watch, "watch")
  warn_run <- num1(warn_run, "warn_run")
  warn_ratio <- num1(warn_ratio, "warn_ratio")
  alarm_run <- num1(alarm_run, "alarm_run")
  alarm_ratio <- num1(alarm_ratio, "alarm_ratio")
  if (watch < 1) .epi_stop("watch 至少为 1：连续超限 0 期不能算信号")
  if (warn_run < watch) .epi_stop("warn_run 不能小于 watch")
  if (alarm_run < warn_run) .epi_stop("alarm_run 不能小于 warn_run")
  if (alarm_ratio < warn_ratio) .epi_stop("alarm_ratio 不能小于 warn_ratio")
  labels <- as.character(unlist(labels))
  if (length(labels) != 4L || any(!nzchar(labels)))
    .epi_stop("labels 必须是 4 个非空名称（正常 / 关注 / 预警 / 告警）")

  structure(
    list(name = name, watch = watch, warn_run = warn_run, warn_ratio = warn_ratio,
         alarm_run = alarm_run, alarm_ratio = alarm_ratio, labels = labels),
    class = "epi_alert_rules"
  )
}

print.epi_alert_rules <- function(x, ...) {
  cat(sprintf("<epi_alert_rules>%s\n", if (is.null(x$name)) "" else paste0(" ", x$name)))
  cat(sprintf("  %s : 连续 ≥%g 期\n", x$labels[2L], x$watch))
  cat(sprintf("  %s : 连续 ≥%g 期，或超出 %.2f 倍\n",
              x$labels[3L], x$warn_run, x$warn_ratio))
  cat(sprintf("  %s : 连续 ≥%g 期，或超出 %.2f 倍\n",
              x$labels[4L], x$alarm_run, x$alarm_ratio))
  invisible(x)
}

#' 包内默认分级规则
#'
#' 超限 1 期关注；连续 2 期或超 1.5 倍预警；连续 3 期或超 2 倍告警。
alert_default_rules <- function() {
  alert_rules(name = "epiAlert-default")
}

#' 规则集存成 JSON，随项目版本管理
alert_rules_write <- function(rules, path) {
  if (!inherits(rules, "epi_alert_rules"))
    .epi_stop("rules 必须是 alert_rules() 的返回值")
  obj <- list(
    format_version = "1",
    name = rules$name %||% "epiAlert-default",
    watch = rules$watch, warn_run = rules$warn_run, warn_ratio = rules$warn_ratio,
    alarm_run = rules$alarm_run, alarm_ratio = rules$alarm_ratio,
    labels = as.list(rules$labels)
  )
  .epi_json_write(obj, path)
  invisible(path)
}

#' 从 JSON 读回规则集
alert_rules_read <- function(path) {
  if (!file.exists(path)) .epi_stop("规则文件不存在：%s", path)
  obj <- .epi_json_read(path)
  labels <- as.character(unlist(obj$labels %||% character(0)))
  alert_rules(
    watch = as.numeric(unlist(obj$watch %||% 1)),
    warn_run = as.numeric(unlist(obj$warn_run %||% 2)),
    warn_ratio = as.numeric(unlist(obj$warn_ratio %||% 1.5)),
    alarm_run = as.numeric(unlist(obj$alarm_run %||% 3)),
    alarm_ratio = as.numeric(unlist(obj$alarm_ratio %||% 2)),
    labels = if (length(labels) == 4L) labels else c("正常", "关注", "预警", "告警"),
    name = obj$name
  )
}

#' 可用的基线方法及其适用粒度
alert_methods <- function() {
  data.frame(
    method = c("seasonal", "pooled", "moving", "poisson"),
    label = c("季节基线（对数正态）", "合并基线（对数正态）",
              "滑动均值基线", "泊松上分位基线"),
    time_step = c("week / month / quarter", "year", "任意", "week / month / quarter"),
    note = c("同地区同周期 ±window 期的历史计数，在 log(count+offset) 尺度求均值与标准差，回推单侧上界",
             "不分季节，用该地区全部历史计数；年度数据没有周期可分时用它",
             "最近 window 期的算术均值 + k 倍标准差，不区分季节，适合短序列",
             "同一季节窗口的历史均数作 λ，取单侧泊松上分位；小计数时比对数正态稳"),
    stringsAsFactors = FALSE
  )
}
