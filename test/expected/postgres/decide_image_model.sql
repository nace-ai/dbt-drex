select public.drex_decide_image(jsonb_build_object('note', note), images, '{"kind": {"type": "choice", "criteria": ["invoice", "receipt"]}}'::jsonb, 'drex-max-v1.1') as answer from photos
