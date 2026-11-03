{#-
  drex_decide_image(state, images, questions, model=none): drex_decide about `state` and up to 8 images, with Drex Max
  (the warehouse function's default) unless `model` names another image model. var('drex_model') doesn't apply, since
  the default text model doesn't read images. `images` is a SQL expression of the warehouse's image argument.
-#}
{% macro drex_decide_image(state, images, questions, model=none) %}
  {% set function = "drex_decide_image" %}
  {% do drex._drex_warn_materialization(function) %}
  {% set state = drex._drex_state(function, state) %}
  {% set images = drex._drex_expression(function, "images", images) %}
  {% set questions = drex._drex_questions(function, questions) %}
  {% set model = drex._drex_model(function, model, use_var=false) %}
  {{ return(adapter.dispatch("drex_decide_image", "drex")(state, images, questions, model)) }}
{% endmacro %}

{% macro default__drex_decide_image(state, images, questions, model) %}
  {% do drex._drex_unsupported() %}
{% endmacro %}

{#- `images`: a scoped file URL from BUILD_SCOPED_FILE_URL, or an ARRAY of them -#}
{% macro snowflake__drex_decide_image(state, images, questions, model) %}
  {{ return(drex._drex_call(drex._drex_snowflake_prefix(), "drex_decide_image", drex._drex_decide_arguments([state, images], questions, model))) }}
{% endmacro %}

{#- `images`: a JSON signed URL, or a JSON array of them, from EXTERNAL_OBJECT_TRANSFORM(..., ['SIGNED_URL']) -#}
{% macro bigquery__drex_decide_image(state, images, questions, model) %}
  {{ return(drex._drex_call(drex._drex_bigquery_prefix(), "decide_image", [
      state, images, drex.drex_json_literal(drex._drex_questions_json(questions)), "NULL" if model is none else drex.drex_string_literal(model)])) }}
{% endmacro %}

{#- `images`: an ARRAY<BINARY> -#}
{% macro spark__drex_decide_image(state, images, questions, model) %}
  {{ return(drex._drex_call(drex._drex_databricks_prefix(), "drex_decide_image", drex._drex_decide_arguments([state, images], questions, model))) }}
{% endmacro %}

{#- `images`: a bytea[] -#}
{% macro postgres__drex_decide_image(state, images, questions, model) %}
  {{ return(drex._drex_call(drex._drex_postgres_prefix(), "drex_decide_image", drex._drex_decide_arguments([state, images], questions, model))) }}
{% endmacro %}

{#- `images`: an Array(String) of image bytes -#}
{% macro clickhouse__drex_decide_image(state, images, questions, model) %}
  {{ return(drex._drex_call("", "drex_decide_image", [state, images, drex.drex_json_literal(drex._drex_questions_json(questions)), drex.drex_string_literal(model or "")])) }}
{% endmacro %}

{#- drex-duckdb asks about images through prompt_drex alone, which takes them in place of state -#}
{% macro duckdb__drex_decide_image(state, images, questions, model) %}
  {% if not execute %}
    {{ return("NULL") }}
  {% endif %}
  {{ exceptions.raise_compiler_error(
      "drex_decide_image: drex-duckdb has no drex_decide_image, since its drex_decide takes JSON state alone. Ask "
      ~ "about images with prompt_drex(image_blobs, ..., model := 'drex-max') in a DuckDB-only model.") }}
{% endmacro %}
