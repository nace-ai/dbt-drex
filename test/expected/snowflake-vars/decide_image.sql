select analytics.ml.drex_decide_image(state, images, PARSE_JSON('{"receipt": {"type": "noul", "instructions": "Is Image 1 a receipt?"}}')) as answer from photos
