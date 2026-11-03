select public.drex_score(body, 'Rate the review', '["1", "2", "3", "4", "5"]'::jsonb) as answer from tickets
