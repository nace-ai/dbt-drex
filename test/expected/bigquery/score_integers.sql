select drex.score(body, 'Rate the review', JSON '["1", "2", "3", "4", "5"]', NULL) as answer from tickets
