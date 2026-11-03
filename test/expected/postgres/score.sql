select public.drex_score(body, 'How urgent is this ticket?', '["can wait", "this week", "today"]'::jsonb, 'drex-max') as answer from tickets
