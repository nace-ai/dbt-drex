{#-
  The arguments every Drex macro shares, checked at compile time as drex-duckdb checks them at bind time, with its
  messages. Labels, criteria and questions are Jinja values, never SQL: every warehouse requires them to be
  constants, and a value that compiles is one each warehouse accepts.
-#}

{% macro _drex_fail(function, message) %}
  {{ exceptions.raise_compiler_error(function ~ ": " ~ message) }}
{% endmacro %}


{#- `input` and `state` are SQL expressions, such as a column name -#}
{% macro _drex_expression(function, name, value) %}
  {% if value is not string or value | trim == "" %}
    {% do drex._drex_fail(function, name ~ " must be a SQL expression, such as a column name") %}
  {% endif %}
  {{ return(value) }}
{% endmacro %}


{#- `instructions` is text; none or '' is no instructions -#}
{% macro _drex_instructions(function, value) %}
  {% if value is none %}
    {{ return("") }}
  {% elif value is not string %}
    {% do drex._drex_fail(function, "instructions must be text, not " ~ value) %}
  {% endif %}
  {{ return(value) }}
{% endmacro %}


{#-
  The model: the argument, else (when `use_var`) var('drex_model'), where none or '' is not given. Returns none for the
  warehouse function's default, drex-v2.0, or drex-max for drex_decide_image.
-#}
{% macro _drex_model(function, value, use_var=true) %}
  {% if (value is none or value == "") and use_var %}
    {% set value = var("drex_model", none) %}
  {% endif %}
  {% if value is none or value == "" %}
    {{ return(none) }}
  {% elif value is not string %}
    {% do drex._drex_fail(function, "model must be a model name, such as 'drex-max', not " ~ value) %}
  {% endif %}
  {{ return(value) }}
{% endmacro %}


{#- A label as text: a string, or a boolean or integer as YAML and Jinja write them (true, 3) -#}
{% macro _drex_label_text(function, name, value, shape_error) %}
  {% if value is string %}
    {{ return(value) }}
  {% elif value is sameas true %}
    {{ return("true") }}
  {% elif value is sameas false %}
    {{ return("false") }}
  {% elif value is integer %}
    {{ return(value | string) }}
  {% elif value is none %}
    {% do drex._drex_fail(function, name ~ " must not hold a NULL label") %}
  {% endif %}
  {% do drex._drex_fail(function, shape_error) %}
{% endmacro %}


{% macro _drex_description(function, value, shape_error) %}
  {% if value is none or value is string %}
    {{ return(value) }}
  {% endif %}
  {% do drex._drex_fail(function, shape_error) %}
{% endmacro %}


{#-
  The labels of `criteria`, `labels`, `levels` or a question's `criteria`, in drex-duckdb's three shapes: a list of
  labels, a list of {label, description}, or (when allow_object) a dict of label to description. Returns
  {labels: [{label, description}], from_object}; none is no labels.
-#}
{% macro _drex_labels(function, name, value, allow_object) %}
  {% set shape_error = name ~ " must be a list of labels or of {label, description}"
      ~ (", or a dict of label to description" if allow_object else "") %}
  {% set labels = [] %}
  {% if value is none %}
    {{ return({"labels": labels, "from_object": false}) }}
  {% elif value is mapping %}
    {% if not allow_object %}
      {% do drex._drex_fail(function, shape_error) %}
    {% endif %}
    {% for key, description in value.items() %}
      {% do labels.append({
          "label": drex._drex_label_text(function, name, key, shape_error),
          "description": drex._drex_description(function, description, shape_error),
      }) %}
    {% endfor %}
    {{ return({"labels": labels, "from_object": true}) }}
  {% elif value is string or value is not iterable %}
    {% do drex._drex_fail(function, shape_error) %}
  {% endif %}
  {% for element in value %}
    {% if element is mapping %}
      {% for key in element %}
        {% if key not in ("label", "description") %}
          {% do drex._drex_fail(function, shape_error) %}
        {% endif %}
      {% endfor %}
      {% do labels.append({
          "label": drex._drex_label_text(function, name, element.get("label"), shape_error),
          "description": drex._drex_description(function, element.get("description"), shape_error),
      }) %}
    {% else %}
      {% do labels.append({"label": drex._drex_label_text(function, name, element, shape_error), "description": none}) %}
    {% endif %}
  {% endfor %}
  {{ return({"labels": labels, "from_object": false}) }}
{% endmacro %}


{#- Drex's and prompt_jev's rules for a question's labels -#}
{% macro _drex_check_labels(function, name, type, parsed) %}
  {% set labels = parsed.labels %}
  {% if type == "noul" %}
    {#- No labels is a noul without criteria. A list names both true and false; a dict may describe only one. -#}
    {% set found = labels | map(attribute="label") | list %}
    {% set valid = found | reject("in", ["true", "false"]) | list | length == 0
        and found | unique | list | length == found | length %}
    {% set complete = found | length == 0 or parsed.from_object or ("true" in found and "false" in found) %}
    {% if not (valid and complete) %}
      {% do drex._drex_fail(function, name ~ " labels must be exactly true and false, got [" ~ found | join(", ") ~ "]") %}
    {% endif %}
    {{ return(none) }}
  {% endif %}
  {% set kind = "labels" if type == "choice" else "levels" %}
  {% set what = name if name == kind else name ~ " " ~ kind %}
  {% if labels | length < 2 or labels | length > 255 %}
    {% do drex._drex_fail(function, name ~ " takes 2 to 255 " ~ kind ~ ", got " ~ labels | length) %}
  {% endif %}
  {% set seen = [] %}
  {% for label in labels %}
    {% if label.label == "" %}
      {% do drex._drex_fail(function, what ~ " must not be empty") %}
    {% endif %}
    {% if label.label in seen %}
      {% do drex._drex_fail(function, what ~ " must be unique; '" ~ label.label ~ "' is a duplicate") %}
    {% endif %}
    {% do seen.append(label.label) %}
    {% if type == "score" and label.description is not none %}
      {% do drex._drex_fail(function, "score levels take no description; describe them in instructions") %}
    {% endif %}
  {% endfor %}
{% endmacro %}


{#- What Drex refuses in a noul: neither instructions nor a description of true or false -#}
{% macro _drex_check_noul_text(function, name, instructions, labels) %}
  {% if instructions != "" %}
    {{ return(none) }}
  {% endif %}
  {% for label in labels %}
    {% if label.description %}
      {{ return(none) }}
    {% endif %}
  {% endfor %}
  {% do drex._drex_fail(function, name ~ " needs instructions, or a description of true or false") %}
{% endmacro %}


{#- One typed question's arguments, parsed and checked: {type, instructions, labels, from_object} -#}
{% macro _drex_question(function, name, type, instructions, criteria, criteria_name) %}
  {% set parsed = drex._drex_labels(function, criteria_name, criteria, type != "score") %}
  {% if type != "noul" and parsed.labels | length == 0 and criteria is none %}
    {% do drex._drex_fail(function, name ~ " needs " ~ ("labels" if type == "choice" else "levels")) %}
  {% endif %}
  {% do drex._drex_check_labels(function, criteria_name, type, parsed) %}
  {% if type == "noul" %}
    {% do drex._drex_check_noul_text(function, name, instructions, parsed.labels) %}
  {% endif %}
  {{ return({"type": type, "instructions": instructions, "labels": parsed.labels, "from_object": parsed.from_object}) }}
{% endmacro %}


{#-
  `questions`: a dict of question id to {type, instructions, criteria}, 1 to 512 of them. Returns
  [{id, type, instructions, labels, from_object}] in the order written.
-#}
{% macro _drex_questions(function, value) %}
  {% if value is not mapping %}
    {% do drex._drex_fail(function, "questions must be a dict of question id to question") %}
  {% endif %}
  {% if value | length < 1 or value | length > 512 %}
    {% do drex._drex_fail(function, "questions takes 1 to 512 questions, got " ~ value | length) %}
  {% endif %}
  {% set questions = [] %}
  {% set seen = [] %}
  {% for id, entry in value.items() %}
    {% if id is not string %}
      {% do drex._drex_fail(function, "question ids must be text, not " ~ id) %}
    {% endif %}
    {% if id | trim == "" %}
      {% do drex._drex_fail(function, "question ids must not be empty") %}
    {% endif %}
    {#- Drex collects answers in a plain object, whose __proto__ is not a key: it would bill the request and drop it -#}
    {% if id == "__proto__" %}
      {% do drex._drex_fail(function, "the question id '__proto__' is not allowed: Drex can't answer it") %}
    {% endif %}
    {% if id | lower in seen %}
      {% do drex._drex_fail(function, "question ids must be unique ignoring case; '" ~ id ~ "' is a duplicate") %}
    {% endif %}
    {% do seen.append(id | lower) %}
    {% set name = "questions." ~ id %}
    {% if entry is not mapping %}
      {% do drex._drex_fail(function, name ~ " must be a dict with type, instructions and criteria") %}
    {% endif %}
    {% for key in entry %}
      {% if key not in ("type", "instructions", "criteria") %}
        {% do drex._drex_fail(function, name ~ " has an unknown key '" ~ key ~ "'; use type, instructions and criteria") %}
      {% endif %}
    {% endfor %}
    {% set type = entry.get("type") %}
    {% if type in ("multiple_choice", "box") %}
      {% do drex._drex_fail(function, name ~ ": " ~ type ~ " questions are not supported, since Drex has no " ~ type ~ " question") %}
    {% elif type not in ("noul", "choice", "score") %}
      {% do drex._drex_fail(function, name ~ ".type must be noul, choice or score" ~ (", not '" ~ type ~ "'" if type is string else "")) %}
    {% endif %}
    {% set instructions = entry.get("instructions") %}
    {% if instructions is not none and instructions is not string %}
      {% do drex._drex_fail(function, name ~ ".instructions must be text") %}
    {% endif %}
    {% if type != "noul" and entry.get("criteria") is none %}
      {% do drex._drex_fail(function, name ~ " needs criteria") %}
    {% endif %}
    {% set question = drex._drex_question(function, name, type, instructions or "", entry.get("criteria"), name ~ ".criteria") %}
    {% do question.update({"id": id}) %}
    {% do questions.append(question) %}
  {% endfor %}
  {{ return(questions) }}
{% endmacro %}


{#-
  A question's criteria as JSON, or none for no criteria. A noul whose labels have no description has no criteria, as
  Drex reads it; with a description it is Drex's object of label to description. A score is a list of levels. A choice
  is a list, which every warehouse's Drex function accepts, so warehouses whose JSON objects don't keep their keys'
  order (Snowflake, BigQuery, Postgres jsonb) send the options as written; with `native`, it is Drex's own object of label
  to description, for drex-duckdb's drex_decide, which sends questions to Drex as they are.
-#}
{% macro _drex_criteria_json(question, native=false) %}
  {% set described = question.labels | rejectattr("description", "none") | list | length > 0 %}
  {% if question.type == "noul" %}
    {% if not described %}
      {{ return(none) }}
    {% endif %}
    {% set criteria = {} %}
    {% for label in question.labels %}
      {% do criteria.update({label.label: label.description}) %}
    {% endfor %}
    {{ return(criteria) }}
  {% elif question.type == "choice" and native %}
    {% set criteria = {} %}
    {% for label in question.labels %}
      {% do criteria.update({label.label: label.description}) %}
    {% endfor %}
    {{ return(criteria) }}
  {% elif question.type == "choice" and described %}
    {% set criteria = [] %}
    {% for label in question.labels %}
      {% do criteria.append({"label": label.label, "description": label.description}) %}
    {% endfor %}
    {{ return(criteria) }}
  {% endif %}
  {{ return(question.labels | map(attribute="label") | list) }}
{% endmacro %}


{#- The questions as a JSON object of id to question, with each question's criteria as _drex_criteria_json writes them -#}
{% macro _drex_questions_json(questions, native=false) %}
  {% set result = {} %}
  {% for question in questions %}
    {% set entry = {"type": question.type} %}
    {% if question.instructions != "" %}
      {% do entry.update({"instructions": question.instructions}) %}
    {% endif %}
    {% set criteria = drex._drex_criteria_json(question, native) %}
    {% if criteria is not none %}
      {% do entry.update({"criteria": criteria}) %}
    {% endif %}
    {% do result.update({question.id: entry}) %}
  {% endfor %}
  {{ return(result) }}
{% endmacro %}
