select prompt_drex(body, 'How urgent is this ticket?', score := ['can wait', 'this week', 'today'], model := 'drex-max') as answer from tickets
