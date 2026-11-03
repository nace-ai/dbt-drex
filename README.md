<p align="center">
  <a href="https://nace.ai"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/assets/nace-logo-white.svg"><img src="docs/assets/nace-logo-black.svg" alt="Nace" height="40"></picture></a>
</p>

<h1 align="center">Drex for dbt</h1>

<p align="center"><b>Classify text and score rows in dbt models, with one model file for every warehouse.</b></p>

<p align="center">
  <a href="https://github.com/nace-ai/dbt-drex/actions/workflows/Tests.yml"><img src="https://img.shields.io/badge/tests-GitHub_Actions-2088FF" alt="Tests"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT license"></a>
</p>

Ask typed questions about your rows from dbt models. The `drex` package's macros compile to the
[Drex](https://console.nace.ai/docs) functions installed in your warehouse, so the same model runs on Snowflake,
BigQuery, Databricks, Postgres, ClickHouse and DuckDB, and returns calibrated probabilities in the warehouse's own
types.

Use it to route support tickets, classify documents, and score rows as part of your dbt project, with answers kept in
tables and sent again only for rows that changed.

[Before you start](#before-you-start) · [Getting started](#getting-started) · [Examples](#examples) ·
[Macro API](docs/API.md) · [Cost](#what-gets-sent-and-billed)

## What it does

| Macro | Result | Use case |
| --- | --- | --- |
| `drex_noul` | The probability of yes | Flag refund requests |
| `drex_choice` | Label, probabilities, confidence | Route tickets to a team |
| `drex_score` | Score, probabilities, confidence | Rank urgency on an ordered scale |
| `drex_decide` | Drex's full response, as JSON | Ask several questions per row |
| `drex_decide_image` | Drex's full response, about images | Classify photos or receipts |
| `drex_choice_value`, `drex_score_value`, `drex_confidence` | Plain values from a result | Filter on answers on any warehouse |
| `drex_fingerprint` | A hash of a row and its question | Send only changed rows from an incremental model |

## Before you start

The macros call Drex functions your warehouse already has. Install your warehouse's integration first, with its own
API key, as its page describes:

| dbt adapter | Install | Where the functions go |
| --- | --- | --- |
| `dbt-snowflake` | [Drex for Snowflake](https://console.nace.ai/docs/integrations/snowflake) | `DREX.PUBLIC` |
| `dbt-bigquery` | [Drex for BigQuery](https://console.nace.ai/docs/integrations/bigquery) | dataset `drex` |
| `dbt-databricks` | [Drex for Apache Spark and Databricks](https://console.nace.ai/docs/integrations/spark) (Unity Catalog functions) | the catalog and schema you choose; `main.drex` in its docs |
| `dbt-postgres` | [Drex for PostgreSQL](https://console.nace.ai/docs/integrations/postgres) | `public` |
| `dbt-clickhouse` | [Drex for ClickHouse](https://console.nace.ai/docs/integrations/clickhouse) | global (ClickHouse Cloud: the organization) |
| `dbt-duckdb` | [Drex for DuckDB](https://console.nace.ai/docs/integrations/duckdb) (in the profile, below) | the `drex` extension |

The key stays in the warehouse's secret store; dbt never sees it. Plain `dbt-spark` isn't supported: drex-spark's
Spark SQL functions exist only in a session that ran `drex_spark.register(spark)`. On Databricks, use
`dbt-databricks`, or a dbt Python model calling `drex_spark.functions`.

The package needs dbt 1.8 or later (dbt Core, or dbt Cloud on a 1.8+ version), and on DuckDB, dbt-duckdb 1.9.0 or
later with DuckDB 2.0, which needs Python 3.11 or later.

## Getting started

### 1. Add the package

In `packages.yml`:

```yaml
packages:
  - git: "https://github.com/nace-ai/dbt-drex.git"
    revision: v0.1.2
```

Then run `dbt deps`.

### 2. Point it at your functions

If your warehouse's setup put the functions somewhere other than the table above, say where in `dbt_project.yml`:

```yaml
vars:
  drex_database: analytics   # Snowflake database, Databricks catalog, or BigQuery project
  drex_schema: ml            # schema or dataset
```

#### DuckDB

dbt-duckdb loads the extension and creates the `nace` secret from your environment when it connects. In
`profiles.yml`:

```yaml
my_project:
  target: dev
  outputs:
    dev:
      type: duckdb
      path: my_project.duckdb
      extensions:
        - name: drex
          repo: community
      secrets:
        - type: nace
          provider: env
```

with `NACE_API_KEY` set in the environment dbt runs in. MotherDuck can't run the extension: see the DuckDB page.

### 3. Ask a question in a model

`models/ticket_teams.sql`:

```sql
select
    ticket_id,
    {{ drex.drex_choice("body", "Which team should handle this ticket?", {
        "billing": "Payments, invoices, refunds and charges",
        "technical": "Bugs, crashes and errors in the product",
        "sales": none,
    }) }} as team
from {{ ref("tickets") }}
```

`dbt run --select ticket_teams` sends each ticket's body once and keeps the answers in a table. On Snowflake it
compiles to `drex.public.drex_choice(body, '...', PARSE_JSON('[...]'))`; on DuckDB to
`prompt_drex(body, '...', choice := [...])`. ClickHouse's `drex_choice` takes plain labels, so there pass a list such
as `["billing", "technical", "sales"]`, or ask a described choice through `drex_decide`.

Answers come from the API and can vary. Keeping them in a table lets you query them without sending the rows again.

## Examples

### One question of each kind

```sql
select
    ticket_id,
    {{ drex.drex_noul("body", "Is the customer asking for a refund?") }} as refund,
    {{ drex.drex_score("body", "How urgent is this ticket?", ["can wait", "this week", "today"]) }} as urgency,
    {{ drex.drex_noul("body", "Is this ticket about a bug?", model="drex-max") }} as bug
from {{ ref("tickets") }}
```

Instructions, labels and the model are Jinja values, written in the model and checked when it compiles: a choice
with one label, a score level with a description, or a question id of `__proto__` fails `dbt compile` and names the
model file, before anything is sent.

### Filter on the answers

The result types differ by warehouse (`OBJECT`, `JSON`, `STRUCT`, `jsonb`, `Tuple`), so read them through the
accessors, which compile to each warehouse's field access:

```sql
select answers.ticket_id, {{ drex.drex_choice_value("answers.team") }} as team
from {{ ref("ticket_teams") }} as answers
where {{ drex.drex_confidence("answers.team") }} >= 0.8
```

Qualify the column, as here: on ClickHouse an alias is visible in the whole query, so after `as team` an unqualified
`team` is the label. Treat NULL as no answer, not as a "no".

### Several questions in one request

```sql
select
    ticket_id,
    {{ drex.drex_decide({"subject": "subject", "body": "body"}, {
        "refund": {"type": "noul", "instructions": "Is a refund needed?"},
        "team": {"type": "choice", "instructions": "Which team?", "criteria": {"billing": "Payments", "technical": none}},
    }) }} as decision
from {{ ref("tickets") }}
```

A dict `state` becomes a JSON object of the row's fields. That object is never NULL, so every row is sent and billed,
even one whose fields are all NULL: leave those rows out with a `where`. The result is Drex's whole response in the
warehouse's JSON type.

### Send only changed rows

See [Incremental models](docs/API.md#incremental-models): `drex_fingerprint` lets an incremental model send only
the rows whose input, question or model changed.

## What gets sent, and billed

Every row a Drex macro runs on is one request, and Drex bills every answered request; it keeps no answer cache.

- **Views and ephemeral models** run their Drex calls on every read, so the package warns when a Drex macro compiles
  into a `view`, `ephemeral`, `materialized_view` or `dynamic_table` model. Use `table` or `incremental`.
- **`dbt run` of a table model** sends all its rows again, and so does `--full-refresh` of an incremental one.
- **`dbt show --select`** runs the model's query rather than reading its table, so it sends rows again, at least the
  ones it shows. `dbt compile` and `dbt parse` send nothing.
- **A warehouse that runs work again bills again**: a retried task or a re-run query. Each warehouse's page says when
  that happens.
- Requests appear in your usage under the warehouse's integration (`drex-snowflake`, `drex-databricks`, ...), since
  the warehouse function sends them.

## Errors

The warehouse function decides what fails the query and what returns NULL: an invalid key or no funds fails the
query, and a row Drex refuses on its own returns NULL with a warning in the warehouse's log. Each warehouse page
lists its rules. The package adds the compile-time checks above.

## Development

The package is the dbt project at the root (`dbt_project.yml`, `macros/`). `test/` holds its tests, `integration_tests/`
the dbt project they run, and `test/mock/` drex-duckdb's mock of Drex's API (`drex_mock.py`), copied unchanged.

```bash
uv sync
uv run ruff check . && uv run ruff format --check .
uv run pytest            # compile tests on every adapter, and DuckDB end to end against the mock
```

`test/test_compile.py` compiles each model of `test/compile_project/` for every adapter, without connecting, and
compares the SQL with `test/expected/<adapter>/`; `DREX_UPDATE_EXPECTED=1` rewrites them. `test/test_doc_snippets.py`
builds every SQL example of this README and `docs/API.md` (and of the Drex docs page, when `DREX_DOCS_DBT_MDX` names
it) as a model. Postgres and ClickHouse run
end to end against the mock in Docker, set up as `.github/workflows/Tests.yml` does, and skip otherwise.

## Support and contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for local checks and pull requests, and the [Macro API](docs/API.md) for the
complete contract. Report bugs through [GitHub Issues](https://github.com/nace-ai/dbt-drex/issues), with
your dbt and adapter versions and a minimal model using synthetic data. Remove keys and private data from reports.

## License and trademarks

[MIT](LICENSE). Nace artwork belongs to Nace AI. The software license does not grant trademark rights.
See [asset sources and branding guidance](docs/assets/README.md).

This package is maintained by Nace AI. References to dbt and the warehouses describe compatibility, not sponsorship
or endorsement by their owners.

dbt is a trademark of dbt Labs, Inc. Snowflake, BigQuery, Databricks, PostgreSQL, ClickHouse and DuckDB are
trademarks of their respective owners.
