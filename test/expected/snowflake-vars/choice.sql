select analytics.ml.drex_choice(body, 'Which team should handle this ticket?', PARSE_JSON('["billing", "technical", "sales"]'), 'drex-max-v1.1') as answer from tickets
