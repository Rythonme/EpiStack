# =============================================================
# EpiStack · epiAlert 加载引导
# 与 bootstrap_core.R / bootstrap_ingest.R 同一套路：优先用已安装的正式包，
# 装不上（断网 / 无构建工具）就回退为 source R/ 源码，函数完全一致。
# =============================================================

epi_bootstrap_alert <- function(pkg_dir = file.path(epi_project_root(), "epi-alert"),
                                verbose = TRUE) {
  lib_dir <- file.path(dirname(pkg_dir), ".rlib")
  if (!dir.exists(lib_dir)) dir.create(lib_dir, recursive = TRUE, showWarnings = FALSE)
  .libPaths(c(normalizePath(lib_dir), .libPaths()))

  # 开发期注意：.rlib 里的旧拷贝会遮蔽源码改动，源码更新则先清掉重装
  inst_desc <- file.path(lib_dir, "epiAlert", "DESCRIPTION")
  if (file.exists(inst_desc)) {
    src_files <- c(file.path(pkg_dir, "DESCRIPTION"),
                   list.files(file.path(pkg_dir, "R"), pattern = "\\.R$", full.names = TRUE))
    if (file.mtime(inst_desc) < max(file.mtime(src_files)))
      unlink(file.path(lib_dir, "epiAlert"), recursive = TRUE, force = TRUE)
  }

  mode <- "source"
  if (requireNamespace("epiAlert", quietly = TRUE)) {
    library(epiAlert)
    mode <- "installed"
  } else {
    ok <- tryCatch({
      suppressMessages(suppressWarnings(
        utils::install.packages(pkg_dir, repos = NULL, type = "source",
                                lib = lib_dir, quiet = TRUE)
      ))
      TRUE
    }, error = function(e) FALSE, warning = function(w) FALSE)
    if (ok && requireNamespace("epiAlert", quietly = TRUE)) {
      library(epiAlert)
      mode <- "installed"
    }
  }

  if (mode == "source") {
    files <- c("utils.R", "json.R", "rules.R", "baseline.R", "scan.R",
               "summary.R", "report.R", "alert_counts.R", "example.R")
    for (f in files) source(file.path(pkg_dir, "R", f), encoding = "UTF-8")
    options(epiAlert.rules_dir = file.path(pkg_dir, "inst", "rules"))
  }
  if (isTRUE(verbose))
    cat(sprintf("[epi-alert] 加载方式: %s\n", mode))
  invisible(mode)
}
