select drex.noul(body, '', JSON '{"true": "The customer wants money back", "false": null}', NULL) as answer from tickets
