{#-
  Fields of a drex_choice or drex_score result, whose type differs by warehouse (OBJECT, JSON, STRUCT, jsonb, Tuple),
  as plain SQL values, so a model that filters on them compiles everywhere. A result with no answer reads as NULL.
-#}

{#- The chosen label, as text -#}
{% macro drex_choice_value(result) %}
  {{ return(adapter.dispatch("drex_field", "drex")(drex._drex_expression("drex_choice_value", "result", result), "choice", "text")) }}
{% endmacro %}

{#- The expected level index (0 for the first level), as a double -#}
{% macro drex_score_value(result) %}
  {{ return(adapter.dispatch("drex_field", "drex")(drex._drex_expression("drex_score_value", "result", result), "score", "number")) }}
{% endmacro %}

{#- Drex's confidence in a choice or score, as a double. A noul's is greatest(p, 1 - p). -#}
{% macro drex_confidence(result) %}
  {{ return(adapter.dispatch("drex_field", "drex")(drex._drex_expression("drex_confidence", "result", result), "confidence", "number")) }}
{% endmacro %}


{% macro default__drex_field(result, field, kind) %}
  {% do drex._drex_unsupported() %}
{% endmacro %}

{% macro snowflake__drex_field(result, field, kind) %}
  {{ return("GET(" ~ result ~ ", '" ~ field ~ "')::" ~ ("VARCHAR" if kind == "text" else "FLOAT")) }}
{% endmacro %}

{% macro bigquery__drex_field(result, field, kind) %}
  {% if kind == "text" %}
    {{ return("JSON_VALUE(" ~ result ~ ", '$." ~ field ~ "')") }}
  {% endif %}
  {{ return("LAX_FLOAT64(JSON_QUERY(" ~ result ~ ", '$." ~ field ~ "'))") }}
{% endmacro %}

{% macro spark__drex_field(result, field, kind) %}
  {% if target.type != "databricks" %}
    {% do drex._drex_unsupported() %}
  {% endif %}
  {{ return("(" ~ result ~ ")." ~ field) }}
{% endmacro %}

{% macro postgres__drex_field(result, field, kind) %}
  {% if target.type != "postgres" %}
    {% do drex._drex_unsupported() %}
  {% endif %}
  {% if kind == "text" %}
    {{ return("((" ~ result ~ ") ->> '" ~ field ~ "')") }}
  {% endif %}
  {{ return("((" ~ result ~ ") ->> '" ~ field ~ "')::double precision") }}
{% endmacro %}

{% macro clickhouse__drex_field(result, field, kind) %}
  {{ return("tupleElement(" ~ result ~ ", '" ~ field ~ "')") }}
{% endmacro %}

{% macro duckdb__drex_field(result, field, kind) %}
  {{ return("struct_extract(" ~ result ~ ", '" ~ field ~ "')") }}
{% endmacro %}
