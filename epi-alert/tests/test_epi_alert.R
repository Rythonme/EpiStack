# =============================================================
# epiAlert 单元测试（base R，零第三方依赖）
# 运行：Rscript tests/test_epi_alert.R
#
# 全部夹具现场生成（alert_example() 与临时文件），仓库里不放二进制数据。
# 重点验证三件事：口径可复现、分级规则与配置一致、输出能被下游直接吃。
# =============================================================
a <- commandArgs(trailingOnly = FALSE)
f <- sub("^--file=", "", a[grep("^--file=", a)])
here <- if (length(f)) dirname(normalizePath(f[1L])) else getwd()
pkg_dir <- normalizePath(file.path(here, ".."))

if (requireNamespace("epiAlert", quietly = TRUE)) {
  suppressPackageStartupMessages(library(epiAlert))
} else {
  for (ff in list.files(file.path(pkg_dir, "R"), pattern = "\\.R$", full.names = TRUE))
    source(ff, encoding = "UTF-8")
}
options(encoding = "UTF-8")

.j <- function(nm) {
  if (exists(nm, mode = "function")) get(nm, mode = "function") else
    get(nm, envir = asNamespace("epiAlert"))
}
alert_period <- .j(".alert_period")
alert_prepare <- .j(".alert_prepare")

pass <- 0L; fail <- 0L
ok <- function(label, cond, extra = "") {
  extra <- if (length(extra)) paste(as.character(extra), collapse = " ") else ""
  if (isTRUE(cond)) { pass <<- pass + 1L; cat(sprintf("  OK   %s\n", label)) }
  else { fail <<- fail + 1L; cat(sprintf("  FAIL %s | %s\n", label, extra)) }
}
section <- function(x) cat(sprintf("\n== %s ==\n", x))

td <- file.path(tempdir(), "epi_alert_test")
unlink(td, recursive = TRUE)
dir.create(td, recursive = TRUE, showWarnings = FALSE)

# ---------------- 1 · 示例数据 ----------------
section("1. 示例数据")
d <- alert_example()
ok("行数 = 地区 × 年 × 周", nrow(d) == 4L * 3L * 52L, nrow(d))
ok("列名符合契约", all(c("date", "region", "count", "population", "disease") %in% names(d)))
ok("无缺失", !any(is.na(d$date)) && !any(is.na(d$count)))
ok("计数为非负整数", all(d$count >= 0) && all(d$count == round(d$count)))
ok("两次调用完全一致（确定性）", identical(d, alert_example()))
ok("默认注入地区在末段升高",
   mean(d$count[d$region == "D 区" & d$date >= as.Date("2024-11-01")]) >
     mean(d$count[d$region == "D 区" & d$date < as.Date("2024-11-01")]) * 1.5)

# ---------------- 2 · 分级规则 ----------------
section("2. 分级规则")
r <- alert_default_rules()
ok("默认规则类名", inherits(r, "epi_alert_rules"))
ok("默认阈值", r$watch == 1 && r$warn_run == 2 && r$alarm_run == 3 &&
                 r$warn_ratio == 1.5 && r$alarm_ratio == 2)
ok("四级标签", identical(r$labels, c("正常", "关注", "预警", "告警")))
ok("watch 非正数报错", inherits(try(alert_rules(watch = 0), silent = TRUE), "try-error"))
ok("warn_run < watch 报错",
   inherits(try(alert_rules(watch = 2, warn_run = 1), silent = TRUE), "try-error"))
ok("alarm_ratio < warn_ratio 报错",
   inherits(try(alert_rules(warn_ratio = 2, alarm_ratio = 1.5), silent = TRUE), "try-error"))
ok("标签数量不对报错",
   inherits(try(alert_rules(labels = c("正常", "告警")), silent = TRUE), "try-error"))
ok("print 不报错", is.character(capture.output(print(r))))

