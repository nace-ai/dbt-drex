{#- Several questions in one request per row, with the row's fields as JSON state -#}
select
    id,
    {{ drex.drex_decide({"subject": "subject", "body": "body"}, {
        "refund": {"type": "noul", "instructions": "Is a refund needed?"},
        "team": {"type": "choice", "instructions": "Which team should handle this ticket?",
                 "criteria": {"billing": "Payments, invoices, refunds and charges", "technical": none, "sales": none}},
        "urgency": {"type": "score", "instructions": "How urgent is this ticket?", "criteria": ["can wait", "this week", "today"]},
    }) }} as decision
from {{ ref("stg_tickets") }}
where id <= 4
