{#-
  drex_fingerprint(input, question=none, model=none): a hash of a row's `input` with the question asked about it, for
  incremental models that send only the rows whose fingerprint changed. `question` is any Jinja value holding what the
  Drex macro is given (instructions, labels, questions), and `model` the same model argument, read through
  var('drex_model') as the Drex macros read it. Changing the input, the question or the model changes the fingerprint;
  nothing else does. A NULL input has a fingerprint of its own, so a row that gains an input is sent.
-#}
{% macro drex_fingerprint(input, question=none, model=none) %}
  {% set input = drex._drex_expression("drex_fingerprint", "input", input) %}
  {% set asked = drex.drex_string_literal(tojson({
      "question": question,
      "model": drex._drex_model("drex_fingerprint", model),
  }, sort_keys=true)) %}
  {% set text = adapter.dispatch("drex_fingerprint_text", "drex")(input) %}
  {{ return(dbt.hash(dbt.concat([asked, "coalesce(" ~ dbt.concat(["'v'", text]) ~ ", 'n')"]))) }}
{% endmacro %}


{#- The input as text, whatever its type -#}
{% macro default__drex_fingerprint_text(input) %}
  {{ return("cast(" ~ input ~ " as " ~ dbt.type_string() ~ ")") }}
{% endmacro %}

{% macro snowflake__drex_fingerprint_text(input) %}
  {{ return("TO_JSON(TO_VARIANT(" ~ input ~ "))") }}
{% endmacro %}

{% macro bigquery__drex_fingerprint_text(input) %}
  {{ return("TO_JSON_STRING(" ~ input ~ ")") }}
{% endmacro %}

{% macro clickhouse__drex_fingerprint_text(input) %}
  {{ return("toString(" ~ input ~ ")") }}
{% endmacro %}
