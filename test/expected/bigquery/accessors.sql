select JSON_VALUE(team, '$.choice') as team, LAX_FLOAT64(JSON_QUERY(urgency, '$.score')) as urgency, LAX_FLOAT64(JSON_QUERY(team, '$.confidence')) as confidence from answers
