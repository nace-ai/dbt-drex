{#-
  drex_decide(state, questions, model=none): Drex's whole response body (model, answers, usage, evaluation_time_ms,
  request_id) for `questions` about `state`, in the warehouse's JSON type. `state` is a SQL expression of that type, or
  a dict of key to SQL expression; `questions` is a dict of question id to {type, instructions, criteria}.
-#}
{% macro drex_decide(state, questions, model=none) %}
  {% set function = "drex_decide" %}
  {% do drex._drex_warn_materialization(function) %}
  {% set state = drex._drex_state(function, state) %}
  {% set questions = drex._drex_questions(function, questions) %}
  {% set model = drex._drex_model(function, model) %}
  {{ return(adapter.dispatch("drex_decide", "drex")(state, questions, model)) }}
{% endmacro %}

{% macro default__drex_decide(state, questions, model) %}
  {% do drex._drex_unsupported() %}
{% endmacro %}

{#- The arguments after `state` for Snowflake, Databricks and Postgres, whose model is optional -#}
{% macro _drex_decide_arguments(arguments, questions, model) %}
  {% do arguments.append(drex.drex_json_literal(drex._drex_questions_json(questions))) %}
  {% if model is not none %}
    {% do arguments.append(drex.drex_string_literal(model)) %}
  {% endif %}
  {{ return(arguments) }}
{% endmacro %}

{% macro snowflake__drex_decide(state, questions, model) %}
  {{ return(drex._drex_call(drex._drex_snowflake_prefix(), "drex_decide", drex._drex_decide_arguments([state], questions, model))) }}
{% endmacro %}

{% macro bigquery__drex_decide(state, questions, model) %}
  {{ return(drex._drex_call(drex._drex_bigquery_prefix(), "decide", [
      state, drex.drex_json_literal(drex._drex_questions_json(questions)), "NULL" if model is none else drex.drex_string_literal(model)])) }}
{% endmacro %}

{% macro spark__drex_decide(state, questions, model) %}
  {{ return(drex._drex_call(drex._drex_databricks_prefix(), "drex_decide", drex._drex_decide_arguments([state], questions, model))) }}
{% endmacro %}

{% macro postgres__drex_decide(state, questions, model) %}
  {{ return(drex._drex_call(drex._drex_postgres_prefix(), "drex_decide", drex._drex_decide_arguments([state], questions, model))) }}
{% endmacro %}

{% macro clickhouse__drex_decide(state, questions, model) %}
  {{ return(drex._drex_call("", "drex_decide", [state, drex.drex_json_literal(drex._drex_questions_json(questions)), drex.drex_string_literal(model or "")])) }}
{% endmacro %}

{#- drex-duckdb's drex_decide sends questions to Drex as they are, so they take Drex's own form -#}
{% macro duckdb__drex_decide(state, questions, model) %}
  {% set arguments = [state, drex.drex_json_literal(drex._drex_questions_json(questions, native=true))] %}
  {% if model is not none %}
    {% do arguments.append("model := " ~ drex.drex_string_literal(model)) %}
  {% endif %}
  {{ return(drex._drex_call("", "drex_decide", arguments)) }}
{% endmacro %}
