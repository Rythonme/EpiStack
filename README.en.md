# EpiStack

Turn raw infectious disease surveillance data into aberration alerts, spatial risk maps and health-inequality reports. Pure R, no third-party dependencies, runs offline.

[中文说明](README.md) · Version `v0.5.0` · [Changelog](CHANGELOG.md) · [Roadmap](ROADMAP.md)

## What it is

A layered analysis chain. Each layer does one job, and layers talk to each other only through the same data contract, so you can use any layer on its own or run the whole chain.

| Layer | Package | Responsibility | Input → output |
|---|---|---|---|
| L0 | `epiCore` | Data contract, region codes, adjacency weights | raw table → contract table |
| L1 | `epiIngest` | Multi-source readers and QC | CSV / Excel / database / API → clean table |
| L2 | `epiAlert` | Seasonal baselines, aberration signals | table → alert list |
| L3 | `epiSpace` | Moran / LISA / BYM2 | table + weights → risk map |
| L3.5 | `epiRobust` | MAUP / weights / spatial SE / multiplicity | table + weights → robustness report |
| L4 | `epiIneq` | Concentration index / SII / decomposition | table + SES → inequality metrics |
| L5 | `epiReport` | Single-file HTML reports | layer results → shareable output |
| L6 | `epiFlow` | Orchestration and manifest | everything → one-command rerun |

L0 (`epiCore`), L1 (`epiIngest`), L2 (`epiAlert`), L3 (`epiSpace`), L3.5 (`epiRobust`) and L4 (`epiIneq`) are released. The remaining layers ship monthly; their interfaces will not change.

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
  "https://github.com/Rythonme/EpiStack/releases/download/v0.1.2/epiCore_0.1.1.tar.gz",
  repos = NULL, type = "source"
)

# L1 multi-source ingestion and QC
install.packages(
  "https://github.com/Rythonme/EpiStack/releases/download/v0.2.1/epiIngest_0.2.1.tar.gz",
  repos = NULL, type = "source"
)

# L2 seasonal baselines and alert grading
install.packages(
  "https://github.com/Rythonme/EpiStack/releases/download/v0.3.0/epiAlert_0.1.0.tar.gz",
  repos = NULL, type = "source"
)

# L3 spatial autocorrelation and hotspots
install.packages(
  "https://github.com/Rythonme/EpiStack/releases/download/v0.4.0/epiSpace_0.1.0.tar.gz",
  repos = NULL, type = "source"
)

# L3.5 spatial robustness audit
install.packages(
  "https://github.com/Rythonme/EpiStack/releases/download/v0.6.0/epiRobust_0.1.0.tar.gz",
  repos = NULL, type = "source"
)

# L4 concentration index / SII / decomposition / accessibility
install.packages(
  "https://github.com/Rythonme/EpiStack/releases/download/v0.5.0/epiIneq_0.1.0.tar.gz",
  repos = NULL, type = "source"
)

library(epiCore); library(epiIngest); library(epiAlert); library(epiSpace); library(epiRobust); library(epiIneq)
```

Plain R, no compiler or Rtools needed. For the development version see [epi-core/README.md](epi-core/README.md), [epi-ingest/README.md](epi-ingest/README.md), [epi-alert/README.md](epi-alert/README.md), [epi-space/README.md](epi-space/README.md), [epi-robust/README.md](epi-robust/README.md) and [epi-ineq/README.md](epi-ineq/README.md).

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
Rscript alert_demo/run_alert.R        # alerting demo: baseline → grading → retrospective scan
Rscript space_demo/run_space.R        # spatial demo: Moran → LISA → hotspots
Rscript case_panel/run_panel.R        # panel example, built-in synthetic data
```

None of them needs external data.

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

## Alerting with `epiAlert`

```r
library(epiAlert)

x <- alert_counts(core)                 # contract table → baseline → exceedance → grading
x$alerts                                # date / region / count / upper / run length / level
x$summary                               # per region: counts by level, peak level, last signal

alert_report(x, "alerts.html")          # single-file report, ready to forward
alert_counts(core, assess = "latest")   # operational view: latest period only
```

Baselines use only history before the period being evaluated (same seasonal window, earlier
years only), so a retrospective scan never feeds a period into its own baseline. Four methods
(`seasonal` / `pooled` / `moving` / `poisson`) are picked automatically by granularity;
`alert_methods()` lists when each applies.

Thresholds are data, not code: `alert_rules(warn_ratio = 2, alarm_ratio = 3)` changes the
calibration, `alert_rules_write()` stores it as JSON with your project.

