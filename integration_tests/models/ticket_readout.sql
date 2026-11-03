{#- The answers as plain values, read the same way on every warehouse. No Drex call, so nothing is sent. -#}
select
    answers.id,
    answers.refund,
    {{ drex.drex_choice_value("answers.team") }} as team,
    {{ drex.drex_confidence("answers.team") }} as team_confidence,
    {{ drex.drex_score_value("answers.urgency") }} as urgency,
    {{ drex.drex_confidence("answers.urgency") }} as urgency_confidence
from {{ ref("ticket_answers") }} as answers
