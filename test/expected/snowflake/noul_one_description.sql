select drex.public.drex_noul(body, 'Refund?', PARSE_JSON('{"true": "Asks for money back"}')) as answer from tickets