p <- file.path(td, "rules.json")
alert_rules_write(r, p)
ok("规则写入 JSON", file.exists(p))
r2 <- alert_rules_read(p)
ok("JSON 往返后阈值一致",
   identical(c(r2$watch, r2$warn_run, r2$warn_ratio, r2$alarm_run, r2$alarm_ratio),
             c(r$watch, r$warn_run, r$warn_ratio, r$alarm_run, r$alarm_ratio)))
ok("JSON 往返后标签一致", identical(r2$labels, r$labels))
ok("读不存在的规则文件报错",
   inherits(try(alert_rules_read(file.path(td, "nope.json")), silent = TRUE), "try-error"))
ok("包内默认规则与代码默认一致",
   {
     rf <- system.file("rules", "alert_default.json", package = "epiAlert")
     if (!nzchar(rf)) rf <- file.path(pkg_dir, "inst", "rules", "alert_default.json")
     file.exists(rf) && identical(alert_rules_read(rf)$warn_ratio, r$warn_ratio)
   })
ok("方法表四种方法", nrow(alert_methods()) == 4L &&
     setequal(alert_methods()$method, c("seasonal", "pooled", "moving", "poisson")))

# ---------------- 3 · 周期映射与粒度 ----------------
section("3. 周期映射")
dd <- as.Date(c("2024-01-01", "2024-07-01", "2024-12-30"))
ok("周周期落在 1..52", all(alert_period(dd, "week", 52L) %in% 1:52))
ok("月周期 = 自然月", identical(alert_period(dd, "month", 12L), c(1L, 7L, 12L)))
ok("季度周期", identical(alert_period(dd, "quarter", 4L), c(1L, 3L, 4L)))
ok("年度周期恒为 1", all(alert_period(dd, "year", 1L) == 1L))
if (requireNamespace("epiCore", quietly = TRUE)) {
  ok("与 epiCore::epi_period 同口径（周）",
     identical(alert_period(dd, "week", 52L), epiCore::epi_period(dd, 52L, "week")))
  ok("与 epiCore::epi_period 同口径（月）",
     identical(alert_period(dd, "month", 12L), epiCore::epi_period(dd, 12L, "month")))
}

# ---------------- 4 · 基线带 ----------------
section("4. 基线带")
b <- alert_baseline(d, assess = "all")
ok("每期一行", nrow(b) == nrow(d))
ok("列结构", all(c("region", "period", "cycle", "date", "baseline", "upper",
                   "n_hist", "method") %in% names(b)))
ok("首年没有基线（无更早历史）", all(is.na(b$upper[b$cycle == 2022])))
ok("后续年份有基线", sum(!is.na(b$upper[b$cycle > 2022])) > 300L)
ok("上界不低于基线", all(b$upper >= b$baseline - 1e-9, na.rm = TRUE))
ok("最小历史观测数被遵守", all(b$n_hist[!is.na(b$upper)] >= 3L))
ok("自动方法：周数据走 seasonal", all(b$method == "seasonal"))

# 手算核对：2024 年第 1 期，只用 2022、2023 年的第 52/1/2 期
# 52 期覆盖 364 天，年初会有一期跨两个日期，取第一条即可
i <- which(b$region == "A 区" & b$cycle == 2024L & b$period == 1L)[1L]
hist_rows <- d[d$region == "A 区" & d$date < d$date[i], ]
per <- alert_period(hist_rows$date, "week", 52L)
z <- hist_rows$count[per %in% c(52L, 1L, 2L)]
lz <- log(z + 0.5)
ok("基线 = exp(mean(log)) - 0.5", abs(b$baseline[i] - (exp(mean(lz)) - 0.5)) < 1e-9)
ok("上界 = exp(mean + 1.645 * sd) - 0.5",
   abs(b$upper[i] - (exp(mean(lz) + 1.645 * stats::sd(lz)) - 0.5)) < 1e-9)
ok("历史样本数正确", b$n_hist[i] == length(z), b$n_hist[i])

