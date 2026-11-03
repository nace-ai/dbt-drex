select prompt_drex(body, 'Refund?', noul := [{'label': 'true', 'description': 'Asks for money back'}, {'label': 'false', 'description': NULL}]) as answer from tickets
