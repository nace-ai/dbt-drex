{#-
  drex_noul(input, instructions, criteria=none, model=none): the probability, from 0 to 1, that the answer to
  `instructions` about `input` is yes. `input` is a SQL expression of text; `criteria` describes true and false.
-#}
{% macro drex_noul(input, instructions=none, criteria=none, model=none) %}
  {% set function = "drex_noul" %}
  {% do drex._drex_warn_materialization(function) %}
  {% set input = drex._drex_expression(function, "input", input) %}
  {% set question = drex._drex_question(function, "the question", "noul", drex._drex_instructions(function, instructions),
      criteria, "criteria") %}
  {% set model = drex._drex_model(function, model) %}
  {{ return(adapter.dispatch("drex_noul", "drex")(input, question, model)) }}
{% endmacro %}

{% macro default__drex_noul(input, question, model) %}
  {% do drex._drex_unsupported() %}
{% endmacro %}

{#- Optional arguments that are omitted, or NULL before a model, for Snowflake, Databricks and Postgres -#}
{% macro _drex_noul_arguments(input, question, model) %}
  {% set criteria = drex._drex_criteria_json(question) %}
  {% set arguments = [input, drex.drex_string_literal(question.instructions)] %}
  {% if criteria is not none or model is not none %}
    {% do arguments.append("NULL" if criteria is none else drex.drex_json_literal(criteria)) %}
  {% endif %}
  {% if model is not none %}
    {% do arguments.append(drex.drex_string_literal(model)) %}
  {% endif %}
  {{ return(arguments) }}
{% endmacro %}

{% macro snowflake__drex_noul(input, question, model) %}
  {{ return(drex._drex_call(drex._drex_snowflake_prefix(), "drex_noul", drex._drex_noul_arguments(input, question, model))) }}
{% endmacro %}

{% macro spark__drex_noul(input, question, model) %}
  {{ return(drex._drex_call(drex._drex_databricks_prefix(), "drex_noul", drex._drex_noul_arguments(input, question, model))) }}
{% endmacro %}

{% macro postgres__drex_noul(input, question, model) %}
  {{ return(drex._drex_call(drex._drex_postgres_prefix(), "drex_noul", drex._drex_noul_arguments(input, question, model))) }}
{% endmacro %}

{#- Every argument is required; NULL criteria is none, and NULL model the default -#}
{% macro bigquery__drex_noul(input, question, model) %}
  {% set criteria = drex._drex_criteria_json(question) %}
  {{ return(drex._drex_call(drex._drex_bigquery_prefix(), "noul", [
      input,
      drex.drex_string_literal(question.instructions),
      "NULL" if criteria is none else drex.drex_json_literal(criteria),
      "NULL" if model is none else drex.drex_string_literal(model),
  ])) }}
{% endmacro %}

{#- Every argument is required; '' criteria is none, and '' model the default -#}
{% macro clickhouse__drex_noul(input, question, model) %}
  {% set criteria = drex._drex_criteria_json(question) %}
  {{ return(drex._drex_call("", "drex_noul", [
      input,
      drex.drex_string_literal(question.instructions),
      "''" if criteria is none else drex.drex_json_literal(criteria),
      drex.drex_string_literal(model or ""),
  ])) }}
{% endmacro %}

{#-
  prompt_drex's default mode is a noul. Its `noul :=` takes a list, which names both true and false, so a dict that
  describes only one gains the other without a description, which Drex reads the same way.
-#}
{% macro duckdb__drex_noul(input, question, model) %}
  {% set arguments = [input, drex.drex_string_literal(question.instructions)] %}
  {% set criteria = drex._drex_criteria_json(question) %}
  {% if criteria is not none %}
    {% set labels = [] %}
    {% for label in ["true", "false"] %}
      {% do labels.append({"label": label, "description": criteria.get(label)}) %}
    {% endfor %}
    {% do arguments.append("noul := " ~ drex._drex_duckdb_criteria(labels)) %}
  {% endif %}
  {% if model is not none %}
    {% do arguments.append("model := " ~ drex.drex_string_literal(model)) %}
  {% endif %}
  {{ return(drex._drex_call("", "prompt_drex", arguments)) }}
{% endmacro %}
