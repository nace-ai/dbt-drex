select drex.choice(body, 'Which team?', JSON '["billing", "technical"]', NULL) as answer from tickets
