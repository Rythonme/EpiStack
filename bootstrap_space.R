# =============================================================
# EpiStack · epiSpace 加载引导
# 与 bootstrap_core.R / bootstrap_ingest.R / bootstrap_alert.R 同一套路：
# 优先用已安装的正式包，装不上（断网 / 无构建工具）就回退为 source R/ 源码。
# =============================================================

epi_bootstrap_space <- function(pkg_dir = file.path(epi_project_root(), "epi-space"),
                                verbose = TRUE) {
  lib_dir <- file.path(dirname(pkg_dir), ".rlib")
  if (!dir.exists(lib_dir)) dir.create(lib_dir, recursive = TRUE, showWarnings = FALSE)
  .libPaths(c(normalizePath(lib_dir), .libPaths()))

  # 开发期注意：.rlib 里的旧拷贝会遮蔽源码改动，源码更新则先清掉重装
  inst_desc <- file.path(lib_dir, "epiSpace", "DESCRIPTION")
  if (file.exists(inst_desc)) {
    src_files <- c(file.path(pkg_dir, "DESCRIPTION"),
                   list.files(file.path(pkg_dir, "R"), pattern = "\\.R$", full.names = TRUE))
    if (file.mtime(inst_desc) < max(file.mtime(src_files)))
      unlink(file.path(lib_dir, "epiSpace"), recursive = TRUE, force = TRUE)
  }

  mode <- "source"
  if (requireNamespace("epiSpace", quietly = TRUE)) {
    library(epiSpace)
    mode <- "installed"
  } else {
    ok <- tryCatch({
      suppressMessages(suppressWarnings(
        utils::install.packages(pkg_dir, repos = NULL, type = "source",
                                lib = lib_dir, quiet = TRUE)
      ))
      TRUE
    }, error = function(e) FALSE, warning = function(w) FALSE)
    if (ok && requireNamespace("epiSpace", quietly = TRUE)) {
      library(epiSpace)
      mode <- "installed"
    }
  }

  if (mode == "source") {
    files <- c("utils.R", "weights.R", "moran.R", "lisa.R", "hotspot.R",
               "summary.R", "report.R", "space_counts.R", "bym2.R", "example.R")
    for (f in files) source(file.path(pkg_dir, "R", f), encoding = "UTF-8")
  }
  if (isTRUE(verbose))
    cat(sprintf("[epi-space] 加载方式: %s\n", mode))
  invisible(mode)
}
