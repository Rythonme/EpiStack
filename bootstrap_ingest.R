# =============================================================
# EpiStack · epiIngest 加载引导
# 与 bootstrap_core.R 同一套路：优先用已安装的正式包，
# 装不上（断网 / 无构建工具）就回退为 source R/ 源码，函数完全一致。
# =============================================================

epi_bootstrap_ingest <- function(pkg_dir = file.path(epi_project_root(), "epi-ingest"),
                                 verbose = TRUE) {
  lib_dir <- file.path(dirname(pkg_dir), ".rlib")
  if (!dir.exists(lib_dir)) dir.create(lib_dir, recursive = TRUE, showWarnings = FALSE)
  .libPaths(c(normalizePath(lib_dir), .libPaths()))

  # 开发期注意：.rlib 里的旧拷贝会遮蔽源码改动，源码更新则先清掉重装
  inst_desc <- file.path(lib_dir, "epiIngest", "DESCRIPTION")
  if (file.exists(inst_desc)) {
    src_files <- c(file.path(pkg_dir, "DESCRIPTION"),
                   list.files(file.path(pkg_dir, "R"), pattern = "\\.R$", full.names = TRUE))
    if (file.mtime(inst_desc) < max(file.mtime(src_files)))
      unlink(file.path(lib_dir, "epiIngest"), recursive = TRUE, force = TRUE)
  }

  mode <- "source"
  if (requireNamespace("epiIngest", quietly = TRUE)) {
    library(epiIngest)
    mode <- "installed"
  } else {
    ok <- tryCatch({
      suppressMessages(suppressWarnings(
        utils::install.packages(pkg_dir, repos = NULL, type = "source",
                                lib = lib_dir, quiet = TRUE)
      ))
      TRUE
    }, error = function(e) FALSE, warning = function(w) FALSE)
    if (ok && requireNamespace("epiIngest", quietly = TRUE)) {
      library(epiIngest)
      mode <- "installed"
    }
  }

  if (mode == "source") {
    files <- c("utils.R", "json.R", "source.R", "adapters.R", "read.R",
               "qc.R", "report.R", "lineage.R", "desensitize.R", "ingest_counts.R")
    for (f in files) source(file.path(pkg_dir, "R", f), encoding = "UTF-8")
    options(epiIngest.rules_dir = file.path(pkg_dir, "inst", "rules"))
  }
  if (isTRUE(verbose))
    cat(sprintf("[epi-ingest] 加载方式: %s\n", mode))
  invisible(mode)
}
