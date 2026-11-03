select drex.public.drex_choice(body, 'Which team?', PARSE_JSON('["billing", "technical"]')) as answer from tickets
