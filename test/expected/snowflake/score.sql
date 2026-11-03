select drex.public.drex_score(body, 'How urgent is this ticket?', PARSE_JSON('["can wait", "this week", "today"]'), 'drex-max') as answer from tickets