## Spatial patterns with `epiSpace`

```r
library(epiSpace)

x <- space_counts(core)                 # contract + weights → global → local → hotspots
x$global                                # Moran's I and permutation p-value
x$hotspots                              # per region: local I, p, HH/LL/HL/LH, category
space_report(x, "spatial-report.html")  # single-file report, ready to forward
```

Weights come from the upstream contract; `epiCore::epi_read_graph()` reads an
adjacency graph exported from real boundaries, and `space_weights(geo, style = "rook")`
builds one from grid coordinates.

Global Moran uses 999 permutations; local LISA labels a hotspot (HH), coldspot (LL)
or spatial outlier (HL/LH) only when the permutation p-value is significant.
Observations are aligned by the region names in the weight matrix — changing the
neighbourhood definition changes what the result means. For Bayesian modelling,
`space_bym2_template()` emits INLA data and code; this package does not fit models
and does not require INLA.

## Health inequality with `epiIneq`

```r
library(epiIneq)

d <- ineq_example()                  # 4×4 fictional grid, SES low→high
x <- ineq_counts(d)                  # curve → CI → SII → decomposition → accessibility
x$summary                            # seven metrics and how to read them
x$groups                             # low/high SES rates and shares
x$decompose                          # between / within / residual
ineq_report(x, "inequality-report.html")
```

CI = 1 − 2×(population-weighted concentration area); negative means the burden
falls on low-SES regions. SII is the predicted rate difference between the two ends.
CI, SII and the rate ratio must agree in direction before calling it evidence.
SES and coordinates are matched from the upstream `core$geo`; without coordinates
accessibility is skipped and the other metrics still compute. `ineq_methods()` lists
where each method applies.

## Robustness audit with `epiRobust`

```r
library(epiRobust)

d <- robust_example(n_side = 6L)   # 6x6 synthetic grid, no real cases
x <- robust_check(d, scales = c(1L, 2L, 3L),
                  styles = c("rook", "queen", "knn"),
                  n_perm = 199L, seed = 20261124L)
x$verdicts                         # four audit verdicts
x$maup$table                       # Moran / LISA / hotspots at each scale
robust_report(x, "robustness-report.html")
```

The audit asks whether a conclusion survives analyst choices: does the Moran sign flip under aggregation, do hotspots survive alternative adjacency definitions, does spatial dependence shrink standard errors, and how many hotspots survive multiplicity correction. In the demo, I = +0.9055 becomes -0.0009 at 3x aggregation and 12 raw hotspots drop to one. Only `stats` / `utils` are required.

## Data and privacy

The repository contains synthetic data only: `demo/make_demo_data.R` generates a fixed-seed panel of 31 fictional regions (`D01`–`D31`). Every example and default run uses it.

Real surveillance data is never shipped or uploaded. Point an ignored local config (`case_panel/data_paths.local.R`, template in `data_paths.example.R`) or the `EPISTACK_PANEL_*` environment variables at your files; data stays read-only and outputs stay on your machine.

## Layout

```
EpiStack/
├── epi-core/                  # L0: formal R package (source, docs, tests, schema)
├── epi-ingest/                # L1: formal R package (readers, QC, reports, masking)
├── epi-alert/                 # L2: formal R package (baselines, grading, alert sheet)
├── epi-space/                 # L3: formal R package (Moran / LISA / hotspots / BYM2 template)
├── epi-robust/                # L3.5: formal R package (MAUP / weights / Conley SE / multiplicity)
├── epi-ineq/                  # L4: formal R package (curve / CI / SII / decomposition / access)
├── ingest_demo/               # L1 demo: synthetic data → QC report → contract check
├── alert_demo/                # L2 demo: injected outbreak → retrospective scan → alert sheet
├── space_demo/                # L3 demo: injected cluster → hotspot detection → analysis sheet
├── ineq_demo/                 # L4 demo: disadvantaged grid → CI/SII → decomposition → access
├── robust_demo/               # L3.5 demo: multi-scale / multi-adjacency → robustness report
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
- [epi-alert/README.md](epi-alert/README.md) — L2 package usage and install details
- [epi-space/README.md](epi-space/README.md) — L3 package usage and install details
- [epi-robust/README.md](epi-robust/README.md) — L3.5 package usage and install details
- [epi-ineq/README.md](epi-ineq/README.md) — L4 package usage and install details

## License

MIT. Thresholds and definitions must be calibrated to the local disease and reporting system; outputs are not public-health decisions.
