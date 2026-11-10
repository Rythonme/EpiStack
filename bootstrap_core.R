# =============================================================
# EpiStack · epiCore 加载引导
# 优先使用已安装（或现场安装到项目内 .rlib/）的正式 R 包；
# 安装不可用（断网 / 无构建工具）时回退为按依赖顺序 source R/ 源码。
# 两条路径暴露完全相同的函数，保证「clone 下来一条命令就能跑」。
# =============================================================

epi_bootstrap_core <- function(pkg_dir, verbose = TRUE) {
  lib_dir <- file.path(dirname(pkg_dir), ".rlib")
  if (!dir.exists(lib_dir)) dir.create(lib_dir, recursive = TRUE, showWarnings = FALSE)
  .libPaths(c(normalizePath(lib_dir), .libPaths()))

  mode <- "source"
  if (requireNamespace("epiCore", quietly = TRUE)) {
    library(epiCore)
    mode <- "installed"
  } else {
    ok <- tryCatch({
      suppressMessages(suppressWarnings(
        utils::install.packages(pkg_dir, repos = NULL, type = "source",
                                lib = lib_dir, quiet = TRUE)
      ))
      TRUE
    }, error = function(e) FALSE, warning = function(w) FALSE)
    if (ok && requireNamespace("epiCore", quietly = TRUE)) {
      library(epiCore)
      mode <- "installed"
    }
  }

  if (mode == "source") {
    files <- c("contract.R", "region.R", "period.R",
               "adjacency.R", "qc.R", "read_counts.R")
    for (f in files) source(file.path(pkg_dir, "R", f), encoding = "UTF-8")
  }
  if (isTRUE(verbose))
    cat(sprintf("[epi-core] 加载方式: %s ｜ 契约版本 %s\n", mode, EPI_CONTRACT_VERSION))
  invisible(mode)
}

# 由 Rscript 的 --file= 参数推断项目根目录（不依赖运行时工作目录）
epi_project_root <- function() {
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  if (length(f)) dirname(dirname(normalizePath(f[1L]))) else dirname(getwd())
}
