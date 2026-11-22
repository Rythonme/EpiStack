# =============================================================
# epiSpace / bym2.R — BYM2 / INLA 模板
#
# 本层不拟合贝叶斯模型：只产出 INLA 需要的三样东西——数据清单、
# 邻接图代码、可复制的模型代码。INLA 列为 Suggests，不装也能生成。
# 这样把「建模门槛」和「空间描述」分开，装不上 INLA 不影响 L3 其它功能。
# =============================================================

#' 生成 BYM2 / INLA 模板
#'
#' @param x 契约表或 `epiCore::read_counts()` 的返回值
#' @param W 权重矩阵；x 是契约时可省略
#' @param year_value 取哪一年，默认最新
#' @param count / population 计数与人口列名
#' @param graph_file INLA 邻接图输出路径
#' @param data_file 模型数据 CSV 输出路径
#' @return 列表：data / graph_code / code / checklist / note
space_bym2_template <- function(x, W = NULL, year_value = NULL,
                                count = "count", population = "population",
                                graph_file = "graph.txt",
                                data_file = "bym2_data.csv") {
  p <- .space_prepare(x, count = count, population = population)
  if (is.null(W)) W <- p$W
  if (is.null(W))
    .epi_stop("BYM2 需要权重矩阵：传 W，或用 epiCore::read_counts() 的返回值")
  ws <- if (inherits(W, "epi_space_weights")) W else space_weights(W)
  vv <- .space_values(p, year_value = year_value, W = ws$W)
  dat <- vv$tot
  names(dat)[names(dat) == "count"] <- "Y"
  if (!is.null(p$population)) names(dat)[names(dat) == "population"] <- "pop"
  dat$region <- rownames(ws$W)

  graph_code <- paste(
    "# 用 spdep 从 sf 对象导出 INLA 邻接图（需另装 spdep / sf）",
    "library(spdep); library(sf)",
    "nb <- poly2nb(shp)                  # shp: 与 W 同地区的面要素",
    sprintf("spdep::nb2INLA('%s', nb)", graph_file),
    sep = "\n"
  )
  code <- paste(
    "library(INLA)",
    sprintf("d <- read.csv('%s', stringsAsFactors = FALSE)", data_file),
    sprintf("g <- inla.read.graph('%s')", graph_file),
    "d$region <- factor(d$region, levels = rownames(g$nn)",
    "            )",
    "",
    "# BYM2: 空间结构项 + 独立异质项，总方差分成空间占比 phi",
    "f <- Y ~ 1 + f(region, model = 'bym2', graph = g, hyper = list(",
    "  phi = list(prior = 'logitbeta', param = c(0.5, 2/3))",
    "))",
    "",
    "# 人口作 offset（率 = Y / pop）；小地区可换成 poisson 的 control.compute",
    "res <- inla(f, family = 'poisson', data = d,",
    "            E = d$pop / mean(d$pop),",
    "            control.compute = list(dic = TRUE, waic = TRUE, cpo = TRUE))",
    "res$summary.fixed",
    "res$summary.hyperpar",
    sep = "\n"
  )
  checklist <- c(
    "W 的地区顺序必须与 graph 节点顺序一致（本模板按 rownames(W) 导出数据）。",
    "先跑 graph_code 生成邻接图，再跑 inla.read.graph() 校验节点数。",
    "E = pop / mean(pop) 只改变尺度，不改变率；不要再把 pop 放进固定效应。",
    "先验参数需按学科与样本量校准；本模板不是可直接引用的模型设定。",
    "INLA 未安装时本函数仍可生成模板；实际拟合请在装好 INLA 的环境执行。"
  )
  structure(
    list(data = dat, graph_code = graph_code, code = code,
         checklist = checklist, graph_file = graph_file,
         data_file = data_file,
         note = "本层只生成模板，不调用 INLA、不写外部文件"),
    class = "epi_space_bym2"
  )
}
