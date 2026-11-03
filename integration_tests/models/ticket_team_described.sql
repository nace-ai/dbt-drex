{#- A choice with descriptions, one of them null. ClickHouse's drex_choice takes plain labels: there, drex_decide asks it. -#}
{{ config(enabled=target.type != "clickhouse") }}

select
    id,
    {{ drex.drex_choice("body", "Which team should handle this ticket?", {
        "billing": "Payments, invoices, refunds and charges",
        "technical": "Bugs, crashes and errors in the product",
        "sales": none,
    }) }} as team
from {{ ref("stg_tickets") }}
where id <= 4
