{#- One question of each kind per ticket, on the default model unless var('drex_model') names another -#}
select
    id,
    {{ drex.drex_noul("body", "Is the customer asking for a refund?") }} as refund,
    {{ drex.drex_noul("body", criteria={"true": "The customer wants money back", "false": none}) }} as refund_described,
    {{ drex.drex_choice("body", "Which team should handle this ticket?", ["billing", "technical", "sales"]) }} as team,
    {{ drex.drex_score("body", "How urgent is this ticket?", ["can wait", "this week", "today"]) }} as urgency,
    {{ drex.drex_noul("body", "Is this ticket about a bug?", model="drex-max") }} as bug_max
from {{ ref("stg_tickets") }}
where id <= 4
