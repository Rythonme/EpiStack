# EpiStack — End-to-end infectious disease surveillance, spatial and equity analytics

[中文说明](README.md) · Version `v0.1.1` · [Roadmap](ROADMAP.md) · [Nov 2026 log](docs/monthly/2026-11.md) · MIT · R >= 4.2 · zero third-party dependencies

> **Repository**: [github.com/Rythonme/EpiStack](https://github.com/Rythonme/EpiStack) (public · first published 2026-11-11)

> Turn one read-only surveillance table (`date, region, count, population, disease`)
> into a **single self-contained HTML report** covering data QC, aberration detection,
> spatial autocorrelation, health inequality and a reproducibility manifest —
> with one command, offline, in Chinese or English output.

## Why this exists

Mature open-source tools already cover the *algorithm* layer: `avallecam/epichannel`
(endemic channels, unmaintained since 2020), `WarnEpi` (EWMA/CUSUM/Serfling flags),
`EpiSignalDetection` (ECDC Atlas + pandoc + Shiny, EU English format), and
`R4EPI/sitrep` (manual R Markdown outbreak templates). What is missing is the
**delivery layer**: a low-friction, offline, one-CSV-to-one-report pipeline that a
prefecture-level epidemiologist can run without pandoc, Shiny, INLA or internet access.

EpiStack is designed as a **system**, not a bigger single tool. The strategy is:
ship a thin but complete L0–L6 chain in month one, then replace one layer per month
with an independently installable satellite R package. The chain never breaks because
every layer speaks the same contract.

## Architecture

| Layer | Satellite repo | Responsibility | Status (2026-11) |
|---|---|---|---|
| L0 | `epi-core` | Versioned contract, region codes, adjacency weights | **formal R package v0.1.0** |
| L1 | `epi-ingest` | Multi-source readers, QC report | thin (`read_counts()` / `epi_qc()`) |
| L2 | `epi-alert` | Seasonal baseline bands, aberration signals | thin |
| L3 | `epi-space` | Moran / LISA / BYM2 / landscape metrics | thin (Moran + 999 permutations) |
| L4 | `epi-ineq` | Concentration index, SII, accessibility | thin (population-weighted CI) |
| L5 | `epi-report` | Single-file HTML, dashboard | thin (inline SVG) |
| L6 | `epi-flow` | Orchestration, cache, manifest | thin (`pipeline.R` + golden test) |

Contract (the only interface between layers):

```
date · region · count · population · disease     # long table
+ geo: region, row/col or admin code, population, ses
+ W: row-standardized, symmetric spatial weights
```

L2–L4 are deliberately **adapters**, not re-implementations. Heavy engines
(`surveillance`, `r-inla`, `EpiNow2`, `healthequal`) belong in `Suggests`; the
end-to-end chain must still run with base R only, offline.

## Quickstart

```bash
git clone https://github.com/Rythonme/EpiStack.git
cd EpiStack

# 1. Full chain (synthetic data) + golden integration smoke test
Rscript pipeline.R --check

# 2. Just the six-layer vertical slice
Rscript vertical_slice/run_e2e.R

# 2b. Full chain on the built-in synthetic panel (default, no private data)
Rscript case_hfrs_real/run_hfrs.R

# 3. Install the formal contract package (local source)
R CMD INSTALL epi-core
Rscript -e 'library(epiCore); print(epi_schema()$version)'

# 3b. Or install epiCore over the network, no clone and no extra packages:
Rscript -e 'install.packages("https://github.com/Rythonme/EpiStack/releases/download/v0.1.1/epiCore_0.1.0.tar.gz", repos=NULL, type="source"); library(epiCore); print(epi_schema()$version)'

# 4. Inspect the monthly plan
Rscript pipeline.R --list
```

For the development version, `remotes::install_github("Rythonme/EpiStack", subdir = "epi-core", ref = "v0.1.1")`
is the standard syntax (verified on Windows only after the workaround below). On Windows, run `Sys.setenv(TAR = "internal")` first: the
repository contains a few Chinese-named example files that the external `tar.exe` cannot decode
under a non-UTF-8 locale (`input string ... is invalid`). `pak::pkg_install("github::Rythonme/EpiStack/epi-core@v0.1.1")`
and the Release-URL one-liner above avoid this entirely. All three paths were verified on R 4.6.0 / Windows.

`pipeline.R` options: `--all` (also run the local real-data HFRS chain when its
read-only files exist), `--force` (ignore the fingerprint cache), `--check`
(run `tests/smoke_e2e.R`), `--out <dir>`, `--list`.
It uses input fingerprints (md5 of scripts + package sources) to skip unchanged
stages — the core `targets` semantic, implemented in base R. A real `targets`
pipeline is planned for the 2027-08 `epi-flow` satellite.

Outputs: `pipeline_out/<stage>/` (reports, alerts CSV, stage `rds` caches),
`pipeline_out/pipeline_manifest.json`, and `pipeline_out/site/` (index + synthetic
report + project kanban, safe to publish). All are git-ignored.

## The `epiCore` package

```r
library(epiCore)

core <- read_counts(
  "my_counts.csv",
  geo = my_geo,                  # region, population, row, col, ses
  time_step = "month",           # week / month / quarter / year / auto
  graph = "provinces.graph",     # optional INLA adjacency (or row/col grid)
  mapping = list(date = "ym", region = "prov", count = "cases_est")
)
validate_contract(core)
core$data   # date, region, count, population, disease, year, period
core$geo    # normalized region codes
core$W      # row-standardized weights
core$qc     # per-row QC masks + human-readable report
core$meta   # contract version, granularity, source, row counts
```

Also exported: `epi_schema()`, `normalize_region()`, `epi_region_codes()`,
`epi_adjacency()`, `epi_read_graph()`, `epi_qc()`, `epi_period()`.
The machine-readable contract lives at `epi-core/inst/contract/schema.json`.
`bootstrap_core.R` installs the package into a local `.rlib/` automatically and
falls back to sourcing `R/` files when installation is unavailable (offline).

## Verification

- `tests/test_epi_core.R`: 40 base-R assertions (schema, codes, periods, adjacency, QC, main entry point)
- `tests/smoke_e2e.R`: **37 PASS / 0 FAIL** — replays the fixed-seed chain and compares
  every key metric against `tests/golden/vertical_slice_v0.1.0.json`, including the
  6 injected outbreak weeks, Moran's I, concentration index, stage caches and HTML integrity
- `R CMD build` + `R CMD check` on the source tarball (R 4.6.0): **0 ERROR, 0 NOTE, 1 WARNING**
  (the WARNING is a portability note about UTF-8 Chinese comments; functionality is unaffected)
- Synthetic slice: 4159 rows, 56 signals, Moran's I = 0.441 (p = 0.031), CI = −0.067
- Synthetic panel demo (31 regions, fixed seed 20261110): 651 rows, QC 0 drops,
  Moran's I = 0.406 (p = 0.003), cumulative I = 0.858 (p = 0.001), CI = −0.113;
  monthly demo 1116 rows / 372 region-periods / 11 signals

**Privacy / data source:** the public repository ships **no real surveillance data**.
Every example runs on `demo/make_demo_data.R` synthetic data. A private local panel can be
connected through the git-ignored `case_hfrs_real/data_paths.local.R` or `EPISTACK_HFRS_*`
environment variables with `--local`; that data and its results are never committed or uploaded.
`--monthly <CSV>` switches the same contract to a monthly chain; no derived values are
presented as real monthly observations.

## CI, reproducibility and privacy

- `.github/workflows/R-CMD-check.yaml` — on push/PR: build + `R CMD check` (0 ERROR
  gate) plus `Rscript pipeline.R --check`; uploads check logs and the synthetic site.
- `.github/workflows/nightly-e2e.yml` — nightly chain rerun + a privacy guard + GitHub
  Pages deployment of `pipeline_out/site/`. Enable Pages with source "GitHub Actions" once.
- `renv.lock` — a minimal zero-dependency snapshot (R 4.6.0 + CRAN repository). There are
  no third-party packages yet; when one is added, regenerate it with `renv::snapshot()`.
- Raw surveillance data is **read-only** and never committed: `.gitignore` excludes
  `.rlib/`, `case_hfrs_real/output/`, `pipeline_out/`, `tests/_smoke_out/`, `*.rds`.
  CI runs synthetic data only; local real-data reports are never uploaded or published.

## Roadmap (one releasable repo per month)

2026-11 `epi-core` + thin slice → 12 `epi-ingest` → 2027-01 `epi-alert` →
02/03 `epi-space` → 04 `epi-ineq` → 05 `epi-access` → 06/07 report & dashboard →
08 `epi-flow` (real `targets`) → 09 GeoAI → 10 **EpiStack 1.0** integration.
Each month only `R/pipeline_plan.R` changes one `current_impl` line.

Full status table, the monthly update SOP and version/privacy conventions live in
[ROADMAP.md](ROADMAP.md); each month gets a `docs/monthly/YYYY-MM.md` archive
(template: [TEMPLATE.md](docs/monthly/TEMPLATE.md)) and a `vX.Y` GitHub Release.
Published: [v0.1](https://github.com/Rythonme/EpiStack/releases/tag/v0.1),
[v0.1.1](https://github.com/Rythonme/EpiStack/releases/tag/v0.1.1).

## License

MIT. Research/engineering prototype: thresholds and definitions must be calibrated
to the local disease and reporting system; outputs are **not** public-health decisions.
