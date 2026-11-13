# EpiStack

Turn raw infectious disease surveillance data into aberration alerts, spatial risk maps and health-inequality reports. Pure R, no third-party dependencies, runs offline.

[中文说明](README.md) · Version `v0.2.0` · [Changelog](CHANGELOG.md) · [Roadmap](ROADMAP.md)

## What it is

A layered analysis chain. Each layer does one job, and layers talk to each other only through the same data contract, so you can use any layer on its own or run the whole chain.

| Layer | Package | Responsibility | Input → output |
|---|---|---|---|
| L0 | `epiCore` | Data contract, region codes, adjacency weights | raw table → contract table |
| L1 | `epiIngest` | Multi-source readers and QC | CSV / Excel / database / API → clean table |
| L2 | `epiAlert` | Seasonal baselines, aberration signals | table → alert list |
| L3 | `epiSpace` | Moran / LISA / BYM2 | table + weights → risk map |
| L4 | `epiIneq` | Concentration index / SII / decomposition | table + SES → inequality metrics |
| L5 | `epiReport` | Single-file HTML reports | layer results → shareable output |
| L6 | `epiFlow` | Orchestration and manifest | everything → one-command rerun |

L0 (`epiCore`) and L1 (`epiIngest`) are released. The remaining layers ship monthly; their interfaces will not change.

The contract — every layer reads and writes only these:

```r
# long table
date · region · count · population · disease

# geographic and socio-economic coding
geo   # region, population, ses, row/col or admin code

# adjacency weights (row-standardized, symmetric, no islands)
W
```

## Install

```r
# L0 contract and readers
install.packages(
  "https://github.com/Rythonme/EpiStack/releases/download/v0.1.1/epiCore_0.1.0.tar.gz",
  repos = NULL, type = "source"
)

# L1 multi-source ingestion and QC
install.packages(
  "https://github.com/Rythonme/EpiStack/releases/download/v0.2.0/epiIngest_0.2.0.tar.gz",
  repos = NULL, type = "source"
)

library(epiCore); library(epiIngest)
```

Plain R, no compiler or Rtools needed. For the development version see [epi-core/README.md](epi-core/README.md) and [epi-ingest/README.md](epi-ingest/README.md).

## Quickstart

```bash
git clone https://github.com/Rythonme/EpiStack.git
cd EpiStack

Rscript pipeline.R --check     # run the full chain and verify results
Rscript pipeline.R --list      # show the layer plan only
```

Results land in `pipeline_out/`:

- `site/index.html` — report site, open in any browser
- `pipeline_manifest.json` — what ran, how long it took, contract version
- `<stage>/` — layer reports, alert CSV, stage caches

Run one chain on its own (from the repository root):

```bash
Rscript vertical_slice/run_e2e.R      # six-layer example, synthetic data
Rscript case_panel/run_panel.R         # panel example, built-in synthetic data
```

Neither command needs external data.

## Reading your own data with `epiCore`

```r
library(epiCore)

core <- read_counts(
  "counts.csv",
  geo       = geo,                 # region, population, ses, row, col
  time_step = "month",             # week / month / quarter / year / auto
  graph     = "provinces.graph",   # optional INLA adjacency; row/col builds a grid
  mapping   = list(date = "date", region = "province", count = "cases")
)

core$data                # date region count population disease year period
core$geo                 # normalized region codes
core$W                   # adjacency weights
core$qc$report           # rows flagged by each QC check
validate_contract(core)  # TRUE on success
```

`read_counts()` handles column aliases, BOM/whitespace/administrative suffixes, date parsing (`YYYY`, `YYYY-MM`, `YYYY-MM-DD`), duplicate keys and dirty rows, population denominators, period mapping, adjacency construction and contract validation.

| Function | Purpose |
|---|---|
| `read_counts()` | main reader and contract entry point, returns an `epi_contract` |
| `validate_contract()` / `epi_contract_check()` | strict / non-strict contract validation |
| `epi_schema()` | versioned contract definition (mirrors `inst/contract/schema.json`) |
| `normalize_region()` / `epi_region_codes()` | region normalization and code tables |
| `epi_adjacency()` / `epi_read_graph()` | grid rook/queen weights, INLA `.graph` adjacency |
| `epi_qc()` | standalone QC checker |
| `epi_period()` / `epi_wrap_period()` / `epi_period_label()` | week / month / quarter / year mapping |

Switch granularity with one argument:

```r
read_counts(x, time_step = "week")     # 52 periods
read_counts(x, time_step = "month")    # 12 periods
read_counts(x, time_step = "quarter")  # 4 periods
read_counts(x, time_step = "year")     # annual index
read_counts(x, time_step = "auto")     # inferred from date spacing
```

## Cleaning messy inputs with `epiIngest`

```r
library(epiIngest)

src <- ingest_source("csv", "counts.csv",
                     mapping = list(date = "date", region = "province", count = "cases"))

ingest_profile(ingest_read(src))   # column types, missingness, date range, duplicate keys

rules <- ingest_qc_default(geo)    # default rules + region whitelist
res   <- qc_apply(src, rules)      # errors dropped, warnings flagged, every row traced
qc_report(res, "qc_report.html")   # single-file report you can send back to the data owner

core <- ingest_counts(src, rules = rules, geo = geo, time_step = "month")
core$ingest$n_dropped              # rows removed by the rules
```

Rules can be stored as JSON next to your project and reused with `qc_apply(src, "config/qc_rules.json")`. Excel, databases, HTTP endpoints and raster covariates go through optional adapters; `epi_ingest_capabilities()` tells you exactly which ones the current machine can run.

## Data and privacy

The repository contains synthetic data only: `demo/make_demo_data.R` generates a fixed-seed panel of 31 fictional regions (`D01`–`D31`). Every example and default run uses it.

Real surveillance data is never shipped or uploaded. Point an ignored local config (`case_panel/data_paths.local.R`, template in `data_paths.example.R`) or the `EPISTACK_PANEL_*` environment variables at your files; data stays read-only and outputs stay on your machine.

## Layout

```
EpiStack/
├── epi-core/                  # L0: formal R package (source, docs, tests, schema)
├── epi-ingest/                # L1: formal R package (readers, QC, reports, masking)
├── ingest_demo/               # L1 demo: synthetic data → QC report → contract check
├── demo/                      # synthetic data generator
├── vertical_slice/            # six-layer end-to-end example
├── case_panel/                # panel case (synthetic by default, --local for private data)
├── pipeline.R                 # orchestration entry point
└── tests/                     # end-to-end self-checks and baselines
```

## Documentation

- Online demo: [rythonme.github.io/EpiStack](https://rythonme.github.io/EpiStack/) (reports and board)
- [ROADMAP.md](ROADMAP.md) — layer release status
- [CHANGELOG.md](CHANGELOG.md) — change log
- [epi-core/README.md](epi-core/README.md) — L0 package usage and install details
- [epi-ingest/README.md](epi-ingest/README.md) — L1 package usage and install details

## License

MIT. Thresholds and definitions must be calibrated to the local disease and reporting system; outputs are not public-health decisions.
