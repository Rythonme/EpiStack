# =============================================================
# EpiStack · epiIneq 加载引导
# 与其余层同一套路：优先用已安装的正式包，装不上（断网 / 无构建工具）
# 就回退为 source R/ 源码；源码更新时自动清掉 .rlib 里的旧拷贝重装。
# =============================================================

epi_bootstrap_ineq <- function(pkg_dir = file.path(epi_project_root(), "epi-ineq"),
                               verbose = TRUE) {
  lib_dir <- file.path(dirname(pkg_dir), ".rlib")
  if (!dir.exists(lib_dir)) dir.create(lib_dir, recursive = TRUE, showWarnings = FALSE)
  .libPaths(c(normalizePath(lib_dir), .libPaths()))

  inst_desc <- file.path(lib_dir, "epiIneq", "DESCRIPTION")
  if (file.exists(inst_desc)) {
    src_files <- c(file.path(pkg_dir, "DESCRIPTION"),
                   list.files(file.path(pkg_dir, "R"), pattern = "\\.R$", full.names = TRUE))
    if (file.mtime(inst_desc) < max(file.mtime(src_files)))
      unlink(file.path(lib_dir, "epiIneq"), recursive = TRUE, force = TRUE)
  }

  mode <- "source"
  if (requireNamespace("epiIneq", quietly = TRUE)) {
    library(epiIneq)
    mode <- "installed"
  } else {
    ok <- tryCatch({
      suppressMessages(suppressWarnings(
        utils::install.packages(pkg_dir, repos = NULL, type = "source",
                                lib = lib_dir, quiet = TRUE)
      ))
      TRUE
    }, error = function(e) FALSE, warning = function(w) FALSE)
    if (ok && requireNamespace("epiIneq", quietly = TRUE)) {
      library(epiIneq)
      mode <- "installed"
    }
  }

  if (mode == "source") {
    files <- c("utils.R", "curve.R", "sii.R", "groups.R", "decompose.R",
               "access.R", "summary.R", "counts.R", "report.R", "example.R")
    for (f in files) source(file.path(pkg_dir, "R", f), encoding = "UTF-8")
  }
  if (isTRUE(verbose))
    cat(sprintf("[epi-ineq] 加载方式: %s\n", mode))
  invisible(mode)
}
