# Macro API

Each Drex macro compiles to a call of the Drex function your warehouse already has: the Drex integration you
installed there (see [Before you start](../README.md#before-you-start)). The macros don't call Drex themselves. The
warehouse function sends each row and returns the answer in the warehouse's own types.

| Macro | Result |
| --- | --- |
| `drex.drex_noul(input, instructions=none, criteria=none, model=none)` | The probability, from 0 to 1, that the answer is yes |
| `drex.drex_choice(input, instructions, labels, model=none)` | `{choice, probabilities: [{value, probability}], confidence}`, probabilities sorted by label |
| `drex.drex_score(input, instructions, levels, model=none)` | `{score, probabilities: [{index, value, probability}], confidence}`, probabilities by index |
| `drex.drex_decide(state, questions, model=none)` | Drex's whole response body: `model`, `answers`, `usage`, `evaluation_time_ms`, `request_id` |
| `drex.drex_decide_image(state, images, questions, model=none)` | The same, for questions about up to 8 images, with Drex Max by default |
| `drex.drex_choice_value(result)` | A choice result's label, as text |
| `drex.drex_score_value(result)` | A score result's expected level index (0 for the first level), as a double |
| `drex.drex_confidence(result)` | A choice or score result's confidence, as a double |
| `drex.drex_fingerprint(input, question=none, model=none)` | A hash of the input and the question, for [incremental models](#incremental-models) |

## Arguments

`input`, `state`, `images` and `result` are SQL, such as a column name: `'body'`, `'tickets.body'`. Every other
argument is a Jinja value, written in the model file and rendered into the SQL, because every warehouse requires
instructions, labels, questions and the model to be constants. A column there is refused when the model compiles.

- **`input`**: text. A NULL input returns NULL and sends nothing. On Databricks and ClickHouse a choice or score result
  can't itself be NULL, so it is a struct or tuple whose fields are NULL: test it through the accessors. For
  structured state, use `drex_decide`.
- **`instructions`**: text. `none` or `''` means no instructions. A `noul` needs instructions, or a description of
  `true` or `false`.
- **`criteria`, `labels`, `levels`**: one of three shapes.
  - A list of labels: `["billing", "technical"]`.
  - A list of `{"label": ..., "description": ...}`, where the description may be `none` or left out.
  - A dict of label to description (`none` for no description), except for `levels`.

  Labels are text; YAML's and Jinja's `true`, `false` and integers are read as `"true"`, `"false"` and `"3"`. dbt's
  YAML (`dbt_project.yml` vars, `--vars`) also reads unquoted `yes`, `no`, `on` and `off` as booleans, so
  `[yes, no, maybe]` is sent as `"true"`, `"false"` and `"maybe"`: quote such labels.
  - `noul` labels are exactly `true` and `false`. A list names both; a dict may describe one. Labels with no
    description are the same as no criteria.
  - `choice` and `score` take 2 to 255 unique, non-empty labels, sent in the order written.
  - `levels` take no descriptions (describe the scale in `instructions`), and their order is the scale.
- **`questions`**: a dict of question id to `{"type", "instructions", "criteria"}`.
  - 1 to 512 questions. Ids are non-empty after trimming, unique ignoring case, and not `__proto__`.
  - `type` is `noul`, `choice` or `score`; `multiple_choice` and `box` are refused by name, as is any other key.
  - `criteria` takes the shapes above. A `choice` or `score` needs criteria.
- **`state`**: a SQL expression of the warehouse's JSON type (below), or a dict of key to SQL expression, which
  becomes a JSON object of those values, with NULL as `null`:
  `drex.drex_decide({"subject": "subject", "body": "body"}, questions)`. That object is never NULL, so every row is
  sent and billed, even one whose values are all NULL; leave those rows out with a `where`.
- **`images`**: a SQL expression in the warehouse's image form (below).
- **`model`**: a model name, such as `'drex-max'`. `none` or `''` is `var('drex_model')`, and with that unset the
  warehouse function's default, `drex-v2.0`. `drex_decide_image` ignores `var('drex_model')` and defaults to
  `drex-max`, since the default text model doesn't read images. The warehouse checks the name against
  `GET /v1/models` when the query runs.

A macro whose arguments break a rule fails `dbt compile`, `run` and `build` with
`Compilation Error in model <name> (<path>)` and the rule, before anything reaches the warehouse. The messages are
drex-duckdb's.

## What each warehouse gets

| Adapter | Calls | Labels and questions | `model` left out | `choice` and `score` result |
| --- | --- | --- | --- | --- |
| `snowflake` | `drex.public.drex_choice(...)` | `PARSE_JSON('...')` | omitted | `OBJECT` |
| `bigquery` | `drex.choice(...)` | `JSON '...'` | `NULL` | `JSON` |
| `databricks` | `main.drex.drex_choice(...)` | JSON text | omitted | `STRUCT` |
| `postgres` | `public.drex_choice(...)` | `'...'::jsonb` | omitted | `jsonb` |
| `clickhouse` | `drex_choice(...)` | `Array(String)` labels; JSON text criteria and questions | `''` | `Tuple(...)` |
| `duckdb` | `prompt_drex(..., choice := [...])`, `drex_decide(...)` | DuckDB lists and structs; `'...'::JSON` questions | omitted | `STRUCT` |

`drex_noul` returns a double everywhere, and `drex_decide` and `drex_decide_image` return each warehouse's JSON:
`OBJECT` (Snowflake), `JSON` (BigQuery, DuckDB), JSON text in a `STRING` (Databricks, read it with `parse_json` or
`from_json`), `jsonb` (Postgres), and JSON text in a `Nullable(String)` (ClickHouse).

On Postgres, the macros write standard string literals, where only a quote is doubled, so they need
`standard_conforming_strings` on, Postgres's default since 9.1. drex-postgres's functions need it too: with it off,
every call fails.

| Adapter | `state` | `images` |
| --- | --- | --- |
| `snowflake` | `VARIANT` or `OBJECT` (a `VARCHAR` is sent as text) | A scoped file URL from `BUILD_SCOPED_FILE_URL`, or an `ARRAY` of them |
| `bigquery` | `JSON` | A `JSON` signed URL, or array of them, from `EXTERNAL_OBJECT_TRANSFORM(..., ['SIGNED_URL'])` |
| `databricks` | JSON text | `ARRAY<BINARY>` |
| `postgres` | `jsonb` | `bytea[]` |
| `clickhouse` | JSON text | `Array(String)` of image bytes |
| `duckdb` | `JSON` | not available (below) |

Where each warehouse's setup put the functions is the default location. Set it with these vars in your
`dbt_project.yml`:

| Var | Default | Used by |
| --- | --- | --- |
| `drex_database` | `drex` (Snowflake), `main` (Databricks), the query's project (BigQuery) | Snowflake, Databricks, BigQuery (a project id, quoted for you) |
| `drex_schema` | `public` (Snowflake, Postgres), `drex` (Databricks, BigQuery) | Snowflake, Databricks, BigQuery, Postgres |
| `drex_model` | none: the function's default | every macro but `drex_decide_image` |

Each is written into the SQL as given, and `''` leaves that part of the name out. ClickHouse's functions are
global and DuckDB's are the extension's, so neither uses a location.

### Adapter limits

- **ClickHouse**: `drex_choice` and `drex_score` take plain labels. A choice with descriptions fails to compile and
  names `drex_decide`, whose `choice` questions take them. A ClickHouse alias is visible in the whole query, so in
  `select {{ drex.drex_choice_value("team") }} as team ... where {{ drex.drex_confidence("team") }} >= 0.8` the second
  `team` is the label, and the query fails: qualify the column (`answers.team`), as [Reading results](#reading-results)
  does.
- **DuckDB**: drex-duckdb has no `drex_decide_image`, since its `drex_decide` takes JSON state alone, so the macro
  fails to compile on DuckDB. Ask about images with `prompt_drex(image_blobs, ..., model := 'drex-max')` in a
  DuckDB-only model. drex-duckdb's `drex_decide` sends questions to Drex as they are, so the macro writes them in
  Drex's own form there (a choice's criteria as an object of label to description); the other warehouses convert
  the shapes above themselves. A `noul :=` list names both labels, so a dict that describes one gains the other
  without a description, which Drex reads the same way.
- **dbt-spark**: not supported. drex-spark's Spark SQL functions exist only in a session that ran
  `drex_spark.register(spark)`, which a dbt connection can't run. Use dbt-databricks with the Unity Catalog
  functions, or a dbt Python model calling `drex_spark.functions`.
- **Other adapters** fail to compile and name the supported ones, including adapters built on dbt-postgres (Redshift,
  Materialize, Greenplum), whose databases don't have drex-postgres's functions.

## Reading results

A choice or score result's type differs by warehouse, so a model that filters on it reads it through the accessors:

```sql
select
    answers.ticket_id,
    {{ drex.drex_choice_value("answers.team") }} as team,
    {{ drex.drex_confidence("answers.team") }} as team_confidence,
    {{ drex.drex_score_value("answers.urgency") }} as urgency
from {{ ref("ticket_answers") }} as answers
where {{ drex.drex_confidence("answers.team") }} >= 0.8
```

Each returns NULL for a row with no answer: a NULL input, or a row the warehouse function returned NULL for. Qualify
the columns, as here, for ClickHouse (see [Adapter limits](#adapter-limits)). A noul's result is the probability `p`
itself, which the accessors don't take; its confidence is `greatest(p, 1 - p)`.

## Incremental models

Every row a Drex macro runs on is a request, and every answer is billed. An incremental model sends only the rows
whose input, question or model changed, by keeping the fingerprint each row was answered with:

```sql
{{ config(materialized="incremental", unique_key="ticket_id") }}

{% set team = {"instructions": "Which team should handle this ticket?", "labels": ["billing", "technical", "sales"]} %}

with tickets as (
    select ticket_id, body, {{ drex.drex_fingerprint("body", team) }} as drex_fingerprint
    from {{ ref("tickets") }}
)

select
    tickets.ticket_id,
    tickets.drex_fingerprint,
    {{ drex.drex_choice("tickets.body", team.instructions, team.labels) }} as team
from tickets
{% if is_incremental() %}
left join {{ this }} as answered on answered.ticket_id = tickets.ticket_id
where answered.drex_fingerprint is null or answered.drex_fingerprint <> tickets.drex_fingerprint
{% endif %}
```

`drex_fingerprint(input, question, model)` hashes the input with `question` (any Jinja value: here the dict the
macro's arguments come from) and the model, read through `var('drex_model')` as the macros read it. Pass it the same
`model` as the Drex macro. `drex_decide_image` doesn't read `var('drex_model')`, so for it pass the same explicit
`model` to both macros (for example `model="drex-max"`): otherwise changing the var changes the fingerprint, and the
next run sends every image again. Changing the instructions, labels or model sends every row again; nothing else does. A
NULL input has a fingerprint of its own, so a row that gains a body is sent. Rows deleted from the source stay in
the model. `--full-refresh` sends every row again.

A row whose answer is NULL (Drex refused it, or its retries ran out) keeps its fingerprint too, so it isn't asked
again until its input, question or model changes. Drex bills only the requests it answers, so to ask those rows again
on each run, add this to the `where`:

```sql
or (tickets.body is not null and {{ drex.drex_choice_value("answered.team") }} is null)
```

## Cost warnings

Every read of a view or an ephemeral model runs its Drex calls again, and each answer is billed. A Drex macro in a
model materialized as `view`, `ephemeral`, `materialized_view` or `dynamic_table` logs a warning when it compiles:

```text
drex: drex_noul in model refunds (models/refunds.sql), materialized as view: every read of it sends every row to
Drex again, and each answer is billed. Materialize it as a table or an incremental model.
```

`dbt build --warn-error` turns it into an error. Running a table model again sends its rows again too, and so does
`dbt show --select` of it, which runs the model's query rather than reading the table.

## Overriding a macro

Each macro is `adapter.dispatch(..., "drex")`, so a project can replace one warehouse's implementation, for example
to call functions installed under other names:

```yaml
# dbt_project.yml
dispatch:
  - macro_namespace: drex
    search_order: ["my_project", "drex"]
```

and define `snowflake__drex_choice(input, question, model)` in `my_project`. The implementations receive the
arguments already checked; `question.labels` holds `{label, description}` dicts.
