select ((team) ->> 'choice') as team, ((urgency) ->> 'score')::double precision as urgency, ((team) ->> 'confidence')::double precision as confidence from answers
