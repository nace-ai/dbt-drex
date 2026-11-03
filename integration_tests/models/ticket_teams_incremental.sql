{#-
  Sends only the tickets whose body, question or model changed since the last run: each row keeps the fingerprint it
  was answered with. var('drex_test_team_instructions') changes the question, which sends every ticket again, and
  var('drex_test_retry_unanswered') adds docs/API.md's condition that asks again the tickets with no answer.
-#}
{{ config(materialized="incremental", unique_key="id") }}

{% set team = {
    "instructions": var("drex_test_team_instructions", "Which team should handle this ticket?"),
    "labels": ["billing", "technical", "sales"],
} %}

with tickets as (
    select id, body, {{ drex.drex_fingerprint("body", team) }} as drex_fingerprint
    from {{ ref("stg_tickets") }}
)

select
    tickets.id,
    tickets.drex_fingerprint,
    {{ drex.drex_choice("tickets.body", team.instructions, team.labels) }} as team
from tickets
{% if is_incremental() %}
left join {{ this }} as answered on answered.id = tickets.id
where answered.drex_fingerprint is null or answered.drex_fingerprint <> tickets.drex_fingerprint
{% if var("drex_test_retry_unanswered", false) %}
or (tickets.body is not null and {{ drex.drex_choice_value("answered.team") }} is null)
{% endif %}
{% endif %}
