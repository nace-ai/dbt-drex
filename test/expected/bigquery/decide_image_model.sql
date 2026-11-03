select drex.decide_image(JSON_OBJECT('note', note), images, JSON '{"kind": {"type": "choice", "criteria": ["invoice", "receipt"]}}', 'drex-max-v1.1') as answer from photos
