select drex.decide(payload, JSON '{"refund": {"type": "noul", "instructions": "Refund?"}}', 'drex-max') as answer from tickets
