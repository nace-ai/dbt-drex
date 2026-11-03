select public.drex_choice(body, 'Which team should handle this ticket?', '["billing", "technical", "sales"]'::jsonb) as answer from tickets