# 同年内相邻期不进入基线（否则本期暴发会污染自己的上界）
ok("同年内其它期不参与基线（无自我污染）",
   all(b$n_hist[which(b$region == "D 区" & b$cycle == 2024L)] <= 9L))

bp <- alert_baseline(d, method = "pooled", assess = "latest")
ok("pooled 方法可用且有上界", all(!is.na(bp$upper)))
ok("pooled 方法标注正确", all(bp$method == "pooled"))
bm <- alert_baseline(d, method = "moving", window = 8L)
ok("moving 方法可用且历史数不超过 window",
   all(bm$n_hist[!is.na(bm$upper)] <= 8L))
bq <- alert_baseline(d, method = "poisson", assess = "latest")
ok("poisson 方法上界为整数计数", all(bq$upper == round(bq$upper), na.rm = TRUE))
ok("assess 只评最新年",
   all(alert_baseline(d, assess = "latest")$cycle == 2024L))
ok("assess 指定年份",
   setequal(unique(alert_baseline(d, assess = 2023L)$cycle), 2023L))
ok("assess 非法值报错",
   inherits(try(alert_baseline(d, assess = "yesterday"), silent = TRUE), "try-error"))

# ---------------- 5 · 扫描与分级 ----------------
section("5. 扫描与分级")
s <- alert_scan(d)
ok("返回类名", inherits(s, "epi_scan"))
ok("current 与基线同长", nrow(s$current) == nrow(d))
ok("level 取值合法", all(s$current$level %in% s$settings$rules$labels))
ok("alerts 只含非正常行", all(s$alerts$level != "正常"))
ok("alerts 与 current 的异常行数一致",
   nrow(s$alerts) == sum(s$current$level != "正常"))
ok("alerts 列可直接落盘", all(c("date", "region", "count", "upper", "run_len",
                                "level") %in% names(s$alerts)))
ok("没有基线时不给级别", all(s$current$level[is.na(s$current$upper)] == "正常"))
ok("预警行满足连续期数或倍数条件",
   all(s$current$run_len[s$current$level == "预警"] >= s$settings$rules$warn_run |
       s$current$ratio[s$current$level == "预警"] >= s$settings$rules$warn_ratio))
ok("连续超限段内 run_len 相同",
   {
     hit <- which(s$current$region == "D 区" & s$current$cycle == 2024L)
     tail_run <- utils::tail(s$current$run_len[hit], 6L)
     length(unique(tail_run)) == 1L && tail_run[1L] >= 3L
   })
ok("注入暴发判为告警",
   any(s$current$level[s$current$region == "D 区" & s$current$cycle == 2024L] == "告警"))
ok("同期其它地区不误报为告警",
   !any(s$current$level[s$current$region != "D 区"] == "告警"))
ok("确定性：两次扫描一致", identical(alert_scan(d)$current, s$current))
ok("print 不报错", is.character(capture.output(print(s))))

# 年度数据：连续期数不累计（只有两年历史，min_obs 放宽到 2）
dy <- d[format(d$date, "%m-%d") == "01-01", ]
sy <- alert_scan(dy, time_step = "year", min_obs = 2L)
ok("年度数据 run_len 不超过 1", all(sy$current$run_len <= 1L))
ok("年度数据自动改用 pooled 基线", all(sy$band$method == "pooled"))
dy2 <- dy
ix2 <- dy2$region == "D 区" & format(dy2$date, "%Y") == "2024"
dy2$count[ix2] <- dy2$count[ix2] * 3
sy2 <- alert_scan(dy2, time_step = "year", min_obs = 2L)
ok("年度数据按超出倍数分级",
   any(sy2$current$level[sy2$current$region == "D 区" &
                         sy2$current$cycle == 2024L] == "告警"))

