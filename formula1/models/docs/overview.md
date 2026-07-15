{% docs __overview__ %}

# formula1-dbt

dbt transformation layer (Silver + Gold) for Formula 1 race data, built on Databricks.

Bronze data is ingested upstream by [formula1-data-engineering-project](https://github.com/sathiskumr/formula1-data-engineering-project); this project owns everything from Silver onward:

- **Silver** — one model per source entity: cleaned, deduplicated, incrementally merged.
- **Gold** — a star schema (`dim_drivers`, `dim_constructors`, `dim_races`, `fact_session_results`) built on top of Silver.

Use the **Database** tree on the left, or the search bar above, to browse models, sources, and tests. The **Lineage Graph** (bottom-right icon) shows how everything connects from Bronze through to Gold.

## Links

- [GitHub repository](https://github.com/sathiskumr/formula1-dbt)
- [Upstream ingestion pipeline](https://github.com/sathiskumr/formula1-data-engineering-project)

## Conventions

- Silver and Gold models both enforce `contract: {enforced: true}` — column names and types are locked.
- Test severities are split deliberately: `error` on grain/primary-key integrity, `warn` on data-quality signals that shouldn't block a build.
- Gray-highlighted nodes in the lineage graph are unmodified pass-throughs; colored nodes have logic applied.

{% enddocs %}