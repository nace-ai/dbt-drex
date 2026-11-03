select public.drex_choice(body, 'Which team?', '["billing", "technical"]'::jsonb) as answer from tickets
