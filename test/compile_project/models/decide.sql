select {{ drex.drex_decide({"subject": "subject", "body": "body"}, {
    "refund": {"type": "noul", "instructions": "Is a refund needed?"},
    "outage": {"type": "noul", "criteria": {"true": "Many users can't work", "false": none}},
    "team": {"type": "choice", "instructions": "Which team?", "criteria": {"billing": "Payments", "technical": none}},
    "urgency": {"type": "score", "instructions": "How urgent?", "criteria": ["low", "high"]},
}) }} as answer from tickets
