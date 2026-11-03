select drex.score(body, 'How urgent is this ticket?', JSON '["can wait", "this week", "today"]', 'drex-max') as answer from tickets
