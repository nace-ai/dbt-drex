select public.drex_decide(payload, '{"refund": {"type": "noul", "instructions": "Refund?"}}'::jsonb, 'drex-max') as answer from tickets
