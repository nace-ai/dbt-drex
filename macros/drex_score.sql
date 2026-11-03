{#-
  drex_score(input, instructions, levels, model=none): where `input` falls on the scale `levels` (a list, in order), as
  the warehouse's native {score, probabilities: [{index, value, probability}], confidence}. Read it with
  drex_score_value and drex_confidence.
-#}
{% macro drex_score(input, instructions, levels, model=none) %}
  {% set function = "drex_score" %}
  {% do drex._drex_warn_materialization(function) %}
  {% set input = drex._drex_expression(function, "input", input) %}
  {% set question = drex._drex_question(function, "the question", "score", drex._drex_instructions(function, instructions),
      levels, "levels") %}
  {% set model = drex._drex_model(function, model) %}
  {{ return(adapter.dispatch("drex_score", "drex")(input, question, model)) }}
{% endmacro %}

{% macro default__drex_score(input, question, model) %}
  {% do drex._drex_unsupported() %}
{% endmacro %}

{% macro snowflake__drex_score(input, question, model) %}
  {{ return(drex._drex_call(drex._drex_snowflake_prefix(), "drex_score", drex._drex_labelled_arguments(input, question, model))) }}
{% endmacro %}

{% macro bigquery__drex_score(input, question, model) %}
  {{ return(drex._drex_bigquery_labelled("score", input, question, model)) }}
{% endmacro %}

{% macro spark__drex_score(input, question, model) %}
  {{ return(drex._drex_call(drex._drex_databricks_prefix(), "drex_score", drex._drex_labelled_arguments(input, question, model))) }}
{% endmacro %}

{% macro postgres__drex_score(input, question, model) %}
  {{ return(drex._drex_call(drex._drex_postgres_prefix(), "drex_score", drex._drex_labelled_arguments(input, question, model))) }}
{% endmacro %}

{% macro clickhouse__drex_score(input, question, model) %}
  {{ return(drex._drex_clickhouse_labelled("drex_score", input, question, model)) }}
{% endmacro %}

{% macro duckdb__drex_score(input, question, model) %}
  {{ return(drex._drex_duckdb_labelled("score", input, question, model)) }}
{% endmacro %}
