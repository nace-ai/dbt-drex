select ml.drex_decide_image(state, images, '{"receipt": {"type": "noul", "instructions": "Is Image 1 a receipt?"}}'::jsonb) as answer from photos
