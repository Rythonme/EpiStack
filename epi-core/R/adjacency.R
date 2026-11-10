# =============================================================
# epiCore / adjacency.R — 空间权重矩阵
# 两种来源：① 规则格网（row/col）② 真实边界导出的 INLA .graph 邻接表
# 两者输出同一形态：行标准化、带地区名、对称的 n x n 矩阵。
# =============================================================

#' 行标准化
epi_row_standardize <- function(W) {
  rs <- rowSums(W)
  iso <- which(rs == 0)
  if (length(iso))
    stop(sprintf("存在 %d 个孤立地区，无法行标准化：%s",
                 length(iso), paste(rownames(W)[iso], collapse = ", ")),
         call. = FALSE)
  out <- sweep(W, 1L, rs, "/")
  dimnames(out) <- dimnames(W)
  out
}

#' 规则格网邻接（rook / queen）
epi_adjacency <- function(geo, style = c("rook", "queen"), row_standardize = TRUE) {
  style <- match.arg(style)
  if (!is.data.frame(geo) || !all(c("region", "row", "col") %in% names(geo)))
    stop("格网邻接需要 geo 表含 region / row / col；真实行政边界请用 epi_read_graph()",
         call. = FALSE)
  n <- nrow(geo)
  dr <- outer(geo$row, geo$row, "-")
  dc <- outer(geo$col, geo$col, "-")
  adj <- if (style == "rook") (abs(dr) + abs(dc) == 1L) else (pmax(abs(dr), abs(dc)) == 1L)
  W <- matrix(as.numeric(adj), n, n, dimnames = list(geo$region, geo$region))
  diag(W) <- 0
  if (row_standardize) W <- epi_row_standardize(W)
  W
}

#' 读取 INLA .graph 邻接表（spdep::nb2INLA 输出格式）
#'
#' 格式：首行 n，随后 n 行「节点号 邻居数 邻居1 邻居2 ...」。
#' 会自动对称化，并给孤立节点显式报错（ICAR 奇异的常见根因）。
epi_read_graph <- function(path, regions = NULL, row_standardize = TRUE) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  bom <- intToUtf8(65279L)
  lines <- trimws(gsub(bom, "", lines, fixed = TRUE))
  lines <- lines[nzchar(lines)]
  if (!length(lines)) stop("邻接图文件为空", call. = FALSE)
  n <- suppressWarnings(as.integer(lines[1L]))
  if (is.na(n) || n < 1L) stop("邻接图首行必须是地区数", call. = FALSE)
  body <- lines[-1L]
  if (length(body) < n)
    stop(sprintf("邻接图行数不足：期望 %d，实际 %d", n, length(body)), call. = FALSE)
  body <- body[seq_len(n)]
  if (is.null(regions)) regions <- as.character(seq_len(n))
  if (length(regions) != n)
    stop(sprintf("regions 长度 %d 与邻接图地区数 %d 不一致", length(regions), n),
         call. = FALSE)

  W <- matrix(0, n, n, dimnames = list(regions, regions))
  for (ln in body) {
    tk <- suppressWarnings(as.integer(strsplit(ln, "[[:space:]]+")[[1L]]))
    if (length(tk) < 2L || is.na(tk[1L]) || is.na(tk[2L])) next
    i <- tk[1L]
    nb <- tk[-c(1L, 2L)]
    nb <- nb[!is.na(nb) & nb >= 1L & nb <= n & nb != i]
    if (length(nb)) {
      W[i, nb] <- 1
      W[nb, i] <- 1
    }
  }
  diag(W) <- 0
  if (row_standardize) W <- epi_row_standardize(W)
  W
}

#' 邻接矩阵体检
epi_adjacency_check <- function(W) {
  structure <- W > 0                      # 行标准化后数值不再对称，但邻接结构必须对称
  list(
    n = nrow(W),
    symmetric = isTRUE(all.equal(structure, t(structure), check.attributes = FALSE)),
    islands = rownames(W)[rowSums(W) == 0],
    rowsum_min = min(rowSums(W)),
    rowsum_max = max(rowSums(W)),
    density = sum(structure) / (nrow(W) * (nrow(W) - 1L)),
    note = "行标准化矩阵的 W[i,j] 与 W[j,i] 可以不等；对称性按邻接结构判定"
  )
}
