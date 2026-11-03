select GET(team, 'choice')::VARCHAR as team, GET(urgency, 'score')::FLOAT as urgency, GET(team, 'confidence')::FLOAT as confidence from answers
