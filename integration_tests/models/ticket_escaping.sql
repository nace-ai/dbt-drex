{#-
  Quotes, backslashes, a newline, a tab and Unicode in instructions, labels, descriptions, question ids and state keys,
  and numbers and NULL in a dict state, as each warehouse's literals carry them to Drex
-#}
{% set tricky = "It's \"quoted\", C:\\path\\n, a\nnew line,\ta tab, ünïcode 😀" %}
select
    id,
    {{ drex.drex_noul("body", tricky) }} as noul,
    {{ drex.drex_choice("body", tricky, ["it's", "back\\slash", "new\nline", "ünï 😀"]) }} as choice,
    {{ drex.drex_decide({"id": "id", "half": "id * 0.5", "missing": "nullif(body, body)", tricky: "subject"}, {
        "ünï 'q' \"id\"": {"type": "choice", "instructions": tricky, "criteria": {"it's": tricky, "plain": none}},
    }) }} as decision
from {{ ref("stg_tickets") }}
where id = 1
