{#- SQL literals of Jinja values, escaped as each warehouse reads them -#}

{#- A string literal -#}
{% macro drex_string_literal(value) %}
  {{ return(adapter.dispatch("drex_string_literal", "drex")(value)) }}
{% endmacro %}

{#- Postgres and DuckDB: standard strings, where only a quote is doubled -#}
{% macro default__drex_string_literal(value) %}
  {{ return("'" ~ value | replace("'", "''") ~ "'") }}
{% endmacro %}

{#- Snowflake, BigQuery, Databricks and ClickHouse read backslash escapes in a string -#}
{% macro drex_backslash_string_literal(value) %}
  {{ return("'" ~ value | replace("\\", "\\\\") | replace("'", "\\'") | replace("\n", "\\n") | replace("\r", "\\r") ~ "'") }}
{% endmacro %}

{% macro snowflake__drex_string_literal(value) %}
  {{ return(drex.drex_backslash_string_literal(value)) }}
{% endmacro %}

{% macro bigquery__drex_string_literal(value) %}
  {{ return(drex.drex_backslash_string_literal(value)) }}
{% endmacro %}

{% macro spark__drex_string_literal(value) %}
  {{ return(drex.drex_backslash_string_literal(value)) }}
{% endmacro %}

{% macro clickhouse__drex_string_literal(value) %}
  {{ return(drex.drex_backslash_string_literal(value)) }}
{% endmacro %}


{#- A JSON value, in the type the warehouse's functions take for labels, criteria and questions -#}
{% macro drex_json_literal(value) %}
  {{ return(adapter.dispatch("drex_json_literal", "drex")(tojson(value))) }}
{% endmacro %}

{% macro default__drex_json_literal(text) %}
  {{ return(drex.drex_string_literal(text)) }}
{% endmacro %}

{% macro snowflake__drex_json_literal(text) %}
  {{ return("PARSE_JSON(" ~ drex.drex_string_literal(text) ~ ")") }}
{% endmacro %}

{% macro bigquery__drex_json_literal(text) %}
  {{ return("JSON " ~ drex.drex_string_literal(text)) }}
{% endmacro %}

{% macro postgres__drex_json_literal(text) %}
  {{ return(drex.drex_string_literal(text) ~ "::jsonb") }}
{% endmacro %}

{% macro duckdb__drex_json_literal(text) %}
  {{ return(drex.drex_string_literal(text) ~ "::JSON") }}
{% endmacro %}


{#- A ClickHouse Array(String) or a DuckDB VARCHAR[] of labels -#}
{% macro _drex_label_list(labels) %}
  {% set items = [] %}
  {% for label in labels %}
    {% do items.append(drex.drex_string_literal(label.label)) %}
  {% endfor %}
  {{ return("[" ~ items | join(", ") ~ "]") }}
{% endmacro %}


{#- A DuckDB list of labels: VARCHAR[] without descriptions, else STRUCT(label, description)[] -#}
{% macro _drex_duckdb_criteria(labels) %}
  {% if labels | rejectattr("description", "none") | list | length == 0 %}
    {{ return(drex._drex_label_list(labels)) }}
  {% endif %}
  {% set items = [] %}
  {% for label in labels %}
    {% set description = "NULL" if label.description is none else drex.drex_string_literal(label.description) %}
    {% do items.append("{'label': " ~ drex.drex_string_literal(label.label) ~ ", 'description': " ~ description ~ "}") %}
  {% endfor %}
  {{ return("[" ~ items | join(", ") ~ "]") }}
{% endmacro %}
