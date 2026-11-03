select drex.public.drex_choice(body, 'Is it the customer\'s "own" C:\\path?\nSay so: 100% sûr', PARSE_JSON('["it\'s", "back\\\\slash", "na\\u00efve"]')) as answer from tickets
