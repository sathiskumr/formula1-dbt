<div align="center">

# 🏎️ formula1-dbt

**dbt transformation layer for the [formula1-data-engineering-project](https://github.com/sathiskumr/formula1-data-engineering-project) — Silver and Gold rebuilt as a dbt project on Databricks.**

[![dbt](https://img.shields.io/badge/dbt--core-1.11-FF694B?style=flat&logo=dbt&logoColor=white)](https://www.getdbt.com/)
[![Databricks](https://img.shields.io/badge/Databricks-FF3621?style=flat&logo=databricks&logoColor=white)](https://www.databricks.com/)
[![Dev CI](https://github.com/sathiskumr/formula1-dbt/actions/workflows/dev-ci.yml/badge.svg)](https://github.com/sathiskumr/formula1-dbt/actions/workflows/dev-ci.yml)
[![Prod Deploy](https://github.com/sathiskumr/formula1-dbt/actions/workflows/prod-build.yml/badge.svg)](https://github.com/sathiskumr/formula1-dbt/actions/workflows/prod-build.yml)
[![dbt docs](https://img.shields.io/badge/dbt%20docs-live-success?style=flat&logo=dbt&logoColor=white)](https://sathiskumr.github.io/formula1-dbt/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

</div>

---

## ⚡ TL;DR

The [formula1-data-engineering-project](https://github.com/sathiskumr/formula1-data-engineering-project) ingests F1 race data into a Bronze Delta layer on Databricks. This repo takes it from there: the Silver and Gold layers are rebuilt as **dbt models**, purpose-built to demonstrate dbt-specific engineering — incremental `merge` strategies, enforced model contracts, layered data tests with severities, dbt unit tests for regression coverage, and a slim CI/CD pipeline using `state:modified+` and `--defer`. Same data, same medallion shape, dbt-native implementation.

---

## 📌 About the Project

Bronze data already exists in Databricks Warehouse (deep-cloned into `formula1_dbt_dev` / `formula1_dbt_prod`); this project owns everything downstream of it.

- **Silver** — one dbt model per source entity: filters to the batch(es) not yet processed, renames (camelCase → snake_case), drops structurally invalid rows (missing key fields), deduplicates on the natural key, and incrementally merges into Delta tables.
- **Gold** — a star schema built on top of Silver: `dim_drivers`, `dim_constructors`, `dim_races`, and a unified `fact_session_results` table (race + sprint sessions, one row each, discriminated by `session_type`).
- **Reference data** — static lookups (nationality → region, constructor colors, driver codes) are declared as `source()`s rather than seeds, since they're built once outside the regular dbt run cycle but still need DAG/lineage visibility.

### Architecture

```
                    Formula 1 Dataset
                           │
                           ▼
              Upstream Ingestion Project
              (Databricks Workflows)
                           │
                           ▼
                 Bronze Delta Tables
                           │
                    dbt source()
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│                    dbt Transformation Layer                  │
│                                                              │
│   Silver Models               Gold Models                    │
│ ┌───────────────┐          ┌────────────────┐                │
│ │ Cleaning      │────────▶ │ Dimensions     │                │
│ │ Deduplication │          │ Fact Tables    │                │
│ │ Standardize   │          │ Star Schema    │                │
│ │ Incremental   │          │ Business Logic │                │
│ └───────────────┘          └────────────────┘                │
│                                                              │
│  - Generic Tests                                             │
│  - Unit Tests                                                │
│  - Model Contracts                                           │
└──────────────────────────────────────────────────────────────┘
                           │
             ┌─────────────┴─────────────┐
             ▼                           ▼
      dbt Documentation            Analytics
      (GitHub Pages)           Power BI / SQL
                          

                 GitHub Actions CI/CD
          • Slim CI (state:modified+)
          • Unit Tests
          • Build
          • Publish Docs
```

---

## 🛠️ Tech Stack

| Layer | Technology | Purpose |
|---|---|---|
| **Transformation** | dbt-core 1.11 + dbt-databricks | Silver/Gold models, tests, docs, macros |
| **Warehouse** | Databricks (Delta Lake, Unity Catalog) | Storage + compute, `formula1_dbt_dev` / `formula1_dbt_prod` catalogs |
| **Testing** | `dbt_utils`, `dbt_expectations`, dbt unit tests | Schema tests, range/relationship checks, regression coverage on model logic |
| **Package/env management** | `uv` | Python + dbt dependency management, lockfile-based reproducibility |
| **CI/CD** | GitHub Actions | Slim CI on PRs (`state:modified+`, `--defer`), full build on merge to `main` |
| **Docs hosting** | GitHub Pages | Static `dbt docs generate --static` site — lineage graph, column-level docs, test coverage |

---

## 📁 Project Structure

```
📦 formula1-dbt
 ┣ 📁 formula1/
 ┃ ┣ 📁 models/
 ┃ ┃ ┣ 📁 bronze/       # Ephemeral passthrough models over source()
 ┃ ┃ ┣ 📁 silver/       # Cleaned, deduped, incrementally merged
 ┃ ┃ ┣ 📁 gold/
 ┃ ┃ ┃ ┣ 📁 dimensions/ # dim_drivers, dim_constructors, dim_races
 ┃ ┃ ┃ ┗ 📁 facts/      # fact_session_results
 ┃ ┃ ┗ 📁 docs/         # Custom dbt docs overview block
 ┃ ┣ 📁 macros/         # get_max_batch_id, get_max_updated_timestamp, generate_schema_name
 ┃ ┣ 📁 _prod_profiles/ # profiles.yml (dev/prod Databricks targets)
 ┃ ┗ 📄 dbt_project.yml
 ┣ 📁 .github/workflows/
 ┃ ┣ 📄 dev-ci.yml      # Slim CI: dbt build on every PR
 ┃ ┗ 📄 prod-build.yml  # Full build on merge to main; publishes state artifact + dbt docs
 ┣ 📄 pyproject.toml / uv.lock
 ┗ 📄 README.md
```

---

## 🗄️ Data Model

### Silver

One model per source entity, each following the same shape: filter to the current `batch_id` (or everything newer than the target table's max `batch_id` on incremental runs) → rename/clean → drop rows missing key fields → dedupe via `row_number()` over the natural key, ordered by `batch_id` (and `ingestion_timestamp` as a tiebreaker where applicable) → merge.

| Model | Grain | Notes |
|---|---|---|
| `silver_drivers` | one row per driver | Full name concatenated from nested `name.givenName` / `name.familyName` |
| `silver_constructors` | one row per constructor | |
| `silver_circuits` | one row per circuit | |
| `silver_races` | one row per `(season, round)` | |
| `silver_results` | one row per `(season, round, constructor_id, driver_id)` | Race sessions; rows missing any key field are filtered out before dedup |
| `silver_sprints` | one row per `(season, round, constructor_id, driver_id)` | Sprint sessions |

All Silver models have `contract: {enforced: true}` set at the `models.formula1.silver` level in `dbt_project.yml`, so column names and types are locked and schema drift fails the build (`on_schema_change: fail`) instead of silently propagating.

### Gold — Star Schema

| Model | Type | Grain |
|---|---|---|
| `dim_drivers` | Dimension | one row per driver, enriched with `nationality_region` |
| `dim_constructors` | Dimension | one row per constructor, enriched with `nationality_region` |
| `dim_races` | Dimension | one row per `(season, round)`, denormalized with circuit attributes |
| `fact_session_results` | Fact | one row per `(season, round, constructor_id, driver_id, session_type)` — race and sprint results unioned, with derived `is_win` / `is_podium` / `has_points` / `is_pole` boolean flags |

`fact_session_results` wraps each derived flag in `coalesce(..., false)` — a DNF/DNS row has a null `final_position`, so without the coalesce, `final_position = 1` evaluates to null instead of `false` and the flag silently disappears from downstream aggregations instead of correctly reading as "no".

---

## ✅ Testing Strategy

Every column in Silver and Gold carries a purpose-built test, not a blanket `not_null`/`unique` sweep — and severities are chosen deliberately rather than left at the default.

| Test type | Used for | Severity pattern |
|---|---|---|
| `not_null` / `unique` on primary keys | Grain integrity | `error` — a broken key fails the build |
| `relationships` | Cross-model referential integrity (e.g. `fact_session_results` → `dim_drivers`) | `warn` — a late-arriving driver shouldn't block a build |
| `dbt_utils.unique_combination_of_columns` | Composite-key uniqueness on multi-column grains | `error` |
| `dbt_expectations.expect_column_values_to_be_between` | Range checks (lat/long, season bounds, points ≥ 0) | `warn` |
| `dbt_expectations.expect_table_row_count_to_be_between` | Row-count sanity (catches a silently empty run) | `warn` |
| `store_failures: true` (project-wide default) | Every failing test persists its failing rows to a `_test_failures` schema for inspection, instead of just a pass/fail count | — |
| **dbt unit tests** | Model *logic*, not warehouse data — fixtures in, asserted rows out | build-breaking by definition |

Unit tests run as part of `dbt build` in dev CI (so a broken fixture fails the PR), but are excluded from the prod deploy (`--exclude-resource-type unit_test`) since they test logic against fixtures rather than the live warehouse.

---

## ⚙️ Engineering Highlights

- **Batch-aware incremental merges** — `get_max_batch_id()` and `get_max_updated_timestamp()` macros pull the current high-water mark from the target table so each run only processes what's new, without relying on a variable being passed in. Both work around Databricks' restriction on aggregate subqueries inside a `MERGE ... WHEN` clause by resolving the max value in a separate `run_query()` call first.
- **Model contracts** — Silver and Gold both enforce contracts (`contract: {enforced: true}`), so a renamed or retyped column fails CI instead of quietly breaking a downstream model.
- **Layered data tests** — generic tests (`not_null`, `unique`, `relationships`) plus `dbt_expectations` for range and row-count checks, with severities split between `error` (grain/PK integrity — build-breaking) and `warn` (data-quality signals that shouldn't block a run, e.g. a missing nationality) — see [Testing Strategy](#-testing-strategy).
- **Custom schema macro** — `generate_schema_name.sql` uses the custom schema exactly as configured (`bronze` / `silver` / `gold`) instead of dbt's default `<target_schema>_<custom_schema>` concatenation, so tables land in clean, predictable schemas rather than `default_silver` / `default_gold`.
- **Slim CI** — `dev-ci.yml` runs `dbt build --select state:modified+ --defer --state ./prod-target` on every PR, comparing against the latest successful prod build's artifacts (downloaded from `prod-build.yml`) rather than rebuilding the whole project.

---

## 🔁 CI/CD

| Workflow | Trigger | What it does |
|---|---|---|
| `dev-ci.yml` | Every PR | `uv sync` → `dbt deps` → downloads the latest prod `manifest.json`/`state` artifact → `dbt build --select state:modified+ --defer --state ./prod-target` against the `dev` target |
| `prod-build.yml` | Push to `main`, or manual dispatch | `uv sync` → `dbt deps` → full `dbt build --exclude-resource-type unit_test` against the `prod` target → uploads `target/` as the `prod-target` artifact (90-day retention) → generates static dbt docs and deploys them to GitHub Pages |

Dev and prod are fully separated at the catalog level (`formula1_dbt_dev` / `formula1_dbt_prod`), each with its own Databricks token via `_prod_profiles/profiles.yml`.

---

## 📚 dbt Docs

Generated docs (lineage graph, column-level descriptions, test coverage) are hosted as a static site via GitHub Pages: **[sathiskumr.github.io/formula1-dbt](https://sathiskumr.github.io/formula1-dbt/)**.

---

## 🔗 Related

- **[formula1-data-engineering-project](https://github.com/sathiskumr/formula1-data-engineering-project)** — the upstream Databricks pipeline: Jolpica F1 API ingestion, Bronze layer, Lakeflow orchestration, and the Power BI dashboard this data ultimately feeds.

---

## 📜 License

MIT — see [LICENSE](LICENSE). Formula 1 data originates from the [Jolpica F1 API](https://api.jolpi.ca), a community-maintained continuation of the Ergast API. F1 branding and trademarks belong to Formula One World Championship Limited.