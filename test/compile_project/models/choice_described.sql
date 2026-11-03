{{ config(enabled=target.type != "clickhouse") }}
select {{ drex.drex_choice("body", "Which team should handle this ticket?", [
    {"label": "billing", "description": "Payments, invoices, refunds and charges"},
    {"label": "technical", "description": none},
    {"label": "sales"},
], model="drex-max") }} as answer from tickets
