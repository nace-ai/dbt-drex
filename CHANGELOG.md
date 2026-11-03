# Changelog

## 0.1.2

The first public release, from `nace-ai/dbt-drex`.

- Adapters built on dbt-postgres (Materialize, Greenplum, Redshift and others) fail to compile with `the <adapter>
  adapter isn't supported`, in every macro and accessor, instead of compiling `public.drex_*` calls their database
  doesn't have. The SQL every supported adapter gets is unchanged.
- Docs: for `drex_decide_image`, pass the same explicit `model` to it and to `drex_fingerprint`, since it doesn't read
  `var('drex_model')`; on Postgres, the macros and drex-postgres's functions need `standard_conforming_strings` on.
- Tests: every SQL example in the README and the Macro API builds twice on DuckDB, Postgres and ClickHouse in CI, and
  the incremental test checks the documented condition that asks rows with no answer again.

## 0.1.1

- `model=''` now reads `var('drex_model')`, as `none` does and the Macro API says, in every macro and in
  `drex_fingerprint`.
- A duplicate or empty label is reported as `labels must be unique` (or `levels`), not `labels labels`.
- Docs: the threshold examples qualify the result column, since ClickHouse reads `team` after `as team` as the alias;
  a dict `state` is sent for every row; `dbt show` sends rows; an incremental model doesn't ask a row with a NULL
  answer again unless told to; YAML reads `yes` and `no` as booleans.

## 0.1.0

The first release.

- `drex_noul`, `drex_choice`, `drex_score`, `drex_decide` and `drex_decide_image` for dbt-snowflake, dbt-bigquery,
  dbt-databricks, dbt-postgres, dbt-clickhouse and dbt-duckdb, compiling to drex-snowflake 0.2.0, drex-bigquery
  0.1.0, drex-spark 0.1.1 (Unity Catalog functions), drex-postgres 0.3.0, drex-clickhouse 0.1.2 and drex-duckdb 0.1.0.
- Labels, criteria and questions as Jinja values, checked when a model compiles.
- `drex_choice_value`, `drex_score_value` and `drex_confidence` to read results on any warehouse.
- `drex_fingerprint` for incremental models that send only changed rows, and a warning when a Drex macro compiles
  into a view or an ephemeral model.
