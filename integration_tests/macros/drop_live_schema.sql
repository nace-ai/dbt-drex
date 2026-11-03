{#- Drops the target's schema, which the live runs build their models in: `dbt run-operation drop_live_schema` -#}
{% macro drop_live_schema() %}
  {% do adapter.drop_schema(api.Relation.create(database=target.database, schema=target.schema)) %}
  {% do log("dropped " ~ target.database ~ "." ~ target.schema, info=true) %}
{% endmacro %}
