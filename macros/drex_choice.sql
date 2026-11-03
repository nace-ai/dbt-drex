{#-
  drex_choice(input, instructions, labels, model=none): which of `labels` answers `instructions` about `input`, as the
  warehouse's native {choice, probabilities: [{value, probability}], confidence}. Read it with drex_choice_value and
  drex_confidence.
-#}
{% macro drex_choice(input, instructions, labels, model=none) %}
  {% set function = "drex_choice" %}
  {% do drex._drex_warn_materialization(function) %}
  {% set input = drex._drex_expression(function, "input", input) %}
  {% set question = drex._drex_question(function, "the question", "choice", drex._drex_instructions(function, instructions),
      labels, "labels") %}
  {% set model = drex._drex_model(function, model) %}
  {{ return(adapter.dispatch("drex_choice", "drex")(input, question, model)) }}
{% endmacro %}

{% macro default__drex_choice(input, question, model) %}
  {% do drex._drex_unsupported() %}
{% endmacro %}

{% macro snowflake__drex_choice(input, question, model) %}
  {{ return(drex._drex_call(drex._drex_snowflake_prefix(), "drex_choice", drex._drex_labelled_arguments(input, question, model))) }}
{% endmacro %}

{% macro bigquery__drex_choice(input, question, model) %}
  {{ return(drex._drex_bigquery_labelled("choice", input, question, model)) }}
{% endmacro %}

{% macro spark__drex_choice(input, question, model) %}
  {{ return(drex._drex_call(drex._drex_databricks_prefix(), "drex_choice", drex._drex_labelled_arguments(input, question, model))) }}
{% endmacro %}

{% macro postgres__drex_choice(input, question, model) %}
  {{ return(drex._drex_call(drex._drex_postgres_prefix(), "drex_choice", drex._drex_labelled_arguments(input, question, model))) }}
{% endmacro %}

{% macro clickhouse__drex_choice(input, question, model) %}
  {{ return(drex._drex_clickhouse_labelled("drex_choice", input, question, model)) }}
{% endmacro %}

{% macro duckdb__drex_choice(input, question, model) %}
  {{ return(drex._drex_duckdb_labelled("choice", input, question, model)) }}
{% endmacro %}


{#- The arguments of a choice or score for Snowflake, Databricks and Postgres, whose model is optional -#}
{% macro _drex_labelled_arguments(input, question, model) %}
  {% set arguments = [input, drex.drex_string_literal(question.instructions), drex.drex_json_literal(drex._drex_criteria_json(question))] %}
  {% if model is not none %}
    {% do arguments.append(drex.drex_string_literal(model)) %}
  {% endif %}
  {{ return(arguments) }}
{% endmacro %}

{#- BigQuery's routines have no drex_ prefix, and NULL model is the default -#}
{% macro _drex_bigquery_labelled(name, input, question, model) %}
  {{ return(drex._drex_call(drex._drex_bigquery_prefix(), name, [
      input,
      drex.drex_string_literal(question.instructions),
      drex.drex_json_literal(drex._drex_criteria_json(question)),
      "NULL" if model is none else drex.drex_string_literal(model),
  ])) }}
{% endmacro %}

{#- ClickHouse takes plain labels as an Array(String), and '' model is the default -#}
{% macro _drex_clickhouse_labelled(name, input, question, model) %}
  {% if execute and question.labels | rejectattr("description", "none") | list | length > 0 %}
    {% do drex._drex_fail(name, "ClickHouse's " ~ name ~ " takes plain labels; for labels with descriptions, use "
        ~ "drex_decide with a choice question") %}
  {% endif %}
  {{ return(drex._drex_call("", name, [
      input,
      drex.drex_string_literal(question.instructions),
      drex._drex_label_list(question.labels),
      drex.drex_string_literal(model or ""),
  ])) }}
{% endmacro %}

{#- prompt_drex with `choice :=` or `score :=` -#}
{% macro _drex_duckdb_labelled(mode, input, question, model) %}
  {% set arguments = [input, drex.drex_string_literal(question.instructions), mode ~ " := " ~ drex._drex_duckdb_criteria(question.labels)] %}
  {% if model is not none %}
    {% do arguments.append("model := " ~ drex.drex_string_literal(model)) %}
  {% endif %}
  {{ return(drex._drex_call("", "prompt_drex", arguments)) }}
{% endmacro %}
