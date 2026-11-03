select `analytics`.ml.choice(body, 'Which team should handle this ticket?', JSON '["billing", "technical", "sales"]', 'drex-max-v1.1') as answer from tickets
