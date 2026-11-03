select drex.choice(body, 'Which team should handle this ticket?', JSON '["billing", "technical", "sales"]', NULL) as answer from tickets
