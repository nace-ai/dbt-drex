select tupleElement(team, 'choice') as team, tupleElement(urgency, 'score') as urgency, tupleElement(team, 'confidence') as confidence from answers
