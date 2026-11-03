select prompt_drex(body, 'Which team should handle this ticket?', choice := ['billing', 'technical', 'sales']) as answer from tickets
