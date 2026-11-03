select drex.public.drex_choice(body, 'Which team should handle this ticket?', PARSE_JSON('["billing", "technical", "sales"]')) as answer from tickets
