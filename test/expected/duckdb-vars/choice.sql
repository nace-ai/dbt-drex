select prompt_drex(body, 'Which team should handle this ticket?', choice := ['billing', 'technical', 'sales'], model := 'drex-max-v1.1') as answer from tickets
