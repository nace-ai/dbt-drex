select drex.choice(body, 'Is it the customer\'s "own" C:\\path?\nSay so: 100% sûr', JSON '["it\'s", "back\\\\slash", "na\\u00efve"]', NULL) as answer from tickets
