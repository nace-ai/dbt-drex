select `analytics`.ml.decide_image(state, images, JSON '{"receipt": {"type": "noul", "instructions": "Is Image 1 a receipt?"}}', NULL) as answer from photos
