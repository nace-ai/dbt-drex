select drex.noul(body, 'Refund?', JSON '{"true": "Asks for money back"}', NULL) as answer from tickets
