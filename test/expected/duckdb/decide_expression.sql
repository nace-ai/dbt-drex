select drex_decide(payload, '{"refund": {"type": "noul", "instructions": "Refund?"}}'::JSON, model := 'drex-max') as answer from tickets
