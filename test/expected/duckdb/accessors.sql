select struct_extract(team, 'choice') as team, struct_extract(urgency, 'score') as urgency, struct_extract(team, 'confidence') as confidence from answers
