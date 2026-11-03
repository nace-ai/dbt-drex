select drex.public.drex_noul(body, '', PARSE_JSON('{"true": "The customer wants money back", "false": null}')) as answer from tickets
