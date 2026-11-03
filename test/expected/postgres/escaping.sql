select public.drex_choice(body, 'Is it the customer''s "own" C:\path?
Say so: 100% sûr', '["it''s", "back\\slash", "na\u00efve"]'::jsonb) as answer from tickets
