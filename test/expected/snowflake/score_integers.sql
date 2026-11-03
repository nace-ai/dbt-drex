select drex.public.drex_score(body, 'Rate the review', PARSE_JSON('["1", "2", "3", "4", "5"]')) as answer from tickets