# 更严的阈值会把信号数压下来
strict <- alert_rules(warn_ratio = 3, alarm_ratio = 4, warn_run = 5, alarm_run = 6)
s2 <- alert_scan(d, rules = strict)
ok("收紧阈值后告警数不增加",
   sum(s2$current$level == "告警") <= sum(s$current$level == "告警"))
ok("收紧阈值后预警数不增加",
   sum(s2$current$level == "预警") <= sum(s$current$level == "预警"))

# ---------------- 6 · 汇总与报告 ----------------
section("6. 汇总与报告")
x <- alert_counts(d)
ok("入口类名", inherits(x, "epi_alert"))
ok("汇总每地区一行", nrow(x$summary) == length(unique(d$region)))
ok("汇总列结构", all(c("region", "n_periods", "n_exceed", "n_alarm",
                       "peak_level", "max_ratio") %in% names(x$summary)))
ok("汇总额等于明细",
   sum(x$summary$n_periods) == nrow(x$current) &&
     sum(x$summary$n_alarm) == sum(x$current$level == "告警"))
ok("最高级别按严重度排序", x$summary$peak_level[1L] == "告警")
ok("alert_summary() 与入口结果一致", identical(alert_summary(x), x$summary))
ok("入口 meta 记录规模", x$meta$n_targets == nrow(d) && x$meta$n_regions == 4L)
ok("print 不报错", is.character(capture.output(print(x))))

con_out <- capture.output(alert_report(x))
ok("console 报告含标题", any(grepl("预警单", con_out)))
csvp <- file.path(td, "alerts.csv")
alert_report(x, csvp, format = "csv")
ok("CSV 信号清单落盘", file.exists(csvp))
ok("CSV 地区汇总落盘", file.exists(file.path(td, "alerts_regions.csv")))
back <- utils::read.csv(csvp, fileEncoding = "UTF-8", stringsAsFactors = FALSE)
ok("CSV 行数一致", nrow(back) == nrow(x$alerts))
ok("CSV 含级别列", "level" %in% names(back))

htmlp <- file.path(td, "alert.html")
alert_report(x, htmlp)
h <- paste(readLines(htmlp, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
ok("HTML 落盘", file.exists(htmlp))
ok("HTML 单文件（无外部依赖）", !grepl("<script|<link", h))
ok("HTML 含分级与方法段", grepl("按地区汇总", h) && grepl("方法与参数", h))

# 地区名里的尖括号必须转义，否则报告结构会被数据破坏
dx <- d
dx$region[dx$region == "A 区"] <- "A<b>区"
hx <- file.path(td, "esc.html")
alert_report(alert_counts(dx), hx)
h2 <- paste(readLines(hx, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
ok("HTML 对数据做转义", grepl("A&lt;b&gt;区", h2) && !grepl("A<b>区", h2))

# ---------------- 7 · 输入校验 ----------------
section("7. 输入校验")
ok("缺列报错",
   inherits(try(alert_counts(data.frame(date = Sys.Date(), x = 1)), silent = TRUE),
            "try-error"))
bad <- d; bad$count[1L] <- NA
ok("计数缺失报错", inherits(try(alert_counts(bad), silent = TRUE), "try-error"))
bad2 <- d; bad2$date[1L] <- NA
ok("日期缺失报错", inherits(try(alert_counts(bad2), silent = TRUE), "try-error"))
ok("窗口参数非法报错",
   inherits(try(alert_baseline(d, window = 0), silent = TRUE), "try-error"))
ok("min_obs 非法报错",
   inherits(try(alert_baseline(d, min_obs = 1), silent = TRUE), "try-error"))
ok("k 非法报错", inherits(try(alert_baseline(d, k = -1), silent = TRUE), "try-error"))
ok("传入非契约对象报错",
   inherits(try(alert_counts(list(a = 1)), silent = TRUE), "try-error"))

cat(sprintf("\n结论：%d PASS / %d FAIL\n", pass, fail))
if (fail > 0L) quit(status = 1L)
