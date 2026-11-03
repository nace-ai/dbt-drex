select ml.drex_choice(body, 'Which team should handle this ticket?', '["billing", "technical", "sales"]'::jsonb, 'drex-max-v1.1') as answer from tickets
