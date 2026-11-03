select drex.public.drex_decide(payload, PARSE_JSON('{"refund": {"type": "noul", "instructions": "Refund?"}}'), 'drex-max') as answer from tickets
