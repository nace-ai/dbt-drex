{#- Where the warehouse functions live, which adapters this package supports, and cost warnings -#}

{#- Raised when a model compiles for its run, not while dbt parses the project, so a model disabled there can't fail -#}
{% macro _drex_unsupported() %}
  {% if not execute %}
    {{ return("NULL") }}
  {% endif %}
  {% if target.type == "spark" %}
    {{ exceptions.raise_compiler_error(
        "drex: dbt-spark isn't supported: drex-spark's Spark SQL functions exist only in a session that ran "
        ~ "drex_spark.register(spark), which a dbt connection can't run. On Databricks, use dbt-databricks with the "
        ~ "Unity Catalog functions, or a dbt Python model calling drex_spark.functions.") }}
  {% endif %}
  {{ exceptions.raise_compiler_error(
      "drex: the " ~ target.type ~ " adapter isn't supported; dbt-drex supports snowflake, bigquery, databricks, "
      ~ "postgres, clickhouse and duckdb") }}
{% endmacro %}


{#-
  The prefix of a warehouse function's name: `<database>.<schema>.` from var('drex_schema') and, where a function can
  live in another database (Snowflake, BigQuery, Databricks), var('drex_database'). Each defaults to where the
  warehouse's setup puts the functions, and is written as given; an empty string leaves that part out.
-#}
{% macro _drex_prefix(default_schema, default_database=none, uses_database=false) %}
  {% set schema = var("drex_schema", none) %}
  {% set parts = [] %}
  {% if uses_database %}
    {% set database = var("drex_database", none) %}
    {% do parts.append(default_database if database is none else database) %}
  {% endif %}
  {% do parts.append(default_schema if schema is none else schema) %}
  {% set parts = parts | select | list %}
  {{ return((parts | join(".") ~ ".") if parts else "") }}
{% endmacro %}

{% macro _drex_snowflake_prefix() %}
  {{ return(drex._drex_prefix("public", "drex", true)) }}
{% endmacro %}

{#- A BigQuery project id may hold hyphens, so it is quoted unless it already is -#}
{% macro _drex_bigquery_prefix() %}
  {% set project = var("drex_database", none) %}
  {% set schema = var("drex_schema", none) %}
  {% set schema = "drex" if schema is none else schema %}
  {% set parts = [] %}
  {% if project %}
    {% do parts.append(project if project.startswith("`") else "`" ~ project ~ "`") %}
  {% endif %}
  {% if schema %}
    {% do parts.append(schema) %}
  {% endif %}
  {{ return((parts | join(".") ~ ".") if parts else "") }}
{% endmacro %}

{% macro _drex_databricks_prefix() %}
  {% if target.type != "databricks" %}
    {% do drex._drex_unsupported() %}
  {% endif %}
  {{ return(drex._drex_prefix("drex", "main", true)) }}
{% endmacro %}

{#-
  Postgres calls a function in the database it's connected to. dbt dispatch walks an adapter's parents, so an adapter
  built on dbt-postgres (Redshift, Materialize, Greenplum, ...) reaches the postgres__ macros, and its database has no
  drex-postgres functions.
-#}
{% macro _drex_postgres_prefix() %}
  {% if target.type != "postgres" %}
    {% do drex._drex_unsupported() %}
  {% endif %}
  {{ return(drex._drex_prefix("public")) }}
{% endmacro %}


{#- A function call, `<prefix><name>(<arguments>)` -#}
{% macro _drex_call(prefix, name, arguments) %}
  {{ return(prefix ~ name ~ "(" ~ arguments | join(", ") ~ ")") }}
{% endmacro %}


{#-
  Every read of a view or an ephemeral model runs its Drex calls again, and Drex bills every row each time: warn when a
  Drex macro compiles into one.
-#}
{% macro _drex_warn_materialization(function) %}
  {% if not execute or model is not mapping or model.get("resource_type") != "model" %}
    {{ return(none) }}
  {% endif %}
  {% set materialized = model.get("config", {}).get("materialized") %}
  {% if materialized in ("view", "ephemeral", "materialized_view", "dynamic_table") %}
    {% do exceptions.warn(
        "drex: " ~ function ~ " in model " ~ model.get("name") ~ " (" ~ model.get("original_file_path") ~ "), materialized as "
        ~ materialized ~ ": every read of it sends every row to Drex again, and each answer is billed. Materialize it as "
        ~ "a table or an incremental model.") %}
  {% endif %}
{% endmacro %}


{#-
  `state` for drex_decide and drex_decide_image: a SQL expression of the warehouse's JSON type, or a dict of key to SQL
  expression, which becomes a JSON object of those values.
-#}
{% macro _drex_state(function, value) %}
  {% if value is mapping %}
    {% if value | length == 0 %}
      {% do drex._drex_fail(function, "state must have at least one key") %}
    {% endif %}
    {% for key, expression in value.items() %}
      {% if key is not string or key == "" %}
        {% do drex._drex_fail(function, "state keys must be non-empty text") %}
      {% endif %}
      {% do drex._drex_expression(function, "state." ~ key, expression) %}
    {% endfor %}
    {{ return(adapter.dispatch("drex_json_object", "drex")(value)) }}
  {% endif %}
  {{ return(drex._drex_expression(function, "state", value)) }}
{% endmacro %}


{#- drex_json_object: a JSON object of key to SQL expression, in the type each warehouse's drex_decide takes -#}

{% macro _drex_key_value_pairs(fields) %}
  {% set pairs = [] %}
  {% for key, expression in fields.items() %}
    {% do pairs.append(drex.drex_string_literal(key) ~ ", " ~ expression) %}
  {% endfor %}
  {{ return(pairs | join(", ")) }}
{% endmacro %}

{% macro default__drex_json_object(fields) %}
  {% do drex._drex_unsupported() %}
{% endmacro %}

{#- OBJECT_CONSTRUCT would leave out a NULL value; every other warehouse keeps it as JSON null -#}
{% macro snowflake__drex_json_object(fields) %}
  {{ return("OBJECT_CONSTRUCT_KEEP_NULL(" ~ drex._drex_key_value_pairs(fields) ~ ")") }}
{% endmacro %}

{% macro bigquery__drex_json_object(fields) %}
  {{ return("JSON_OBJECT(" ~ drex._drex_key_value_pairs(fields) ~ ")") }}
{% endmacro %}

{#- Databricks' functions take JSON as text; to_json would leave out a NULL field without ignoreNullFields -#}
{% macro spark__drex_json_object(fields) %}
  {{ return("to_json(named_struct(" ~ drex._drex_key_value_pairs(fields) ~ "), map('ignoreNullFields', 'false'))") }}
{% endmacro %}

{% macro postgres__drex_json_object(fields) %}
  {{ return("jsonb_build_object(" ~ drex._drex_key_value_pairs(fields) ~ ")") }}
{% endmacro %}

{#- ClickHouse's functions take JSON as text. toJSONString writes each value, but returns NULL for a NULL. -#}
{% macro clickhouse__drex_json_object(fields) %}
  {% set parts = [] %}
  {% for key, expression in fields.items() %}
    {% do parts.append(drex.drex_string_literal(("{" if loop.first else ",") ~ tojson(key) ~ ":")) %}
    {% do parts.append("ifNull(toJSONString(" ~ expression ~ "), 'null')") %}
  {% endfor %}
  {{ return("concat(" ~ parts | join(", ") ~ ", '}')") }}
{% endmacro %}

{% macro duckdb__drex_json_object(fields) %}
  {{ return("json_object(" ~ drex._drex_key_value_pairs(fields) ~ ")") }}
{% endmacro %}
