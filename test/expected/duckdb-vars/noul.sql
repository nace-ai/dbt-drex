select prompt_drex(body, 'Is the customer asking for a refund?', model := 'drex-max-v1.1') as answer from tickets
