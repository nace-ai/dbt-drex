select main.drex.drex_score(body, 'How urgent is this ticket?', '["can wait", "this week", "today"]', 'drex-max') as answer from tickets
