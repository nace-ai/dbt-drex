{#-
  docs/API.md's "Reading results": the answers Drex is sure of. The column is qualified because ClickHouse would read
  an unqualified `team` as the alias `team` of the label.
-#}
select
    answers.id,
    {{ drex.drex_choice_value("answers.team") }} as team,
    {{ drex.drex_confidence("answers.team") }} as team_confidence,
    {{ drex.drex_score_value("answers.urgency") }} as urgency
from {{ ref("ticket_answers") }} as answers
where {{ drex.drex_confidence("answers.team") }} >= 0.8
