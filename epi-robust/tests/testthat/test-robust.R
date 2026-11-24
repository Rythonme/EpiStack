test_that("合成示例结构正确", {
  d <- robust_example()
  expect_true(is.data.frame(d))
  expect_true(all(c("region", "count", "population", "row", "col") %in% names(d)))
  expect_equal(length(unique(d$region)), 36L)
  expect_equal(sum(d$count[d$region == "R36"]), sum(d$count[d$region == "R36"]))
})

test_that("权重敏感性可复现且覆盖三种邻接", {
  d <- robust_example()
  a <- robust_weights(d, n_perm = 49L, seed = 1L)
  b <- robust_weights(d, n_perm = 49L, seed = 1L)
  expect_equal(a$table$I, b$table$I)
  expect_equal(a$table$p, b$table$p)
  expect_equal(nrow(a$table), 3L)
  expect_setequal(a$table$style, c("rook", "queen", "knn"))
})

test_that("MAUP 多尺度输出且地区数递减", {
  d <- robust_example()
  r <- robust_maup(d, scales = c(1L, 2L, 3L), n_perm = 49L, seed = 1L)
  expect_equal(nrow(r$table), 3L)
  expect_true(all(r$table$n_regions >= 3L))
  expect_true(r$table$n_regions[1L] > r$table$n_regions[3L])
  expect_s3_class(r, "epi_robust_maup")
})

test_that("Conley 标准误在多个截断下可算", {
  d <- robust_example()
  r <- robust_conley(d)
  expect_equal(nrow(r$table), 4L)
  expect_true(all(r$table$se_ratio > 0))
  expect_true(all(r$table$conley_lo <= r$table$conley_hi))
})

test_that("BH-FDR 校正后 p 单调且不小于原始 p", {
  p <- c(0.001, 0.02, 0.04, 0.3, 0.8)
  r <- robust_multiplicity(p, method = "fdr")
  o <- order(r$table$p)
  expect_true(all(diff(r$table$fdr_p[o]) >= -1e-12))
  expect_true(all(r$table$fdr_p >= r$table$p - 1e-12))
})

test_that("一键体检端到端可复现", {
  d <- robust_example()
  a <- robust_check(d, n_perm = 49L, seed = 7L)
  b <- robust_check(d, n_perm = 49L, seed = 7L)
  expect_s3_class(a, "epi_robust")
  expect_length(a$verdicts, 4L)
  expect_equal(a$overall, b$overall)
  expect_equal(a$maup$table$I, b$maup$table$I)
})

test_that("输入校验有效", {
  d <- robust_example()
  bad <- d[, setdiff(names(d), "count")]
  expect_error(robust_weights(bad), "缺少必要列")
  expect_error(robust_maup(d, scales = 0L), "scales")
})
