# epiIngest

EpiStack 体系的 **L1 层**：把「数据怎么进来」这件事做扎实。
多源读取 → 规则化质控 → 输出统一契约，下游一行不改。

- **零强制依赖**：`Imports` 只有 `utils` / `stats` / `tools`。断网只装 base R 也能读 CSV 并质控。
- **规则是数据不是代码**：质控规则存成 JSON 随项目走，换口径改文件、不改包。
- **口径与 `epiCore` 一致**：`ingest_counts()` 内部只调用一次 `epiCore::read_counts()`，不复制契约逻辑，因此两者结果一致。

## 安装

```r
# 需要 epiCore 生成契约（可选，只读 + 质控不需要）
install.packages(
  "https://github.com/Rythonme/EpiStack/releases/download/v0.1.1/epiCore_0.1.0.tar.gz",
  repos = NULL, type = "source"
)

install.packages(
  "https://github.com/Rythonme/EpiStack/releases/download/v0.2.0/epiIngest_0.2.0.tar.gz",
  repos = NULL, type = "source"
)
library(epiIngest)
```

可选后端按需安装，缺了不影响核心链路：

```r
install.packages(c("readxl", "DBI", "terra", "openssl"))   # Excel / 数据库 / 栅格 / 脱敏哈希
epi_ingest_capabilities()                                  # 看当前环境到底能用哪些
```

## 五分钟上手

```r
library(epiIngest)

src <- ingest_source("csv", "counts.csv",
                     mapping = list(date = "日期", region = "省份", count = "发病数"))

ingest_profile(ingest_read(src))   # 先看：列类型、缺失率、日期范围、重复键
```

```r
geo  <- read.csv("geo.csv")                       # region / population / ses
rules <- ingest_qc_default(geo)                    # 默认规则 + 地区白名单
res   <- qc_apply(src, rules)

qc_report(res, "质控单.html")                      # 单文件报告，可直接发出去
core  <- ingest_counts(src, rules = rules, geo = geo, time_step = "month")

core$data        # date / region / count / population / disease / year / period
core$ingest$n_dropped                              # 规则剔除了多少行
```

## 质控规则

```r
rules <- qc_rules(
  required   = c("date", "region", "count"),       # 空值即 error
  unique_key = c("date", "region"),                # 重复保留首条
  range      = list(count = c(0, 1e6)),            # 越界即 error
  date_seq   = list(by = "month", max_gap = 1),    # 断档记 warn
  region_code = list(allowed = geo$region),        # 未知编码即 error
  outlier    = list(method = "mad", k = 8),        # 异常值记 warn
  cross_field = list(list(lhs = "count", op = "<=", rhs = "population")),
  name = "counts-qc"
)
```

| 级别 | 默认行为 | 全局改法 |
|---|---|---|
| `error` | 剔除该行 | 不提供关闭开关 |
| `warn` | 保留并标记 | `ingest_on_warn("drop")` 或 `ingest_on_warn("error")` |

规则可以存成文件，跟着项目做版本管理：

```r
qc_rules_write(rules, "config/qc_rules.json")
res <- qc_apply(src, "config/qc_rules.json")
```

## 输入源

| 类型 | 写法 | 依赖 |
|---|---|---|
| CSV / TSV / 分隔符文本 | `ingest_source("csv", path)`，`encoding = "auto"` 自动识别 UTF-8 / GBK / BOM | base R |
| 多文件 / 整目录 | `path` 给目录或路径向量，按列名对齐后纵向合并 | base R |
| Excel | `ingest_source("excel", path, sheet = 1)` | `readxl` |
| 数据库 | `ingest_source("db", query = "select ...", con = conn)` | `DBI` + 驱动 |
| HTTP 接口 | `ingest_source("api", url, records_path = "result.records")` | base R（JSON 自带解析） |
| 栅格协变量 | `ingest_zonal(raster, polygons, stats = c("mean"))` | `terra` |

## 脱敏

```r
# 加盐 SHA-256 假名：同一盐同一编码永远同一假名，可纵向合并，无法反查
safe <- ingest_desensitize(ingest_read(src), salt = Sys.getenv("EPI_SALT"))
safe$data$region
```

盐值不要入库；需要再识别时用 `key_file` 把对照表写到本地私有目录。

## 文档

| 想干什么 | 看哪个 |
|---|---|
| 声明数据源、读进来看一眼 | `?ingest_source`、`?ingest_read`、`?ingest_profile` |
| 写规则、跑规则、出质控单 | `?qc_rules`、`?qc_apply`、`?qc_report` |
| 直接出契约 | `?ingest_counts` |
| 追溯这份表怎么来的 | `?ingest_lineage` |
| 脱敏 / 栅格协变量 | `?ingest_desensitize`、`?ingest_zonal` |

## 测试

```bash
Rscript tests/test_epi_ingest.R
```

夹具全部在临时目录现造，仓库里不放二进制数据。96 项断言覆盖编码、BOM、分隔符嗅探、
多文件合并、8 类脏数据定位、warn 策略、规则 JSON 往返、报告三种出口、脱敏、
可选适配器，以及与 `epiCore::read_counts()` 的逐位等价性。

没装可选包时，相关几项打印 `SKIP` 而不是失败：核心功能只依赖 base R。

## 许可证

MIT。
