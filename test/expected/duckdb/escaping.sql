select prompt_drex(body, 'Is it the customer''s "own" C:\path?
Say so: 100% sûr', choice := ['it''s', 'back\slash', 'naïve']) as answer from tickets
